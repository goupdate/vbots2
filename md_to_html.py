#!/usr/bin/env python3
"""Convert all .md in .omo/ to .html with code highlighting."""

import markdown
import pathlib
import re
import sys

OMO = pathlib.Path(__file__).parent

HEAD = """<!DOCTYPE html><html lang="ru"><meta charset="utf-8">
<title>{title}</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
<script>hljs.highlightAll()</script>
<style>
  body {{ max-width: 900px; margin: 2em auto; padding: 0 1em; font: 16px/1.6 system-ui, sans-serif; color: #222; }}
  ul, ol {{ padding-left: 1.5em; margin: .5em 0; }}
  li {{ margin: .2em 0; }}
  pre {{ background: #f6f8fa; padding: 1em; border-radius: 6px; overflow-x: auto; }}
  code {{ background: #f0f0f0; padding: .15em .3em; border-radius: 3px; font-size: .9em; }}
  pre code {{ background: none; padding: 0; }}
  table {{ border-collapse: collapse; width: 100%; }}
  th, td {{ border: 1px solid #ddd; padding: .5em; text-align: left; }}
  th {{ background: #f6f8fa; }}
  h1, h2, h3 {{ margin-top: 1.5em; }}
</style>
"""

def fix_lists(text: str) -> str:
    """Insert blank line before bullet lists, and move inline '-' to new line."""
    # Move inline bullet markers to their own line: "Text: - item" → "Text:\n- item"
    text = re.sub(r"([^\n]):?\s*- \b", r"\1\n\n- ", text)
    # Insert blank line before list items that lack one
    lines = text.splitlines(keepends=True)
    out = []
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if stripped.startswith(("- ", "* ", "+ ")) or re.match(r"^\d+\.\s", stripped):
            if out and out[-1].rstrip() != "":
                out.append("\n")
        out.append(line)
    return "".join(out)

def convert_one(path: pathlib.Path) -> pathlib.Path:
    md = path.read_text(encoding="utf-8")
    md = fix_lists(md)
    title = md.split("\n", 1)[0].lstrip("# ").strip() if md.startswith("#") else path.stem
    body = markdown.markdown(md, extensions=["extra", "fenced_code", "tables"])
    html = HEAD.format(title=title) + body + "</html>"
    out = path.with_suffix(".html")
    out.write_text(html, encoding="utf-8")
    return out

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <file.md>")
        sys.exit(1)
    path = pathlib.Path(sys.argv[1])
    if not path.exists():
        print(f"File not found: {path}")
        sys.exit(1)
    out = convert_one(path)
    print(f"OK  {path.name} -> {out.name}")

if __name__ == "__main__":
    main()
