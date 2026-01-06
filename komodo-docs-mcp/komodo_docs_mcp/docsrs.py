from __future__ import annotations

import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from html import unescape
from typing import Any, Iterable, Optional


@dataclass(frozen=True)
class DocItem:
    kind: str
    name: str
    href: str
    summary: Optional[str] = None
    signature: Optional[str] = None
    docs: Optional[str] = None


@dataclass(frozen=True)
class DocSection:
    id: str
    title: str
    items: list[DocItem]


@dataclass(frozen=True)
class ModuleDocs:
    crate: str
    version: str
    module_path: str
    page_url: str
    sections: list[DocSection]


def filter_module_docs(module: ModuleDocs, *, query: str) -> ModuleDocs:
    q = (query or "").strip().lower()
    if not q:
        return module

    sections: list[DocSection] = []
    for section in module.sections:
        items = [
            it
            for it in section.items
            if q in it.name.lower() or (it.summary and q in it.summary.lower())
        ]
        if items:
            sections.append(DocSection(id=section.id, title=section.title, items=items))

    return ModuleDocs(
        crate=module.crate,
        version=module.version,
        module_path=module.module_path,
        page_url=module.page_url,
        sections=sections,
    )


class DocsRsError(RuntimeError):
    pass


_SECTION_RE = re.compile(
    r'<h2 id="(?P<id>[^"]+)" class="section-header">(?P<title>.*?)<a href="#',
    re.S,
)
_DL_AFTER_SECTION_RE = re.compile(r'<dl class="item-table">(?P<dl>.*?)</dl>', re.S)
_DT_DD_RE = re.compile(r"<dt>(?P<dt>.*?)</dt>(?:<dd>(?P<dd>.*?)</dd>)?", re.S)
_A_RE = re.compile(
    r'<a class="(?P<class>[^"]+)" href="(?P<href>[^"]+)"[^>]*>(?P<text>.*?)</a>',
    re.S,
)
_H1_MODULE_RE = re.compile(r"<h1>Module <span>(?P<name>.*?)</span>", re.S)
_BREADCRUMBS_RE = re.compile(r'<div class="rustdoc-breadcrumbs">(?P<html>.*?)</div>', re.S)
_BREADCRUMB_LINK_RE = re.compile(r"<a [^>]*>(?P<text>.*?)</a>", re.S)
_VERSION_RE = re.compile(r'<span class="version">(?P<ver>[^<]+)</span>', re.S)

_ITEM_DOCBLOCK_RE = re.compile(r'<div class="docblock"[^>]*>(?P<html>.*?)</div>', re.S)
_ITEM_DECL_RE = re.compile(r'<pre class="rust item-decl">(?P<html>.*?)</pre>', re.S)


def _strip_tags(html: str) -> str:
    html = re.sub(r"</?(?:wbr|span)[^>]*>", "", html)
    html = re.sub(r"<br\\s*/?>", "\n", html)
    html = re.sub(r"</p\\s*>", "\n\n", html)
    html = re.sub(r"<li\\s*>", "- ", html)
    html = re.sub(r"</li\\s*>", "\n", html)
    html = re.sub(r"<pre[^>]*>", "\n```text\n", html)
    html = re.sub(r"</pre\\s*>", "\n```\n", html)
    html = re.sub(r"<code[^>]*>", "`", html)
    html = re.sub(r"</code\\s*>", "`", html)
    html = re.sub(r"<[^>]+>", "", html)
    text = unescape(html)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def normalize_module_path(crate: str, module_path: str) -> str:
    module_path = module_path.strip()
    module_path = module_path.replace("::", "/").strip("/")
    if not module_path:
        return crate
    if not module_path.startswith(crate + "/") and module_path != crate:
        module_path = f"{crate}/{module_path}"
    return module_path


