---
name: grill-me-codex
description: Use when the user says "/grill-me-codex", "grill me then have codex review", "grill me then have kimi review", "grill me and stress-test the plan", "grill me against the docs", "stress-test this against our domain model", "interview me about this plan then get a second model on it", "get codex and kimi to review the plan", or is about to build something high-stakes (auth, schema, concurrency, migrations, payments) and wants both alignment AND a cross-model sanity check before implementation. Two acts — ACT 1: Claude interviews you relentlessly, one question at a time, until every branch of the decision tree is resolved; in projects with CONTEXT.md/ADRs it also challenges terms against the glossary and updates the docs inline. ACT 2: the locked plan goes to PLAN.md and a second model — OpenAI Codex by default, Moonshot Kimi via reviewer=kimi, or both — adversarially reviews it read-only (VERDICT:APPROVED/REVISE) in the same session until approval or MAX_ROUNDS, then you sign off before code. If you already have a plan use /codex-review. NOT for reviewing written code (/codex:review) and NOT for trivial changes.
---

# Grill-Me-Codex — Get Grilled, Then Get Reviewed

Two acts, two different jobs:

- **Act 1 fixes the #1 failure mode: building the wrong thing.** Claude interrogates *you* until intent is locked — no guessing at ambiguity. (This act is Matt Pocock's `grill-me`, used under MIT — see `THIRD-PARTY-NOTICES.md`.)
- **Act 2 fixes the #2 failure mode: a plan that sounds right but breaks.** A *different model* — Codex (default), Kimi, or both — adversarially attacks the locked plan. Cross-model = no echo chamber.

You enter at two points only: answering the grill, and signing off the converged plan. The reviewer is read-only the whole time and never touches a file.

---

## ACT 1 — GRILL (you ↔ Claude)

> Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.
>
> Ask the questions one at a time, waiting for my answer before continuing.
>
> If a question can be answered by exploring the codebase, explore the codebase instead.

### Docs-aware mode (automatic when the project has living docs)

