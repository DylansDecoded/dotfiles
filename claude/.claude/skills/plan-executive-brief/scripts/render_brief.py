#!/usr/bin/env python3
"""Render an executive HTML brief from a plan markdown file + a distilled brief JSON.

The skill (Claude) supplies the judgment — a JSON object with the executive
fields. This script does the deterministic part: wrap the bundled template,
convert the full plan markdown into the collapsible detail block, write the
HTML next to the plan, and open it.

Usage:
  render_brief.py --plan <plan.md> --brief-json <brief.json> [--no-open] [--out <path>]
"""
import argparse
import html
import json
import os
import re
import subprocess
import sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "..", "assets", "template.html")


# --------------------------------------------------------------------------- #
# Minimal, dependency-free markdown -> HTML for the "full plan" detail block.
# Handles the subset plans actually use: headings, lists, fenced code, inline
# code, bold, links, paragraphs. Everything is HTML-escaped first so unknown
# content is preserved safely rather than injected.
# --------------------------------------------------------------------------- #
def _inline(text):
    text = html.escape(text, quote=False)
    # protect inline code spans from further formatting
    spans = []

    def stash(m):
        spans.append(m.group(1))
        return f"\x00{len(spans) - 1}\x00"

    text = re.sub(r"`([^`]+)`", stash, text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(
        r"\[([^\]]+)\]\(([^)\s]+)\)",
        lambda m: f'<a href="{html.escape(m.group(2), quote=True)}">{m.group(1)}</a>',
        text,
    )
    text = re.sub(r"\x00(\d+)\x00", lambda m: f"<code>{spans[int(m.group(1))]}</code>", text)
    return text


def _split_row(line):
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


def _is_table_sep(line):
    if "|" not in line and "-" not in line:
        return False
    cells = _split_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{1,}:?", c or "") for c in cells)


def _render_table(header, rows):
    th = "".join(f"<th>{_inline(c)}</th>" for c in header)
    trs = []
    for r in rows:
        cells = (r + [""] * len(header))[: len(header)]
        trs.append("<tr>" + "".join(f"<td>{_inline(c)}</td>" for c in cells) + "</tr>")
    return f"<table><thead><tr>{th}</tr></thead><tbody>{''.join(trs)}</tbody></table>"


def markdown_to_html(md):
    # Prefer the real library if it happens to be installed; otherwise fall back.
    try:
        import markdown as _md  # type: ignore

        return _md.markdown(md, extensions=["fenced_code", "tables"])
    except Exception:
        pass

    lines = md.replace("\r\n", "\n").split("\n")
    out = []
    i = 0
    n = len(lines)

    def close_list(stack):
        while stack:
            out.append(f"</{stack.pop()}>")

    list_stack = []
    while i < n:
        line = lines[i]

        # fenced code block
        m = re.match(r"^\s*```(\w*)\s*$", line)
        if m:
            close_list(list_stack)
            i += 1
            buf = []
            while i < n and not re.match(r"^\s*```\s*$", lines[i]):
                buf.append(html.escape(lines[i], quote=False))
                i += 1
            i += 1  # skip closing fence
            out.append("<pre><code>" + "\n".join(buf) + "</code></pre>")
            continue

        # headings
        m = re.match(r"^(#{1,4})\s+(.*)$", line)
        if m:
            close_list(list_stack)
            level = len(m.group(1))
            out.append(f"<h{level}>{_inline(m.group(2).strip())}</h{level}>")
            i += 1
            continue

        # GFM table: a header row followed by a |---|---| separator row
        if "|" in line and i + 1 < n and _is_table_sep(lines[i + 1]):
            close_list(list_stack)
            header = _split_row(line)
            i += 2  # consume header + separator
            rows = []
            while i < n and lines[i].strip() and "|" in lines[i]:
                rows.append(_split_row(lines[i]))
                i += 1
            out.append(_render_table(header, rows))
            continue

        # list items (one level of nesting via indentation)
        m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
        if m:
            indent = len(m.group(1))
            ordered = m.group(2).endswith(".")
            tag = "ol" if ordered else "ul"
            depth = 1 if indent >= 2 else 0
            # adjust nesting
            while len(list_stack) > depth + 1:
                out.append(f"</{list_stack.pop()}>")
            if len(list_stack) < depth + 1:
                out.append(f"<{tag}>")
                list_stack.append(tag)
            out.append(f"<li>{_inline(m.group(3).strip())}</li>")
            i += 1
            continue

        # blank line
        if line.strip() == "":
            close_list(list_stack)
            i += 1
            continue

        # paragraph (gather consecutive non-empty, non-structural lines)
        close_list(list_stack)
        buf = [line.strip()]
        i += 1
        while i < n and lines[i].strip() != "" and not re.match(
            r"^(\s*```|#{1,4}\s|\s*([-*]|\d+\.)\s|\s*\|)", lines[i]
        ):
            buf.append(lines[i].strip())
            i += 1
        out.append("<p>" + _inline(" ".join(buf)) + "</p>")

    close_list(list_stack)
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# Executive-brief section builder
# --------------------------------------------------------------------------- #
def _esc(s):
    return html.escape(str(s), quote=False)


def _field(label, inner):
    return f'<div class="field"><div class="label">{_esc(label)}</div>{inner}</div>'


def _list(items, cls=""):
    cls = f' class="{cls}"' if cls else ""
    lis = "\n".join(f"<li>{_inline(str(x))}</li>" for x in items if str(x).strip())
    return f"<ul{cls}>{lis}</ul>"


def build_brief(b):
    parts = []
    if b.get("objective"):
        parts.append(_field("Objective", f'<p class="objective">{_inline(b["objective"])}</p>'))
    if b.get("why_now"):
        parts.append(_field("Why now", f"<p>{_inline(b['why_now'])}</p>"))
    if b.get("what_changes"):
        parts.append(_field("What changes", _list(b["what_changes"])))
    if b.get("scope_effort"):
        parts.append(_field("Scope & effort", f"<p>{_inline(b['scope_effort'])}</p>"))
    if b.get("risks"):
        risk_lis = []
        for r in b["risks"]:
            if isinstance(r, dict):
                line = f'<li class="risk">{_inline(r.get("risk", ""))}'
                if r.get("mitigation"):
                    line += f'<span class="mit">{_inline(r["mitigation"])}</span>'
                line += "</li>"
            else:
                line = f'<li class="risk">{_inline(str(r))}</li>'
            risk_lis.append(line)
        parts.append(_field("Key risks", "<ul>" + "\n".join(risk_lis) + "</ul>"))
    if b.get("decisions_needed"):
        parts.append(_field("Decisions needed", _list(b["decisions_needed"], cls="pill-decisions")))
    return "\n".join(parts)


def derive_title(brief, plan_md, plan_path):
    if brief.get("title"):
        return brief["title"]
    for line in plan_md.splitlines():
        m = re.match(r"^#\s+(.*)$", line)
        if m:
            return m.group(1).strip()
    return os.path.splitext(os.path.basename(plan_path))[0].replace("-", " ").title()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True)
    ap.add_argument("--brief-json", required=True)
    ap.add_argument("--out")
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args()

    with open(args.plan, encoding="utf-8") as f:
        plan_md = f.read()
    with open(args.brief_json, encoding="utf-8") as f:
        brief = json.load(f)
    with open(TEMPLATE, encoding="utf-8") as f:
        template = f.read()

    title = derive_title(brief, plan_md, args.plan)
    generated = datetime.now().strftime("%B %-d, %Y at %-I:%M %p")

    out_html = (
        template.replace("{{TITLE}}", _esc(title))
        .replace("{{GENERATED_AT}}", _esc(generated))
        .replace("{{EXEC_BRIEF}}", build_brief(brief))
        .replace("{{FULL_PLAN}}", markdown_to_html(plan_md))
    )

    out_path = args.out or os.path.splitext(args.plan)[0] + ".html"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(out_html)

    print(out_path)

    if not args.no_open:
        try:
            subprocess.run(["open", out_path], check=False)
        except Exception as e:  # noqa: BLE001
            print(f"(could not auto-open: {e})", file=sys.stderr)


if __name__ == "__main__":
    main()
