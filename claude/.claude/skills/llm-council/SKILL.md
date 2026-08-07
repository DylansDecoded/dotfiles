---
name: llm-council
description: >-
  End-to-end conductor that takes a project, feature, or idea from rough concept
  to an execution-ready plan — and says honestly when it isn't worth building.
  Four gated phases: frame → deep research with a BUILD/RESHAPE/SKIP verdict →
  grill + cross-model council (OpenAI Codex AND Moonshot Kimi both adversarially
  review the plan until both approve) → handoff to a cheaper executor as a
  paste-ready prompt with optional direct launch. Composes the deep-research and
  grill-me-codex skills. Use whenever the user says "/llm-council", "council
  this", "run the council on X", "is this worth building", "is X feasible",
  "research then plan X", "take this idea through the pipeline", or describes
  vetting an idea end to end — research, plan, multi-model review, then hand off
  the build. Trigger even without the word "council". NOT for cloning an
  existing app (/cloneify, /shipify), NOT for reviewing an existing plan only
  (/codex-review), NOT for research alone (/deep-research).
---

# llm-council

Vet an idea end to end: research whether it's possible and worth it, grill the
user into a real plan, put that plan in front of **two** other models (Codex +
Kimi) until both approve, then hand the approved plan to a cheaper model to
build. You are the conductor: run four phases, **stop at every gate for the
user's go-ahead**, and compose the existing `deep-research` and `grill-me-codex`
skills rather than reinventing them.

Two deliverables, and either one counts as success:

1. **A verdict** — sometimes the honest output of Phase 1 is "SKIP: don't build
   this." Killing a bad idea early is the pipeline working, not failing.
2. **`EXECUTION-PROMPT.md`** — a self-contained build prompt, tailored to the
   executor the user picks, that a cheaper model can run without any of this
   run's context.

## Why gates matter

Each phase is expensive: research burns tokens, grilling takes real user time,
the council makes two external CLI calls per round, and the launch writes code.
The user stays in the driver's seat. **Never auto-advance.** Finish a phase,
show what you produced, ask the gate question, wait. "Go back" always reopens
the previous phase.

## Run folder & state

Pick a short kebab-case slug for the idea (e.g. `usage-dashboard`,
`sops-rotation`).

Resolve `<run-root>` **before writing any file** — artifacts belong next to
where the user will build, never inside this skill's own directory:

- **Feature in an existing repo:** `<run-root>` = that repo; the run folder
  sits at its root.
