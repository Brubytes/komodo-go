from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from json import JSONDecoder
from typing import Any, Optional

from . import __version__
from .docsrs import (
    AllItem,
    DocItem,
    DocsRsClient,
    DocsRsError,
    ensure_bool,
    ensure_int,
    ensure_one_of,
    ensure_str,
    filter_module_docs,
    module_docs_to_json,
    module_docs_to_markdown,
    search_all_items,
)


@dataclass(frozen=True)
class JsonRpcRequest:
    jsonrpc: str
    id: Optional[Any]
    method: str
    params: dict[str, Any]

_DEBUG = os.environ.get("KOMODO_DOCS_MCP_DEBUG", "").strip().lower() in {"1", "true", "yes", "y", "on"}
_LOG_FILE = (os.environ.get("KOMODO_DOCS_MCP_LOG_FILE") or "").strip()
_LOG_FP = None
_STDIO_MODE: Optional[str] = None  # "content-length" | "ndjson"


def _log_open() -> None:
    global _LOG_FP
    if _LOG_FP is not None:
        return
    if not _LOG_FILE:
        _LOG_FP = False
        return
    try:
        _LOG_FP = open(_LOG_FILE, "a", encoding="utf-8")
    except Exception:
        _LOG_FP = False


def _debug(msg: str) -> None:
    if not _DEBUG:
        _log_open()
        if _LOG_FP not in (None, False):
            _LOG_FP.write(msg.rstrip() + "\n")
            _LOG_FP.flush()
        return
    _log_open()
    line = msg.rstrip() + "\n"
    try:
        sys.stderr.write(line)
        sys.stderr.flush()
    except Exception:
        pass
    if _LOG_FP not in (None, False):
        _LOG_FP.write(line)
        _LOG_FP.flush()


def _write_message(payload: dict[str, Any]) -> None:
    global _STDIO_MODE
    raw_text = json.dumps(payload, ensure_ascii=False)

    # Default to NDJSON; Codex's stdio transport uses newline-delimited JSON.
    mode = _STDIO_MODE or "ndjson"
    if mode == "content-length":
        raw = raw_text.encode("utf-8")
        sys.stdout.buffer.write(f"Content-Length: {len(raw)}\r\n\r\n".encode("ascii"))
        sys.stdout.buffer.write(raw)
        sys.stdout.buffer.flush()
        return

    sys.stdout.write(raw_text + "\n")
    sys.stdout.flush()

class _StdioJsonRpc:
    def __init__(self) -> None:
        self._buf = b""
        self._decoder = JSONDecoder()
        self.last_framing: Optional[str] = None

    def _fill(self) -> bool:
        reader = sys.stdin.buffer
        read1 = getattr(reader, "read1", None)
        chunk = read1(4096) if callable(read1) else reader.read(4096)
        if not chunk:
            return False
        self._buf += chunk
        return True

    def read_message(self) -> Optional[dict[str, Any]]:
        while True:
            # Trim leading whitespace/newlines.
            self._buf = self._buf.lstrip(b"\r\n\t ")
            if not self._buf and not self._fill():
                return None

            # Header framing: Content-Length
            lower = self._buf[:64].lower()
            if lower.startswith(b"content-length:"):
                self.last_framing = "content-length"
                header_end = self._buf.find(b"\r\n\r\n")
                sep_len = 4
                if header_end < 0:
                    header_end = self._buf.find(b"\n\n")
                    sep_len = 2
                if header_end < 0:
                    if not self._fill():
                        return None
                    continue

                header_blob = self._buf[:header_end].decode("utf-8", errors="replace")
                length = None
                for raw_line in header_blob.replace("\r\n", "\n").split("\n"):
                    if raw_line.lower().startswith("content-length:"):
                        try:
                            length = int(raw_line.split(":", 1)[1].strip())
                        except Exception:
                            length = None
                        break
                if length is None:
                    raise ValueError("invalid Content-Length header")

                body_start = header_end + sep_len
                need = body_start + length
                while len(self._buf) < need:
                    if not self._fill():
                        return None

                body = self._buf[body_start:need]
                self._buf = self._buf[need:]
                return json.loads(body.decode("utf-8", errors="replace"))

            # Raw JSON (no headers, no newline required).
            self.last_framing = "ndjson"
            try:
                text = self._buf.decode("utf-8")
            except UnicodeDecodeError:
                if not self._fill():
                    return None
                continue

            start = 0
            while start < len(text) and text[start] in " \t\r\n":
                start += 1
            if start >= len(text):
                self._buf = b""
                if not self._fill():
                    return None
                continue

            try:
                obj, end = self._decoder.raw_decode(text, start)
            except json.JSONDecodeError:
                if not self._fill():
                    return None
                continue

            consumed = len(text[:end].encode("utf-8"))
            self._buf = self._buf[consumed:]
            return obj


