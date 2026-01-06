#!/usr/bin/env python3
"""
Small wrapper to start the MCP server without requiring a specific working directory.

Codex/MCP runners don't always set `cwd`, so `python -m komodo_docs_mcp` can fail
to import when launched from elsewhere. This script adds this folder to sys.path
and then runs the package entrypoint.
"""

from __future__ import annotations

import os
import sys


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)

    log_file = (os.environ.get("KOMODO_DOCS_MCP_LOG_FILE") or "").strip()
    try:
        from komodo_docs_mcp.server import main as run

        run()
    except Exception as e:
        if log_file:
            try:
                with open(log_file, "a", encoding="utf-8") as fp:
                    fp.write(f"wrapper error: {e!r}\n")
            except Exception:
                pass
        raise


if __name__ == "__main__":
    main()
