---
name: resume-tailor
description: Tailor Dylan's resume to a job posting, polish work-experience entries, and log application outcomes so the skill improves over time. Use whenever the user mentions tailoring, updating, or adapting his resume or CV for a job, company, or posting; pastes a job description or JD link; asks to make his experience or a specific role "more polished" or "come off better"; reports an application outcome ("applied to X", "got a callback", "rejected by Y"); or asks what resume version went to a company. Trigger even if he doesn't say the word "resume" but is clearly preparing application materials.
---

# Resume Tailor

Tailors Dylan Robson's resume to job postings without fabricating anything, polishes the master resume on request, and learns from feedback and application outcomes.

## Files

- **Master resume (source of truth):** `~/Documents/Career/CV/DylanRobson_CV_2026.docx`
- **Tailored output:** `~/Documents/Career/CV/<Company>/DylanRobson_Resume.docx` — one folder per company (matches existing `Databricks/`, `Circle/` convention). Alongside it, write `tailoring-notes.md` (what changed and why — this is the input for outcome correlation later).
- **Memory:** `learnings.md` in this skill directory. Read its **Current Rules** section at the start of every run. Append to it at the end of every run.
- **docx helper:** `scripts/docx_io.py` (self-contained, runs via `uv run`). Use it for all docx reads and writes — do not hand-roll python-docx code or convert through other formats, or you'll lose the master's styling.

```bash
# Read a docx as structured JSON (paragraph index, style, text, run formatting)
~/.claude/skills/resume-tailor/scripts/docx_io.py extract <file.docx>

# Clone master → output, applying edits (indexes refer to the extract output)
~/.claude/skills/resume-tailor/scripts/docx_io.py apply <master.docx> <out.docx> <edits.json>
```

Edit ops: `{"op":"replace","index":N,"text":"..."}`, `{"op":"delete","index":N}`, `{"op":"insert_after","index":N,"copy_format_from":M,"text":"..."}`, and `{"op":"replace_runs","index":N,"runs":[{"text":"Label:","bold":true},{"text":"  body","bold":false}]}` for paragraphs that mix formatting. All indexes are from the original extract — the script resolves shifts itself.

## The non-negotiable: no fabrication

The whole value of this skill is that Dylan can send its output without re-auditing every line. One invented metric destroys that. So:

- You may **reorder, reword, cut, merge, and emphasize**. You may not **invent** — no new employers, titles, dates, metrics, percentages, team sizes, technologies, certifications, or client details.
- Every factual claim in the output must trace to the master resume or to something Dylan explicitly told you in this conversation.
- If the posting wants something the master doesn't show (say, Kubernetes or healthcare domain experience), do not quietly add it. Flag the gap and ask: "The posting emphasizes X — do you have real experience with it? Give me the specifics and I'll work it in." Only add what he confirms, in his words, and note in `tailoring-notes.md` that it was user-supplied.
- Rewording numbers is fine ("roughly 40%" → "~40%"); changing them is not. "Reducing deployment time by 40%" cannot become "50%" or gain a dollar figure.

## Mode 1: Tailor to a posting

Trigger: a job posting is pasted, linked, or attached; "tailor my resume for X".

1. Read `learnings.md` Current Rules, extract the master via the script, and get the posting (if it's a URL, fetch it; if fetch fails, ask for a paste).
2. Analyze the posting: hard requirements, nice-to-haves, seniority signal, domain, and the exact vocabulary it uses. Where Dylan has the experience under a different name, adopt the posting's term (their "lakehouse platform" over our "medallion architecture") — recruiters and ATS both match on their words, not ours.
3. Plan the tailoring before editing: which bullets to promote, cut, or reword; what the professional summary should lead with; which Core Competencies lines to reorder. Bullets within a job should be reordered so the most posting-relevant come first. Keep total length at or under the master's.
4. Build the edits JSON and produce the tailored docx with the script. Prefer editing the summary, competencies, and bullets. Check the extract's `runs` before choosing an op: uniform-format paragraphs (bullets, summary) take `replace`; mixed-format ones (the bold-label Core Competencies lines, the `Title | Company | City<tab>Dates` headers) need `replace_runs` or plain `replace` will flatten the bold. Leave the name/contact header alone.
5. Run the self-checks (below). Fix what fails.
6. Write `tailoring-notes.md` next to the output: posting summary, what changed and why, keyword-coverage table (requirement → where the resume now answers it, or "gap — flagged"), and any user-supplied additions.
7. Show Dylan the change summary and coverage table (not the whole resume dump), tell him the file path, and ask for reactions. Log the run and any feedback in `learnings.md`.

## Mode 2: Polish the master

Trigger: "update my work experience for X company to come off more polished", "tighten up the EY section", etc. This edits the **master**, since it's the source all tailoring flows from.

1. Back up first: copy the master to `~/Documents/Career/CV/backups/DylanRobson_CV_2026.<YYYY-MM-DD>.docx` (create the folder if needed).
2. Extract the relevant section and rewrite the bullets: lead with the outcome, cut filler, prefer concrete verbs, keep every fact identical. If a bullet is vague ("worked on various data initiatives"), don't decorate it — ask Dylan for the specifics that would make it concrete, or tighten it honestly.
3. Show before/after per bullet in the conversation and apply to the master only after he approves. He may approve a subset — apply exactly that.
4. Log what he approved vs. rejected in `learnings.md`; rejected phrasings are some of the best signal this skill gets.

## Mode 3: Outcomes and feedback

Trigger: "applied to X", "got a callback from X", "rejected by Y", "the recruiter said…", or any comment on a past output.

1. Append a row to the Outcome Log in `learnings.md` (date, company, role, resume file, outcome, notes).
2. Read that company's `tailoring-notes.md` and connect the outcome to the choices made: what was emphasized, what gaps existed, what phrasing was used.
3. If a pattern has 2+ supporting entries (e.g. callbacks when GenAI delivery leads the summary; silence when gaps were papered over with adjacent-sounding bullets), promote it to a numbered Current Rule. One-off datapoints stay in the log — a single rejection proves nothing about phrasing.

## Self-checks (every tailoring or polish run)

1. **Fabrication audit** — extract the produced docx and check every changed paragraph: each fact must exist in the master or in Dylan's messages this session. Anything else gets removed before delivery, not flagged for later.
2. **Slop scan** — reject resume clichés (*results-driven, dynamic, passionate, detail-oriented, proven track record, synergy, responsible for* as a bullet opener) and the banned-word list in Dylan's global style rules (*leverage, robust, comprehensive, seamless, cutting-edge, spearheaded* more than once…). Rewrite hits with plain, specific language.
3. **Coverage honesty** — the keyword table in `tailoring-notes.md` must mark real gaps as gaps. A tailored resume that pretends to cover everything is a fabrication with extra steps.
4. **Format spot-check** — extract the output and confirm paragraph count and styles look sane (no collapsed bullets, no lost section headers).

If a self-check keeps failing across runs, that's a learnings entry: record what kept slipping through so future runs watch for it.

## The learnings loop

`learnings.md` is why run #30 should beat run #1. At the start of every run, read Current Rules and apply them. At the end, append an entry: date, mode, company, what you did, feedback received, self-check failures. Distill repeated observations into Current Rules — keep the rules list short and sharp (prune rules that stop earning their place). Never store resume content or posting text there, only lessons.
