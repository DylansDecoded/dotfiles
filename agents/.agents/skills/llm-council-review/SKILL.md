---
name: llm-council-review
description: Agent-agnostic "grill me, then get a council of other LLMs to attack the plan" workflow. Use when the user says "/llm-council-review", "council review", "grill me then get the council on it", "have the other models review this plan", "cross-model review", "get codex and grok to review", "stress-test this plan against other LLMs", or is about to build something high-stakes (auth, schema, concurrency, migrations, payments) and wants alignment plus a multi-model sanity check before code. Works from ANY host CLI — Claude Code, Codex, Grok, Kimi, or opencode — and auto-discovers the OTHER LLM CLIs installed on the machine to form the review council (e.g. host=codex → council=claude+grok+kimi+opencode). Act 1: the host interviews the user one question at a time until the decision tree is resolved and writes PLAN.md. Act 2: every council member adversarially reviews PLAN.md read-only (VERDICT: APPROVED/REVISE) in persistent sessions until all approve or MAX_ROUNDS, then the user signs off. Prefer this over /grill-me-codex when the host is not Claude or when more than Codex/Kimi should weigh in. NOT for reviewing written code and NOT for trivial changes.
---

# LLM Council Review

Same two acts as `grill-me-codex`, with two differences: the **host** is whichever agent is reading this (Claude, Codex, Grok, Kimi, or opencode), and the **council** is every other LLM CLI on the machine rather than a hard-coded Codex.