def _as_request(msg: dict[str, Any]) -> JsonRpcRequest:
    return JsonRpcRequest(
        jsonrpc=str(msg.get("jsonrpc") or "2.0"),
        id=msg.get("id"),
        method=str(msg.get("method") or ""),
        params=dict(msg.get("params") or {}),
    )


def _result(req_id: Any, result: Any) -> None:
    if req_id is None:
        return
    _write_message({"jsonrpc": "2.0", "id": req_id, "result": result})


def _error(req_id: Any, code: int, message: str, data: Optional[Any] = None) -> None:
    if req_id is None:
        return
    err: dict[str, Any] = {"code": code, "message": message}
    if data is not None:
        err["data"] = data
    _write_message({"jsonrpc": "2.0", "id": req_id, "error": err})


def _notify(method: str, params: Optional[dict[str, Any]] = None) -> None:
    _write_message({"jsonrpc": "2.0", "method": method, "params": params or {}})


def _tool_schema_get_module_docs() -> dict[str, Any]:
    return {
        # Tool names must match ^[a-zA-Z0-9_-]+$ (no dots).
        "name": "komodo_docs_get_module_docs",
        "description": "Fetch docs.rs rustdoc for a module and return a sectioned API overview (Markdown or JSON).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "crate": {"type": "string", "default": "komodo_client"},
                "version": {"type": "string", "default": "latest"},
                "modulePath": {"type": "string", "default": "komodo_client::api::read"},
                "query": {"type": "string", "default": ""},
                "includeItemDocs": {"type": "boolean", "default": False},
                "maxItems": {"type": "integer", "default": 50, "minimum": 1, "maximum": 500},
                "format": {"type": "string", "default": "markdown", "enum": ["markdown", "json"]},
            },
            "required": [],
        },
    }


def _tool_schema_search() -> dict[str, Any]:
    return {
        "name": "komodo_docs_search",
        "description": "Search the crate-wide docs.rs 'all items' index and return matching symbols with URLs.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "crate": {"type": "string", "default": "komodo_client"},
                "version": {"type": "string", "default": "latest"},
                "query": {"type": "string"},
                "limit": {"type": "integer", "default": 20, "minimum": 1, "maximum": 200},
                "format": {"type": "string", "default": "markdown", "enum": ["markdown", "json"]},
            },
            "required": ["query"],
        },
    }


def _tool_schema_get_item_docs() -> dict[str, Any]:
    return {
        "name": "komodo_docs_get_item_docs",
        "description": "Fetch docs.rs rustdoc page for a symbol (by name or full path) and return its signature + docs.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "crate": {"type": "string", "default": "komodo_client"},
                "version": {"type": "string", "default": "latest"},
                "item": {"type": "string", "description": "Symbol name or full path like entities::stack::StackListItem"},
                "maxMatches": {"type": "integer", "default": 10, "minimum": 1, "maximum": 50},
                "format": {"type": "string", "default": "markdown", "enum": ["markdown", "json"]},
            },
            "required": ["item"],
        },
    }


def _format_search_markdown(*, crate: str, version: str, query: str, hits: list[AllItem], base_url: str) -> str:
    lines: list[str] = []
    lines.append(f"# Search: {query}")
    lines.append("")
    lines.append(f"- Crate: `{crate}`")
    lines.append(f"- Version: `{version}`")
    lines.append("")
    if not hits:
        lines.append("_No matches._")
        return "\n".join(lines).strip() + "\n"
    for it in hits:
        url = base_url + it.href.lstrip("/")
        lines.append(f"- `{it.item_path}` ({it.kind}) — {url}")
    return "\n".join(lines).strip() + "\n"


