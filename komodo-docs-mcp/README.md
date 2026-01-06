# komodo-docs-mcp

An MCP (Model Context Protocol) stdio server that fetches `docs.rs` pages for the `komodo_client` crate and returns the API docs in a structured format (Markdown or JSON).

## Tools

- `komodo_docs_get_module_docs`
  - Fetches a module page (default: `komodo_client::api::read`) and returns a sectioned list of items.
  - Optionally fetches each item's page to include signature + full docs.
- `komodo_docs_search`
  - Searches the crate-wide `all.html` index by symbol name/path.
- `komodo_docs_get_item_docs`
  - Fetches a single symbol page by name/path (resolves via `komodo_docs_search`) and returns signature + docs.

## Run

```bash
python3 -m komodo_docs_mcp
```

If your MCP runner can’t set a working directory, use:

```bash
python3 /Users/jan/Development/Flutter/Projekte/komodo-go/komodo-docs-mcp/komodo_docs_mcp_stdio.py
```

## Example tool call (from an MCP client)

- `crate`: `komodo_client`
- `version`: `latest` (or an explicit version like `1.19.5`)
- `modulePath`: `komodo_client::api::read` (also accepts `komodo_client/api/read`)
- `query`: optional filter (matches name/summary, case-insensitive). For stacks-related endpoints, use `query = "stack"`.
  - `includeItemDocs`: `false` (set to `true` to fetch each item page)
  - `maxItems`: cap when `includeItemDocs=true`
  - `format`: `markdown` or `json`

For symbol lookup across the crate:

- `komodo_docs_search({ "query": "StackListItem" })`
- `komodo_docs_get_item_docs({ "item": "entities::stack::StackListItem" })`

## Notes

- This server makes outbound HTTPS requests to `docs.rs`. Ensure your MCP runner allows network access.
- Parsing is best-effort against rustdoc HTML; if docs.rs changes markup, adjust `komodo_docs_mcp/docsrs.py`.
- For stdio transport, the server supports both newline-delimited JSON (NDJSON) and `Content-Length` framing; Codex uses NDJSON.