- **Act 1 — Grill.** You interrogate the user until intent is locked. (Matt Pocock's `grill-me`, MIT — see `THIRD-PARTY-NOTICES.md`.)
- **Act 2 — Council.** Each other model attacks the locked plan, read-only, in its own persistent session. Several models from several labs means no single model's blind spots survive.

The user appears exactly twice: answering the grill, and signing off the converged plan. No code is written in either act.

---

## ACT 1 — GRILL (user ↔ host)

> Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.
>
> Ask the questions one at a time, waiting for my answer before continuing.
>
> If a question can be answered by exploring the codebase, explore the codebase instead.

### Docs-aware mode (automatic when the project has living docs)

If `CONTEXT.md` (or `CONTEXT-MAP.md`) or `docs/adr/` exists, or the user asks to be grilled "against the docs":

- Challenge the user's wording against the glossary; propose precise canonical terms for overloaded ones.
- Stress-test boundaries between domain concepts with concrete scenarios; surface code that contradicts what the user just said.
- Update `CONTEXT.md` inline as each term resolves (format: `CONTEXT-FORMAT.md`). It's a glossary only.
- Offer an ADR only when a decision is hard to reverse AND surprising without context AND a real trade-off (format: `ADR-FORMAT.md`).
- Create these files lazily, never scaffold empty ones. No docs and no request → grill normally.

When the tree is resolved, write `PLAN.md`:

```markdown
# Plan: <task>
_Locked via grill — by <host> + <user>_

## Goal
## Approach            (numbered, concrete steps)
## Key decisions & tradeoffs   (name the contestable choices so the council has something to bite)
## Risks / open questions
## Out of scope
```

Initialize `PLAN-REVIEW-LOG.md` with `# Plan Review Log: <task>` and a line naming the host, the council, and `MAX_ROUNDS`.

---

## ACT 2 — COUNCIL (host ↔ other CLIs)

### 1. Resolve tunables
| Var | Default | Meaning |
|-----|---------|---------|
| `HOST` | whatever you are | `claude`, `codex`, `grok`, `kimi`, or `opencode`. You know which CLI you're running in; never put yourself on the council. |
| `REVIEWERS` | all others found on PATH | Comma list to override, e.g. `reviewers=codex,grok`. |
| `MAX_ROUNDS` | `5` | Hard cap. The loop always terminates here. |
| `PLAN_FILE` / `LOG_FILE` | `PLAN.md` / `PLAN-REVIEW-LOG.md` | |

Discover the council and echo it before starting:
```bash
scripts/council-discover.sh "$HOST"
```
Zero reviewers found → say so and stop; a council of none is not a review. One reviewer is fine (that's `grill-me-codex` with a different name).

Two things to tell the user up front: cost and time. Each round runs every reviewer with a fresh read of the repo; `claude` in particular loads a large context and can cost a dollar or two per round. If the repo has heavy uncommitted work and `kimi` is on the council, warn that Kimi has no sandbox (see `reviewers.md`) and offer to drop it.

### 2. Snapshot the repo
```bash
git status --porcelain=v1 -uall > /tmp/council-baseline.txt
```
Re-check after every round. Any diff means a reviewer wrote to the repo → STOP, show the user what changed, do not auto-revert.

### 3. The review prompt (identical for every reviewer, every round)
Round 1, save to `/tmp/council-prompt.txt`:
> You are an adversarial reviewer for an implementation plan. Be skeptical and specific — your job is to find what breaks, not to be agreeable. Read the plan at `PLAN.md` (and `CONTEXT.md`/ADRs for the domain language, if present) and any repo files you need (you are read-only). Identify concrete flaws: security holes, race conditions, missing edge cases, schema conflicts, domain-language mismatches, wrong assumptions, observability gaps, simpler alternatives. For each, give a one-line fix. Do NOT modify any files. End your reply with EXACTLY one line: `VERDICT: APPROVED` if the plan is sound enough to implement, or `VERDICT: REVISE` if it still has material problems.

Rounds 2+:
> I revised the plan. Re-review PLAN.md — check whether your prior findings are addressed and flag anything new. End with VERDICT: APPROVED or VERDICT: REVISE.

### 4. Run a round — all reviewers in parallel
```bash
R=1; for r in $REVIEWERS; do scripts/council-run.sh "$r" "$R" /tmp/council-prompt.txt /tmp/council & done; wait
```
`council-run.sh` owns the per-CLI mechanics (read-only flags, session capture, resume, 10-minute ceiling, output parsing) — see `reviewers.md` for what each adapter does and why. It writes `/tmp/council/<reviewer>.round<N>.txt` and prints `<reviewer>: VERDICT: …`. A non-zero exit means that reviewer failed (auth, model, timeout): stop and tell the user which one, don't retry blind and don't quietly continue with a smaller council.

Give the shell call a generous timeout (Claude Code: `timeout: 660000` on the Bash tool; other hosts: whatever their tool ceiling is). The script's own `perl alarm` guard fails loud at 600s per reviewer; macOS ships no `timeout`.

### 5. After each round
1. Append each critique to `LOG_FILE` under `## Round <n> — <reviewer>`.
2. All reviewers `APPROVED` on this plan version → converged, go to Resolution.
3. Any `REVISE` → you are the arbiter. Merge the critiques; where reviewers disagree with each other, log it — cross-model disagreement is the most useful signal this skill produces. Revise `PLAN_FILE` once, append `### <host>'s response` (what changed, what was rejected and why), increment the round.
4. Round > `MAX_ROUNDS` → deadlock, go to Resolution.

### Resolution (the user's final gate)
- **Converged:** present the final plan, a 3-bullet summary of what the two acts improved, and a per-reviewer round count. Ask: *"Grilled + survived N rounds of <council>. Implement it now?"* Code only on yes.
- **Deadlock:** don't fake it. List each unresolved point, which reviewer holds it, and your counter-position. The user breaks the tie.

---

## Hard rules
- Act 1 before Act 2. No `PLAN.md` until the grill has actually resolved the tree with the user.
- Never put the host on its own council. A model reviewing its own plan is the echo chamber this skill exists to avoid.
- Read-only every round, enforced per CLI by `council-run.sh`; the post-round `git status` diff is the backstop for the one CLI (Kimi) that has no enforcement.
- The loop terminates at `MAX_ROUNDS`. Reviewers advise; the host decides, and logs why when it rejects a critique.
- `LOG_FILE` is the deliverable. Keep the whole argument.

## What NOT to do
- Don't review already-written code — this is for plans.
- Don't pin models (`-m`, `--model`) on any reviewer; use each CLI's configured default. Pinning `gpt-5.x-codex` variants 400s on ChatGPT-account auth.
- Don't pass `--yolo`, `-y`, `--always-approve`, `--dangerously-skip-permissions`, or `bypassPermissions` to any reviewer.
- Don't shrink the council silently when a member fails. Surface it.