def _handle_tool_search(arguments: dict[str, Any], client: DocsRsClient) -> dict[str, Any]:
    crate = ensure_str(arguments.get("crate"), default="komodo_client")
    version = ensure_str(arguments.get("version"), default="latest")
    query = ensure_str(arguments.get("query"), default="")
    limit = ensure_int(arguments.get("limit"), default=20, min_value=1, max_value=200)
    fmt = ensure_one_of(arguments.get("format"), default="markdown", allowed=["markdown", "json"])

    page_version, items = client.parse_all_items(crate=crate, version=version)
    hits = search_all_items(items, query=query, limit=limit)
    base_url = f"https://docs.rs/{crate}/{version}/{crate}/"

    if fmt == "json":
        payload = {
            "crate": crate,
            "version": page_version,
            "query": query,
            "hits": [
                {
                    "kind": it.kind,
                    "itemPath": it.item_path,
                    "href": it.href,
                    "url": base_url + it.href.lstrip("/"),
                }
                for it in hits
            ],
        }
        text = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    else:
        text = _format_search_markdown(crate=crate, version=page_version, query=query, hits=hits, base_url=base_url)

    return {"content": [{"type": "text", "text": text}]}


def _handle_tool_get_item_docs(arguments: dict[str, Any], client: DocsRsClient) -> dict[str, Any]:
    crate = ensure_str(arguments.get("crate"), default="komodo_client")
    version = ensure_str(arguments.get("version"), default="latest")
    item_query = ensure_str(arguments.get("item"), default="")
    max_matches = ensure_int(arguments.get("maxMatches"), default=10, min_value=1, max_value=50)
    fmt = ensure_one_of(arguments.get("format"), default="markdown", allowed=["markdown", "json"])

    page_version, items = client.parse_all_items(crate=crate, version=version)
    hits = search_all_items(items, query=item_query, limit=max_matches)

    base_url = f"https://docs.rs/{crate}/{version}/{crate}/"
    if not hits:
        return {
            "content": [
                {
                    "type": "text",
                    "text": f"No matches for `{item_query}` in `{crate}` {page_version}. Try komodo_docs_search.\n",
                }
            ],
            "isError": True,
        }

    # Prefer exact full-path matches if provided.
    normalized = item_query.strip()
    exact = [h for h in hits if h.item_path == normalized]
    chosen = exact[0] if exact else hits[0]

    item = DocItem(kind=chosen.kind, name=chosen.item_path.split("::")[-1], href=chosen.href)
    detailed = client.parse_item_page(base_url=base_url, item=item)

    url = base_url + chosen.href.lstrip("/")
    if fmt == "json":
        payload = {
            "crate": crate,
            "version": page_version,
            "item": {
                "kind": chosen.kind,
                "itemPath": chosen.item_path,
                "url": url,
                "signature": detailed.signature,
                "docs": detailed.docs,
            },
            "alternatives": [
                {"kind": h.kind, "itemPath": h.item_path, "url": base_url + h.href.lstrip("/")}
                for h in hits[1:]
            ],
        }
        text = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    else:
        lines: list[str] = []
        lines.append(f"# {chosen.item_path}")
        lines.append("")
        lines.append(f"- Crate: `{crate}`")
        lines.append(f"- Version: `{page_version}`")
        lines.append(f"- Source: {url}")
        lines.append("")
        if detailed.signature:
            lines.append("```rust")
            lines.append(detailed.signature)
            lines.append("```")
            lines.append("")
        if detailed.docs:
            lines.append(detailed.docs)
            lines.append("")
        if len(hits) > 1:
            lines.append("## Other matches")
            lines.append("")
            for h in hits[1:]:
                lines.append(f"- `{h.item_path}` ({h.kind}) — {base_url + h.href.lstrip('/')}")
            lines.append("")
        text = "\n".join(lines).strip() + "\n"

    return {"content": [{"type": "text", "text": text}]}


