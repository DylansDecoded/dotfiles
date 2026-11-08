---
name: plan-executive-brief
description: Turns a Claude Code plan into an executive-level HTML decision brief. Use this whenever a plan has just been finalized or approved (the ExitPlanMode hook injects a cue to invoke it), or whenever the user asks to "summarize the plan", "make an executive summary of this plan", "turn the plan into HTML / a brief / a doc", "make this plan digestible", "exec brief", or wants a stakeholder-friendly version of a plan. Trigger even when the user doesn't say the word "skill".
metadata:
  version: 1.0.0
  category: planning
  tags: [plan, executive-summary, html, reporting]
---

# Plan Executive Brief

Distill a Claude Code plan into a one-glance executive brief and render it as a self-contained HTML document, with the full plan kept one click away in a collapsible section.

## Why this exists

A plan file is written for the engineer who will execute it: implementation detail, file lists, verification steps. A decision-maker approving that plan needs something different — what it achieves, why now, what it costs, what could go wrong, what they must decide. This skill produces that view. "Executive level" means: a stakeholder can decide whether to approve in under two minutes without reading the implementation.

## Workflow

### 1. Locate the source plan

- Default: the **most-recently-modified `*.md`** in `/Users/dylan/.claude/plans/`.
  ```bash
  ls -t /Users/dylan/.claude/plans/*.md | head -1
  ```
- If the user points at a specific plan, use that path instead.
- If no plan file exists but a plan is present in the conversation, write it to a temp `.md` and use that.

Read the plan in full before distilling.

### 2. Distill into an executive brief

Produce these fields. Cut implementation minutiae — keep what a stakeholder needs to decide. Be specific and concrete; a brief full of vague claims is useless.

- **objective** — one sentence: what this delivers.
- **why_now** — the problem or trigger; why it's worth doing.
- **what_changes** — 3–6 outcome-oriented bullets (what will be true after, not the steps).
- **scope_effort** — qualitative size: areas/files touched, rough effort, anything sequenced or blocking.
- **risks** — the real ones, each with a mitigation. Use objects `{ "risk": "...", "mitigation": "..." }`.
- **decisions_needed** — open questions or choices the stakeholder must make (omit if none).

### 3. Render the HTML

Write the fields to a **fresh, uniquely-named** temp JSON file (e.g. `/tmp/plan_brief_<plan-slug>.json` or via `mktemp`) — reusing a fixed path like `/tmp/plan_brief.json` can collide with a stale file and block the write. Match this shape, then call the renderer:

```json
{
  "title": "optional — defaults to the plan's H1",
  "objective": "…",
  "why_now": "…",
  "what_changes": ["…", "…"],
  "scope_effort": "…",
  "risks": [{ "risk": "…", "mitigation": "…" }],
  "decisions_needed": ["…"]
}
```

```bash
python3 /Users/dylan/.claude/skills/plan-executive-brief/scripts/render_brief.py \
  --plan "<plan.md>" --brief-json /tmp/plan_brief.json
```

The script wraps `assets/template.html`, converts the full plan markdown into the collapsible "Full plan detail" block, writes `<plan-slug>.html` next to the plan, and opens it. Pass `--no-open` to skip launching the browser, or `--out <path>` to override the destination.

### 4. Report and continue

Tell the user where the HTML was written. If the skill was triggered by the post-plan hook, generate the brief and then proceed with executing the approved plan — don't stall on it.

## Notes

- The HTML is fully self-contained (inline CSS, no external assets) so it's portable and prints/exports to PDF cleanly.
- The markdown converter in `render_brief.py` is dependency-free and handles the subset plans use (headings, lists, fenced code, inline code, bold, links). It uses the `markdown` package if present, otherwise its built-in fallback.
- Automatic triggering relies on the `PostToolUse`/`ExitPlanMode` hook in `settings.json` (see `scripts/plan_brief_hook.py`). The skill is equally usable on demand for any existing plan file.