class DocsRsClient:
    def __init__(self, *, user_agent: str = "komodo-docs-mcp/0.1.0"):
        self._user_agent = user_agent
        self._cache: dict[str, tuple[float, str]] = {}

    def fetch_text(self, url: str, *, ttl_s: int = 300) -> str:
        now = time.time()
        cached = self._cache.get(url)
        if cached and (now - cached[0]) < ttl_s:
            return cached[1]

        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": self._user_agent,
                "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as e:
            raise DocsRsError(f"docs.rs returned HTTP {e.code} for {url}") from e
        except urllib.error.URLError as e:
            raise DocsRsError(f"failed to reach docs.rs for {url}: {e}") from e

        text = raw.decode("utf-8", errors="replace")
        self._cache[url] = (now, text)
        return text

    def module_url(self, crate: str, version: str, module_path: str) -> str:
        norm = normalize_module_path(crate, module_path)
        base = f"https://docs.rs/{urllib.parse.quote(crate)}/{urllib.parse.quote(version)}/"
        if norm == crate:
            return urllib.parse.urljoin(base, f"{crate}/index.html")
        return urllib.parse.urljoin(base, f"{norm}/index.html")

    def parse_module(self, *, crate: str, version: str, module_path: str) -> ModuleDocs:
        page_url = self.module_url(crate, version, module_path)
        html = self.fetch_text(page_url)

        page_version = version
        vm = _VERSION_RE.search(html)
        if vm:
            page_version = unescape(vm.group("ver")).strip()

        module_name = None
        m1 = _H1_MODULE_RE.search(html)
        if m1:
            module_name = _strip_tags(m1.group("name"))

        breadcrumbs: list[str] = []
        bm = _BREADCRUMBS_RE.search(html)
        if bm:
            for m in _BREADCRUMB_LINK_RE.finditer(bm.group("html")):
                t = _strip_tags(m.group("text"))
                if t:
                    breadcrumbs.append(t.replace("\u00ad", ""))

        module_fqn = "::".join([*breadcrumbs, module_name] if module_name else breadcrumbs)
        if not module_fqn:
            module_fqn = module_path.replace("/", "::")

        sections: list[DocSection] = []
        # rustdoc module pages: repeated (<h2.section-header> + <dl.item-table>)
        # We find all section headers first, then pair them with the next dl.
        pos = 0
        while True:
            hm = _SECTION_RE.search(html, pos)
            if not hm:
                break
            section_id = hm.group("id")
            title = _strip_tags(hm.group("title"))
            dlm = _DL_AFTER_SECTION_RE.search(html, hm.end())
            if not dlm:
                pos = hm.end()
                continue
            dl_html = dlm.group("dl")
            pos = dlm.end()

            items: list[DocItem] = []
            for m in _DT_DD_RE.finditer(dl_html):
                dt_html = m.group("dt")
                dd_html = m.group("dd")
                am = _A_RE.search(dt_html)
                if not am:
                    continue
                kind = am.group("class").split()[0]
                href = unescape(am.group("href"))
                name = _strip_tags(am.group("text"))
                summary = _strip_tags(dd_html) if dd_html else None
                items.append(DocItem(kind=kind, name=name, href=href, summary=summary))

            sections.append(DocSection(id=section_id, title=title, items=items))

        return ModuleDocs(
            crate=crate,
            version=page_version,
            module_path=module_fqn,
            page_url=page_url,
            sections=sections,
        )

    def parse_item_page(self, *, base_url: str, item: DocItem) -> DocItem:
        url = urllib.parse.urljoin(base_url, item.href)
        html = self.fetch_text(url)

        signature = None
        sm = _ITEM_DECL_RE.search(html)
        if sm:
            signature = _strip_tags(sm.group("html"))

        docs = None
        dm = _ITEM_DOCBLOCK_RE.search(html)
        if dm:
            docs = _strip_tags(dm.group("html"))

        return DocItem(
            kind=item.kind,
            name=item.name,
            href=item.href,
            summary=item.summary,
            signature=signature,
            docs=docs,
        )


def module_docs_to_markdown(
    module: ModuleDocs,
    *,
    include_item_docs: bool,
    max_items: int,
    client: Optional[DocsRsClient] = None,
) -> str:
    lines: list[str] = []
    lines.append(f"# {module.module_path}")
    lines.append("")
    lines.append(f"- Crate: `{module.crate}`")
    lines.append(f"- Version: `{module.version}`")
    lines.append(f"- Source: {module.page_url}")
    lines.append("")

    base_url = module.page_url.rsplit("/", 1)[0] + "/"
    expanded_client = client or DocsRsClient()

    for section in module.sections:
        if not section.items:
            continue
        lines.append(f"## {section.title}")
        lines.append("")
        for item in section.items:
            link = urllib.parse.urljoin(base_url, item.href)
            if item.summary:
                lines.append(f"- `{item.name}` — {item.summary} ({link})")
            else:
                lines.append(f"- `{item.name}` ({link})")
        lines.append("")

        if include_item_docs:
            count = 0
            for item in section.items:
                if count >= max_items:
                    lines.append(f"_Stopped after {max_items} items (maxItems)._")
                    lines.append("")
                    break
                count += 1
                detailed = expanded_client.parse_item_page(base_url=base_url, item=item)
                lines.append(f"### {detailed.name}")
                lines.append("")
                if detailed.signature:
                    lines.append("```rust")
                    lines.append(detailed.signature)
                    lines.append("```")
                    lines.append("")
                if detailed.docs:
                    lines.append(detailed.docs)
                    lines.append("")

    return "\n".join(lines).strip() + "\n"


def module_docs_to_json(
    module: ModuleDocs,
    *,
    include_item_docs: bool,
    max_items: int,
    client: Optional[DocsRsClient] = None,
) -> str:
    base_url = module.page_url.rsplit("/", 1)[0] + "/"
    expanded_client = client or DocsRsClient()

    sections: list[dict[str, Any]] = []
    for section in module.sections:
        items: list[dict[str, Any]] = []
        for idx, item in enumerate(section.items):
            detailed = item
            if include_item_docs and idx < max_items:
                detailed = expanded_client.parse_item_page(base_url=base_url, item=item)
            items.append(
                {
                    "kind": detailed.kind,
                    "name": detailed.name,
                    "href": detailed.href,
                    "url": urllib.parse.urljoin(base_url, detailed.href),
                    "summary": detailed.summary,
                    "signature": detailed.signature,
                    "docs": detailed.docs,
                }
            )
        sections.append({"id": section.id, "title": section.title, "items": items})

    payload = {
        "crate": module.crate,
        "version": module.version,
        "modulePath": module.module_path,
        "pageUrl": module.page_url,
        "sections": sections,
    }
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def ensure_int(v: Any, *, default: int, min_value: int, max_value: int) -> int:
    if v is None:
        return default
    try:
        n = int(v)
    except Exception:
        return default
    return max(min_value, min(max_value, n))


def ensure_bool(v: Any, *, default: bool) -> bool:
    if v is None:
        return default
    if isinstance(v, bool):
        return v
    if isinstance(v, str):
        return v.strip().lower() in {"1", "true", "t", "yes", "y", "on"}
    return default


def ensure_str(v: Any, *, default: str) -> str:
    if v is None:
        return default
    if isinstance(v, str) and v.strip():
        return v.strip()
    return default


def ensure_one_of(v: Any, *, default: str, allowed: Iterable[str]) -> str:
    s = ensure_str(v, default=default)
    return s if s in set(allowed) else default