def _handle_tool_get_module_docs(arguments: dict[str, Any], client: DocsRsClient) -> dict[str, Any]:
    crate = ensure_str(arguments.get("crate"), default="komodo_client")
    version = ensure_str(arguments.get("version"), default="latest")
    module_path = ensure_str(arguments.get("modulePath"), default=f"{crate}::api::read")
    query = ensure_str(arguments.get("query"), default="")
    include_item_docs = ensure_bool(arguments.get("includeItemDocs"), default=False)
    max_items = ensure_int(arguments.get("maxItems"), default=50, min_value=1, max_value=500)
    fmt = ensure_one_of(arguments.get("format"), default="markdown", allowed=["markdown", "json"])

    # Convenience topic shorthands.
    if module_path.lower() in {"stack", "stacks"}:
        module_path = f"{crate}::api::read"
        if not query:
            query = "stack"

    module = client.parse_module(crate=crate, version=version, module_path=module_path)
    if query:
        module = filter_module_docs(module, query=query)
    if fmt == "json":
        text = module_docs_to_json(
            module,
            include_item_docs=include_item_docs,
            max_items=max_items,
            client=client,
        )
    else:
        text = module_docs_to_markdown(
            module,
            include_item_docs=include_item_docs,
            max_items=max_items,
            client=client,
        )

    return {"content": [{"type": "text", "text": text}]}


def main() -> None:
    # Allow overriding user agent (useful if docs.rs rate limits).
    user_agent = os.environ.get("KOMODO_DOCS_MCP_USER_AGENT") or f"komodo-docs-mcp/{__version__}"
    docs_client = DocsRsClient(user_agent=user_agent)
    transport = _StdioJsonRpc()
    _debug(f"server start: version={__version__} pid={os.getpid()} cwd={os.getcwd()}")
    _debug(f"python: {sys.executable} {sys.version.split()[0]}")

    while True:
        try:
            msg = transport.read_message()
        except Exception as e:
            _debug(f"read_message error: {e}")
            return
        if msg is None:
            return
        global _STDIO_MODE
        if _STDIO_MODE is None and transport.last_framing:
            _STDIO_MODE = transport.last_framing
            _debug(f"stdio mode: {_STDIO_MODE}")
        _debug(f"<= {msg.get('method')}")
        req = _as_request(msg)

        if not req.method:
            _error(req.id, -32600, "Invalid Request: missing method")
            continue

        try:
            if req.method == "initialize":
                _result(
                    req.id,
                    {
                        "protocolVersion": req.params.get("protocolVersion") or "2024-11-05",
                        "serverInfo": {"name": "komodo-docs-mcp", "version": __version__},
                        "capabilities": {
                            "tools": {"listChanged": False},
                            "resources": {"subscribe": False, "listChanged": False},
                            "prompts": {"listChanged": False},
                        },
                        "instructions": "Use komodo_docs.get_module_docs to fetch and format docs.rs API docs.",
                    },
                )
            elif req.method in ("initialized", "notifications/initialized"):
                # Notification; no response.
                _result(req.id, {})
            elif req.method == "ping":
                _result(req.id, {})
            elif req.method == "tools/list":
                _result(req.id, {"tools": [_tool_schema_get_module_docs(), _tool_schema_search(), _tool_schema_get_item_docs()]})
            elif req.method == "tools/call":
                name = str(req.params.get("name") or "")
                arguments = dict(req.params.get("arguments") or {})
                if name in ("komodo_docs_get_module_docs", "komodo_docs.get_module_docs"):
                    _result(req.id, _handle_tool_get_module_docs(arguments, docs_client))
                elif name == "komodo_docs_search":
                    _result(req.id, _handle_tool_search(arguments, docs_client))
                elif name == "komodo_docs_get_item_docs":
                    _result(req.id, _handle_tool_get_item_docs(arguments, docs_client))
                else:
                    _error(req.id, -32601, f"Unknown tool: {name}")
            elif req.method == "resources/list":
                _result(req.id, {"resources": []})
            elif req.method == "resources/templates/list":
                _result(req.id, {"resourceTemplates": []})
            elif req.method == "prompts/list":
                _result(req.id, {"prompts": []})
            elif req.method in ("resources/read", "prompts/get"):
                _error(req.id, -32601, f"Method not implemented: {req.method}")
            else:
                # Ignore unknown notifications; error on requests.
                _error(req.id, -32601, f"Method not found: {req.method}")
        except DocsRsError as e:
            _result(req.id, {"content": [{"type": "text", "text": f"docs.rs error: {e}"}], "isError": True})
        except Exception as e:
            _error(req.id, -32603, "Internal error", data=str(e))
