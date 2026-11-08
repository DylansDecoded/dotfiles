#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["python-docx>=1.1"]
# ///
"""Programmatic checks for resume-tailor eval outputs.

Usage: check_output.py <master.docx> <output.docx>

Prints JSON with:
  valid_docx        output opens, paragraph/style summary
  para_count        output vs master
  numbers_audit     numeric tokens in output not present in master (fabrication proxy)
  banned_words      slop/cliche hits with paragraph index
  changed_paras     indexes of paragraphs whose text differs from master (aligned by
                    exact-text matching; insertions/deletions make this approximate)
"""
import json
import re
import sys

from docx import Document

BANNED = [
    "results-driven", "proven track record", "synergy", "detail-oriented",
    "passionate about", "dynamic professional", "leverag", "robust",
    "comprehensive", "seamless", "cutting-edge", "delve", "foster",
    "harness", "underscore", "pivotal", "transformative", "game-changing",
]


def texts(path):
    return [(p.text, p.style.name) for p in Document(path).paragraphs]


def numbers(text):
    # numeric tokens incl. 40%, 7+, $185K, 6-month, 10-15, 2026
    return set(re.findall(r"[$~]?\d[\d,.]*(?:\s?%|\+|K|M)?(?:-\w+)?", text))


def main(master_path, out_path):
    master = texts(master_path)
    out = texts(out_path)
    master_text = "\n".join(t for t, _ in master)
    master_nums = numbers(master_text)
    master_set = {t.strip() for t, _ in master if t.strip()}

    report = {
        "valid_docx": True,
        "para_count": {"master": len(master), "output": len(out)},
        "styles_output": sorted({s for _, s in out}),
        "numbers_audit": [],
        "banned_words": [],
        "changed_paras": [],
    }
    for i, (t, style) in enumerate(out):
        new_nums = numbers(t) - master_nums
        if new_nums:
            report["numbers_audit"].append({"index": i, "new_numbers": sorted(new_nums), "text": t[:100]})
        low = t.lower()
        hits = [b for b in BANNED if b in low]
        if re.match(r"\s*responsible for", low):
            hits.append("'responsible for' opener")
        if hits:
            report["banned_words"].append({"index": i, "hits": hits, "text": t[:100]})
        if t.strip() and t.strip() not in master_set:
            report["changed_paras"].append({"index": i, "style": style, "text": t[:100]})
    json.dump(report, sys.stdout, indent=1, ensure_ascii=False)
    print()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    try:
        main(sys.argv[1], sys.argv[2])
    except Exception as e:  # invalid/corrupt docx
        json.dump({"valid_docx": False, "error": str(e)}, sys.stdout)
        print()
        sys.exit(1)
