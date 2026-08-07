# Resume Tailoring Learnings

Read Current Rules before every run. Append an entry after every run, piece of feedback, or outcome. Promote patterns with 2+ supporting entries into Current Rules; prune rules that stop earning their place. Lessons only — no resume content or posting text in this file.

## Current Rules

1. (seed) Use the posting's vocabulary for skills Dylan actually has — their term beats ours for both recruiters and ATS.
2. (seed) Lead bullets with the outcome, not the activity ("Cut deployment time ~40% by…" over "Responsible for building…").
3. (seed) Dylan's field is data/AI consulting: postings usually weigh platform depth (Databricks, Foundry, Snowflake) and GenAI delivery over generic leadership language. Reorder to show those first when the posting asks.

## Outcome Log

| Date | Company | Role | Resume file | Outcome | Notes |
|------|---------|------|-------------|---------|-------|

## Entry Log

### 2026-07-11 — skill created
Seed rules above come from Dylan's global writing style and resume conventions, not observed outcomes. Treat them as provisional until run data confirms them.

### 2026-08-04 — Mode 2 master polish (research-driven)
Applied deep-research findings (consulting + Databricks resume best practices) to the master: 11 bullet rewrites (weak openers, run-ons, garbled phrasing), removed "Proven" from summary, deleted 2 stray empty paragraphs, restyled intern bullets to List Paragraph, theme font Times New Roman → Calibri, line spacing 1.16 → single. Dylan approved via "go ahead and improve"; delivered docx + PDF. No new metrics added — Dylan didn't supply numbers for the flagged gaps (CapTech QSR scale, IaC accelerator reuse, Tallan cost reduction, Hylaine POC count); revisit next run.
Tooling lessons: (1) docx_io.py silently dropped a `delete` that followed two `insert_after` ops near the same indexes — always re-extract and verify after apply. (2) Word AppleScript/JXA/docx2pdf all hang on this machine (likely dialog); LibreOffice (`soffice --headless --convert-to pdf`) is the working PDF path. (3) macOS `mdls` page counts go stale — parse the PDF's /Count instead. (4) Doc paragraphs carry explicit `w:spacing` overrides, so docDefaults spacing edits are no-ops; line-height lives only in docDefaults.
Resolved cosmetic issue: the wide word gaps in the first two CapTech bullets were NOT justification — they were `w:hint="eastAsia"` on the runs (doc default lang is zh-CN), triggering East Asian spacing rules. Stripping the hint attribute fixed it. Watch for eastAsia hints in any doc originally authored with a Chinese-locale Word.

### 2026-07-11 — iteration-1 eval (TELUS tailor, Veryon tailor, CapTech polish)
Skill runs passed 18/18 assertions; Dylan approved both tailoring outputs ("looks great" / "looks good") with no change requests. Baseline runs without the skill failed on fabrication both times, in the same way: JD-verbatim phrases transplanted into the summary/competencies as claims ("software estimation and work planning", "human-in-the-loop design", "change management"). Lesson: the highest-risk fabrication surface is the Core Competencies and summary lines, where posting vocabulary slides in as an unearned skill claim — audit those hardest. Known tooling ceiling: competency lines carry bold-label mixed runs that docx_io.py's whole-paragraph replace would flatten, so runs currently leave them unedited (reordering them is legitimately useful; needs a run-preserving edit op).