While exploring, check for `CONTEXT.md` (or `CONTEXT-MAP.md` pointing at per-context `CONTEXT.md` files) and `docs/adr/`. If any exist — or the user asks to be grilled "against the docs" — layer these behaviors onto the grill (adapted from Matt Pocock's `grill-with-docs`, MIT):

- **Challenge against the glossary.** If the user's wording conflicts with `CONTEXT.md`, call it out: "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"
- **Sharpen fuzzy terms.** Propose a precise canonical term when the user says something overloaded ("account" — Customer or User?).
- **Stress-test with concrete scenarios** that probe the boundaries between domain concepts.
- **Cross-reference with code.** If the code contradicts what the user just said, surface it.
- **Update `CONTEXT.md` inline** as each term is resolved — don't batch. Format per [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md). `CONTEXT.md` is a glossary and nothing else: no implementation details, no spec, no scratch pad.
- **Offer ADRs sparingly** — only when a decision is (1) hard to reverse, (2) surprising without context, AND (3) a real trade-off. All three or skip it. Format per [ADR-FORMAT.md](./ADR-FORMAT.md).
- **Create files lazily.** No `CONTEXT.md`? Create it when the first term is resolved. No `docs/adr/`? Create it when the first ADR is warranted. Don't scaffold empty docs in a project that has none and didn't ask.

If the project has no such docs and the user didn't ask for them, grill normally — don't introduce a docs layer uninvited.

When the decision tree is resolved (and any glossary/ADR updates are written), **write the agreed plan to `PLAN.md`** in this structure — using the canonical terms from `CONTEXT.md` when docs-aware mode was active — then move to Act 2:

```markdown
# Plan: <task>
_Locked via grill — by Claude + <user>_

## Goal
<one paragraph — reflects what the grilling actually settled>

## Approach
<numbered, concrete steps>

## Key decisions & tradeoffs
<the contestable choices the grill resolved — name them so Codex has something to bite>

## Risks / open questions
<anything still genuinely open>

## Out of scope
<bounds the grill established>
```

Initialize `PLAN-REVIEW-LOG.md`:
```markdown
# Plan Review Log: <task>
Act 1 (grill) complete — plan locked with the user. MAX_ROUNDS=<n>.
```

---

## ACT 2 — REVIEW (Claude ↔ Reviewer)

Now hand the locked plan to a second model for adversarial review. Codex mechanics verified end-to-end 2026-06-04; Kimi mechanics verified 2026-07-21 (kimi 0.28.1).

### Tunables (read from args, else default)
| Var | Default | Meaning |
|-----|---------|---------|
| `REVIEWER` | `codex` | `codex`, `kimi`, or `both`. `both` runs each round past both models; converged only when both say APPROVED on the same plan version. |
| `MAX_ROUNDS` | `5` | Hard cap on review rounds. The loop ALWAYS terminates here. |
| `PLAN_FILE` | `PLAN.md` | The plan Act 1 produced. |
| `LOG_FILE` | `PLAN-REVIEW-LOG.md` | Append-only argument transcript. The artifact. |

If invoked with e.g. `rounds=3` or `reviewer=kimi`, use those. Echo resolved values before starting.

### Prerequisites (verify once, fast)
**Codex** (`REVIEWER=codex` or `both`):
- `codex --version` ≥ 0.130 (older CLIs error on the default `gpt-5.5` model).
- Codex authenticated (prior `codex login`; ChatGPT account is fine). On auth/model error, surface it — don't silently retry.
- Do NOT pin `-m`. Use the config default. Pinning `gpt-5.x-codex` variants 400s on ChatGPT-account auth.

**Kimi** (`REVIEWER=kimi` or `both`):
- `kimi --version` ≥ 0.28 and authenticated (prior `kimi login`). On auth error, surface it.
- Use the config default model — don't pin `-m`.
- **Kimi has no read-only sandbox.** In prompt mode it executes tools — including file writes — without asking. Read-only is enforced by contract + verification (see the Kimi section below), so require a clean-enough `git status` baseline before starting: snapshot `git status --porcelain=v1 -uall` output now and keep it for per-round comparison.

### The review prompt (sent each round, identical for every reviewer)
> You are an adversarial reviewer for an implementation plan. Be skeptical and specific — your job is to find what breaks, not to be agreeable. Read the plan at `PLAN.md` (and `CONTEXT.md`/ADRs for the domain language, if present) and any repo files you need (you are read-only). Identify concrete flaws: security holes, race conditions, missing edge cases, schema conflicts, domain-language mismatches, wrong assumptions, observability gaps, simpler alternatives. For each, give a one-line fix. Do NOT modify any files. End your reply with EXACTLY one line: `VERDICT: APPROVED` if the plan is sound enough to implement, or `VERDICT: REVISE` if it still has material problems.

### Codex mechanics (`REVIEWER=codex` or `both`)

#### Round 1 — fresh session (capture `thread_id`)
```bash
codex exec -s read-only --json -o /tmp/codex-verdict.txt "$(cat REVIEW_PROMPT)" \
  < /dev/null 2>/dev/null | grep '"type":"thread.started"'
```
Parse `thread_id` from the `{"type":"thread.started","thread_id":"..."}` line → that's `THREAD_ID`. The critique is in `/tmp/codex-verdict.txt`. Confirm success by the verdict file + a `thread.started` line; if neither appears, the run failed (auth/model) — stop and tell the user. `2>/dev/null` suppresses cosmetic MCP/auth stderr noise. **`< /dev/null` is mandatory:** `codex exec` reads stdin *in addition to* the prompt arg, so under a non-interactive driver (Claude Code's Bash tool, CI, any non-TTY pipeline) it blocks forever waiting on stdin EOF — a silent ~0% CPU hang. The redirect gives it immediate EOF.

#### Rounds 2..MAX — resume the SAME session (Codex remembers its prior critiques)
```bash
# resume REJECTS -s. Force read-only via -c sandbox_mode, or Codex inherits
# config.toml (possibly danger-full-access) and could WRITE files. This is the
# single most important safety line in the skill — verified 2026-06-04.
codex exec resume "$THREAD_ID" -c sandbox_mode="read-only" --json \
  -o /tmp/codex-verdict.txt \
  "I revised the plan. Re-review PLAN.md — check whether your prior findings are addressed and flag anything new. End with VERDICT: APPROVED or VERDICT: REVISE." \
  < /dev/null 2>/dev/null >/dev/null
```
Both `codex exec` and `codex exec resume` support `--json` and `-o/--output-last-message`. The `< /dev/null` redirect is required on the resume call too — same non-interactive stdin hang as Round 1.

**Timeout guard (both rounds):** run every `codex exec` / `codex exec resume` with a 10-minute ceiling so any future stall fails loud instead of hanging silently. Via Claude Code's Bash tool, pass `timeout: 600000` on the tool call (the default 2-minute tool timeout is too short for real reviews and would kill them mid-run). In a plain shell, prefix the command with `timeout 600` (Linux / Git Bash) or `gtimeout 600` (macOS via coreutils — stock macOS has no `timeout`). If the ceiling trips, treat it as a failed run: stop and tell the user rather than retrying blind.

