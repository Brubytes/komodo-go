import unittest

from komodo_docs_mcp.docsrs import DocsRsClient, module_docs_to_markdown, search_all_items


class _FakeDocsRsClient(DocsRsClient):
    def __init__(self, module_html: str, item_html: str):
        super().__init__(user_agent="test")
        self._module_html = module_html
        self._item_html = item_html
        self._all_html = ""

    def with_all_html(self, all_html: str) -> "_FakeDocsRsClient":
        self._all_html = all_html
        return self

    def fetch_text(self, url: str, *, ttl_s: int = 300) -> str:  # type: ignore[override]
        if url.endswith("/komodo_client/api/read/index.html"):
            return self._module_html
        if url.endswith("/komodo_client/all.html"):
            return self._all_html
        if url.endswith("/komodo_client/api/read/struct.Foo.html"):
            return self._item_html
        raise AssertionError(f"unexpected url {url}")


class DocsRsParsingTests(unittest.TestCase):
    def test_parse_module_and_item(self) -> None:
        module_html = (
            '<span class="version">1.2.3</span>'
            '<div class="rustdoc-breadcrumbs"><a href="../../index.html">komodo_client</a>'
            '::<wbr><a href="../index.html">api</a></div>'
            '<h1>Module <span>read</span>&nbsp;</h1>'
            '<h2 id="structs" class="section-header">Structs<a href="#structs" class="anchor">§</a></h2>'
            '<dl class="item-table">'
            '<dt><a class="struct" href="struct.Foo.html" title="struct komodo_client::api::read::Foo">Foo</a></dt>'
            "<dd>Foo summary</dd>"
            "</dl>"
        )
        item_html = (
            '<pre class="rust item-decl">pub struct Foo { pub a: i32 }</pre>'
            '<div class="docblock"><p>Full docs for <code>Foo</code>.</p></div>'
        )
        client = _FakeDocsRsClient(module_html=module_html, item_html=item_html)
        module = client.parse_module(crate="komodo_client", version="latest", module_path="komodo_client::api::read")

        self.assertEqual(module.crate, "komodo_client")
        self.assertEqual(module.version, "1.2.3")
        self.assertEqual(module.module_path, "komodo_client::api::read")
        self.assertEqual(len(module.sections), 1)
        self.assertEqual(module.sections[0].title, "Structs")
        self.assertEqual(module.sections[0].items[0].name, "Foo")
        self.assertEqual(module.sections[0].items[0].summary, "Foo summary")

        detailed = client.parse_item_page(
            base_url="https://docs.rs/komodo_client/latest/komodo_client/api/read/",
            item=module.sections[0].items[0],
        )
        self.assertIn("pub struct Foo", detailed.signature or "")
        self.assertIn("Full docs for", detailed.docs or "")

    def test_markdown_rendering(self) -> None:
        module_html = (
            '<span class="version">1.2.3</span>'
            '<div class="rustdoc-breadcrumbs"><a href="../../index.html">komodo_client</a>'
            '::<wbr><a href="../index.html">api</a></div>'
            '<h1>Module <span>read</span>&nbsp;</h1>'
            '<h2 id="structs" class="section-header">Structs<a href="#structs" class="anchor">§</a></h2>'
            '<dl class="item-table">'
            '<dt><a class="struct" href="struct.Foo.html" title="struct komodo_client::api::read::Foo">Foo</a></dt>'
            "<dd>Foo summary</dd>"
            "</dl>"
        )
        item_html = (
            '<pre class="rust item-decl">pub struct Foo { pub a: i32 }</pre>'
            '<div class="docblock"><p>Full docs.</p></div>'
        )
        client = _FakeDocsRsClient(module_html=module_html, item_html=item_html)
        module = client.parse_module(crate="komodo_client", version="latest", module_path="komodo_client::api::read")
        md = module_docs_to_markdown(module, include_item_docs=True, max_items=10, client=client)
        self.assertIn("# komodo_client::api::read", md)
        self.assertIn("## Structs", md)
        self.assertIn("```rust", md)
        self.assertIn("pub struct Foo", md)

    def test_all_items_search(self) -> None:
        all_html = (
            '<span class="version">1.2.3</span>'
            '<h3 id="structs">Structs</h3>'
            '<ul class="all-items">'
            '<li><a href="entities/stack/type.StackListItem.html">entities::stack::StackListItem</a></li>'
            '<li><a href="api/read/struct.GetStacksSummary.html">api::read::GetStacksSummary</a></li>'
            "</ul>"
        )
        client = _FakeDocsRsClient(module_html="", item_html="").with_all_html(all_html)
        ver, items = client.parse_all_items(crate="komodo_client", version="latest")
        self.assertEqual(ver, "1.2.3")
        hits = search_all_items(items, query="StackListItem", limit=10)
        self.assertEqual(hits[0].item_path, "entities::stack::StackListItem")


if __name__ == "__main__":
    unittest.main()