- **New standalone idea:** default `<run-root>` = `<cwd>/<slug>/`.
- At the start of Phase 0, state where you intend to put it ("I'll keep the run
  artifacts in `<run-root>/council-run/`. Good, or somewhere else?") and honor
  the answer. If cwd is ambiguous, ask — don't guess a home-dir dumping ground.

```
<run-root>/
└── council-run/
    ├── STATE.md            # last completed phase — enables resume
    ├── frame.md            # Phase 0
    ├── research.md         # Phase 1 (incl. the worth-it verdict)
    ├── PLAN.md             # Phase 2 (from grill-me-codex)
    ├── PLAN-REVIEW-LOG.md  # Phase 2 council argument (from grill-me-codex)
    └── EXECUTION-PROMPT.md # Phase 3
```

`STATE.md` is the resume anchor — keep it machine-checkable:

```
idea: <one line>
slug: <slug>
phase_done: 0 | 1 | 2 | 3
verdict: BUILD | RESHAPE | SKIP | —
status: <one line, incl. "stopped after research" if the user ended there>
updated: <date>
```

On every invocation: look for an existing `council-run/STATE.md` in cwd and one
level of subdirectories (don't rely on re-deriving the same slug). If one is
found, read its `idea:` line and ask: *"Found a run for '<idea>' at phase <N> —
resume it, or is this a new idea?"* Resume on match; a new idea starts fresh in
its own `<run-root>`. Update `STATE.md` after every phase.

---

## Phase 0 · FRAME

Goal: pin down what the idea *is* and what "worth it" means, so research has a
target. This is a quick framing, not the full grill — that comes in Phase 2.

Interview **one question at a time**, recommending an answer for each:

1. **The idea in one sentence** — what would exist that doesn't today?
2. **The problem it solves** — what pain, for whom? (If the user can't name a
   real pain, note it; the research verdict should weigh that heavily.)
3. **Success criteria** — what makes this worth having built, and roughly what
   effort budget makes it *not* worth it?
4. **Hard constraints** — local-only, stack, budget, integrations, deadlines.
5. **Known unknowns** — what the user is already unsure about (these become
   research questions).

Write `frame.md` with those five sections. Keep it tight.

**Gate:** show `frame.md`, then ask: *"Framed. Run the research phase? It'll dig
into feasibility, prior art, and effort — and end with an honest
build/reshape/skip verdict."* Wait.

---

## Phase 1 · RESEARCH — with a worth-it verdict

Goal: sourced facts on whether this is possible and worth doing — not vibes.

1. Invoke the **deep-research** skill via the Skill tool with a question built
   from `frame.md`, e.g.:
   > "Research <idea> for a feasibility assessment. Cover: does something like
   > this already exist (products, open-source projects, prior attempts) and how
   > well do they work; the technical approach and hard problems; realistic
   > effort and cost; known failure stories; anything that changed recently that
   > makes this newly possible or newly pointless. Constraints:
   > <hard constraints from frame.md>."

   Tell it this is a **feasibility brief, not content research** — the
   content-gap/creator angles of its template can be trimmed. If the
   environment denies the built-in WebSearch (this machine's global config
   routes search through `mcp__crawler__search`), say so in the handoff so its
   web track uses the crawler instead of stalling on denied permissions.
2. Distill the report into `research.md` for a *decider* (link the
   deep-research artifact it saved to the vault, so nothing is orphaned),
   ending with:

   ```markdown
   ## Worth-it verdict
   **Verdict:** BUILD | RESHAPE | SKIP
   **Why:** <2-4 sentences grounded in the research, judged against the
   success criteria and effort budget from frame.md>
   **What would change this verdict:** <the fact or constraint that would
   flip it>
   ```

   Be honest. If prior art already solves the problem, or the effort dwarfs the
   stated budget, say SKIP and why. RESHAPE means the idea is worth pursuing in
   a different form — name the form.
3. Present the findings conversationally, verdict first.

**Gate:** ask: *"Verdict is <X>. Proceed to planning, reshape the idea (back to
Phase 0 with what we learned), or stop here?"* On stop, record the actual
verdict plus "stopped after research" in `STATE.md` (a user can stop on a BUILD
verdict too — don't misrecord that as SKIP). The run is complete and
successful. Wait.

---

## Phase 2 · GRILL + COUNCIL

Goal: turn frame + research into a plan hardened by two independent models.

0. **Make the write guard possible:** if `<run-root>` isn't a git repo (fresh
   standalone ideas won't be), `git init` it now. grill-me-codex's Kimi safety
   check and Phase 3's baseline check both depend on `git status` working.
1. Invoke the **grill-me-codex** skill via the Skill tool **with
   `reviewer=both`** — that is the council: each round, Codex and Kimi
   independently attack the plan; convergence requires both to say
   `VERDICT: APPROVED` on the same plan version. Hand it three things:
   `council-run/frame.md` and `council-run/research.md` as context; the rule
   that the plan must honor the frame's constraints and the research's
   landmines; and the requirement that `PLAN.md` end with an **`## Acceptance`
   section** — a command to run and the output that proves each must-have works
   (Phase 3's execution prompt needs it, and the grill-me-codex plan template
   doesn't produce one on its own). Its grill should go *deeper* than Phase 0,
   not re-ask what frame.md already answers. All council mechanics — the CLI
   invocations, read-only enforcement, the Kimi git-status write guard,
   MAX_ROUNDS termination, the review log — are that skill's job. Don't
   duplicate or improvise them here.
2. When it converges (or deadlocks at MAX_ROUNDS — surface that honestly and
   let the user break the tie), ensure `PLAN.md` and `PLAN-REVIEW-LOG.md` end
   up in `council-run/`; **move** (don't copy) them there if the skill wrote
   them elsewhere, so there's exactly one version of the plan on disk.
3. Report: rounds taken, what each model's critiques changed, and any point
   where the two models disagreed with each other — cross-model disagreement is
   signal the user should see.

**Gate:** ask: *"Plan approved by both models after <N> rounds. Move to the
handoff phase? I'll package it for a cheaper executor and you choose who
builds it."* Wait.

---

## Phase 3 · HANDOFF — cheap executor

Goal: the approved plan, packaged so a cheaper model can build it — prompt
first, optional launch second.

### 1. Pick the executor

First a quick preflight: `command -v kimi` / `command -v codex` for any CLI
executor being offered — if one is missing, don't offer it; the Claude executor
is always available. Then ask the user (one question, with a recommendation
based on the plan):

| Executor | Reach for it when |
|---|---|
| **Claude, cheap tier** (fresh Claude Code session, `/model sonnet` + `/effort low`) | The build touches this machine's config, skills, or MCP tooling; you want Claude Code's harness and permission model around the writes. Usually the safest default. |
| **Kimi CLI** | Cheapest. Well-specified, mechanical builds where the plan leaves little to decide. Kimi executes writes without asking — treat it accordingly. |
| **Codex CLI** (whatever the user's codex config defaults to) | Strong coder for gnarlier implementation; sandboxed to workspace writes. |

### 2. Write `EXECUTION-PROMPT.md`

It must stand alone — the executor won't have this run's files open, so inline
everything. Structure:

```markdown
# Build: <idea, one line>

> HOW TO RUN — <the executor-specific instructions from step 3 below>

You are implementing an approved plan. Do not re-litigate the design — the
plan survived adversarial review by two independent models. Build in the
plan's order, verify each milestone before moving on, and stop and say so if
reality contradicts the plan rather than silently improvising.

## Constraints (non-negotiable)
<from frame.md>

## The plan
<the full approved PLAN.md, inlined — it already carries Out of scope and
the ## Acceptance section the executor must satisfy>
```

### 3. Present the run instructions (always) …

- **Claude:** open a fresh Claude Code session in `<run-root>`, run
  `/model sonnet` and `/effort low`, paste the prompt. Optionally set the
  finish line: `/goal "<the Acceptance signal>"`.
- **Kimi:** from `<run-root>`:
  `kimi -p "$(cat council-run/EXECUTION-PROMPT.md)"`
- **Codex:** from `<run-root>`:
  `codex exec -s workspace-write "$(cat council-run/EXECUTION-PROMPT.md)" < /dev/null`
  (the stdin redirect is mandatory — see grill-me-codex for why codex hangs
  without it; don't pin `-m`).

### 4. … then offer to launch it from this session

Only on an explicit yes, and only after checking the baseline: run
`git status` in `<run-root>` first — if there's uncommitted work, tell the user
and suggest committing or a worktree before an autonomous model starts writing.

- **Claude:** launch a `general-purpose` Agent with `model: sonnet`, prompt =
  the EXECUTION-PROMPT.md contents, working in `<run-root>`.
- **Kimi / Codex:** run the exact command from step 3 as a background Bash task
  (builds outlast the default tool timeout), then monitor and report. Never add
  `--yolo`/`-y` to kimi and never escalate codex past `workspace-write`.

Report the build result against the Acceptance section — what passed, what
didn't, verbatim failures. Mark `STATE.md` complete.

---

## Operating principles

- **One question at a time** in interviews; always recommend an answer.
- **Gates are hard stops.** Produce → show → ask → wait.
- **SKIP is a win.** The pipeline exists to find out if the idea is worth it;
  "no" answered cheaply beats "yes" answered by a failed build.
- **Compose, don't reinvent.** Research belongs to `deep-research`; the grill,
  the council rounds, and every codex/kimi CLI mechanic belong to
  `grill-me-codex`. This skill sequences them and owns the artifacts.
- **Claude moderates but doesn't vote twice.** In the council, incorporate or
  reject each critique with a logged reason — but the approval bar is the two
  external models, not you.
- **Everything to disk.** Every phase leaves a file in `council-run/` so runs
  are resumable and auditable.
- **The execution prompt stands alone.** Inline the plan; the executor has no
  access to this run.