### Kimi mechanics (`REVIEWER=kimi` or `both`)

Same review prompt, same verdict contract. Kimi's prompt mode prints the critique to stdout and appends a resume hint, so no `--json` parsing dance is needed.

#### Round 1 — fresh session (capture `session_id`)
```bash
kimi -p "$(cat REVIEW_PROMPT)" > /tmp/kimi-verdict.txt 2>/dev/null
```
The critique is the file body; the last line reads `To resume this session: kimi -r session_<uuid>` — parse `session_<uuid>` → that's `SESSION_ID`. (No stdin redirect needed — verified non-interactively; kimi prompt mode doesn't block on stdin the way `codex exec` does.) If the file is empty or has no resume hint, the run failed (auth/model) — stop and tell the user.

#### Rounds 2..MAX — resume the SAME session (`-S`, not the hint's `-r`)
```bash
kimi -S "$SESSION_ID" -p "I revised the plan. Re-review PLAN.md — check whether your prior findings are addressed and flag anything new. End with VERDICT: APPROVED or VERDICT: REVISE." \
  > /tmp/kimi-verdict.txt 2>/dev/null
```
Resume with memory verified: `-S <id> -p` recalls the prior rounds. The hint line says `-r`; use `-S` — it's the documented flag and verified working.

The same 10-minute timeout guard applies to every kimi call.

#### Read-only is contract + verification, not a flag — the Kimi safety line
`codex` has `-s read-only`; `kimi` has nothing equivalent, and in prompt mode it WILL write files without asking (verified 2026-07-21: it created a file on request with no `--yolo`). So:
1. The review prompt's "Do NOT modify any files" is the contract.
2. **After every kimi round**, re-run `git status --porcelain=v1 -uall` and diff against the pre-Act-2 snapshot. Any change → STOP. Show the user exactly what changed and let them decide how to restore — do NOT auto-revert (that could clobber their own uncommitted work).
3. If the repo has significant uncommitted work the user can't afford to risk, say so and recommend `reviewer=codex` for this run.

### Each round, after the reviewer returns
1. Read the verdict file(s); append to `LOG_FILE`: `## Round <n> — Codex` and/or `## Round <n> — Kimi` + the full critique.
2. Grep the last line for the verdict:
   - `VERDICT: APPROVED` (from every active reviewer, on this plan version) → break to Resolution (converged).
   - `VERDICT: REVISE` from any reviewer → Claude decides **what's actually worth acting on** (Claude is final arbiter — reviewers advise, don't command). With `both`, merge the two critiques and note where they disagree — cross-reviewer disagreement is signal, log it. Revise `PLAN_FILE` once per round. Append `### Claude's response` to `LOG_FILE`: what changed, what was rejected, why. Increment round.
3. If round > `MAX_ROUNDS` → break to Resolution (deadlock).

### Resolution (you sign off — final gate)
- **APPROVED:** present the final `PLAN_FILE`, a 3-bullet summary of what the two acts improved, and the round count. Ask: *"Grilled + survived N rounds of <reviewer(s)>. Implement it now?"* Code only on yes. **No code is written during either act.**
- **MAX_ROUNDS hit without APPROVED (deadlock):** do NOT fake convergence. List each unresolved point + Claude's counter-position; hand it to the user to break the tie. A flagged disagreement beats a false "approved."

---

## Hard rules
- Act 1 always precedes Act 2 — don't write `PLAN.md` until the grill has actually resolved the decision tree with the user.
- The reviewer is read-only EVERY round. Codex: `-s read-only` first call, `-c sandbox_mode="read-only"` on every resume (resume has no `-s`). Kimi: no sandbox flag exists — prompt contract plus the per-round `git status` diff check, and STOP on any repo change.
- The loop ALWAYS terminates at `MAX_ROUNDS`.
- Claude is final arbiter on every REVISE — incorporate good critiques, reject bad ones *with a logged reason*. Don't cave to everything (defeats the cross-model check) and don't ignore it (defeats the point).
- Code only after the user's final sign-off.
- `LOG_FILE` is the deliverable — keep the whole argument.

## What NOT to do
- Don't review already-written code — that's `/codex:review`.
- Don't pin a `-codex` model variant on ChatGPT-account auth — it 400s.
- Don't let the reviewer edit files. Read-only, always.
- Don't run `kimi` with `-y`/`--yolo`/`--auto` — those grant it autonomous tool approval, the opposite of a read-only reviewer.
- Don't skip the post-round `git status` check when the reviewer is Kimi — it's the only write guard Kimi has.
- Don't skip Act 1 — the grill is half the value.
