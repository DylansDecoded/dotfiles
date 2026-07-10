---
name: shipify
description: End-to-end conductor for cloning a piece of software with a deployment-aware pipeline. Walks the user through four gated phases — scope → deep research → plan (grilled + Codex-reviewed) → a paste-ready build prompt — and its first move is asking whether the clone is for local/personal use or for deploying at a larger scale, then steering every phase accordingly (hosting, auth, cost model, and ops become first-class for scale builds). Use this whenever the user wants to clone, rebuild, reimplement, or make their own version of an existing app AND ship it somewhere — "clone X and deploy it", "build my own Superhuman as a SaaS", "make a production-ready version of X", "clone this for my team/customers" — or when they want to clone something but haven't said where it will run. Trigger even when the user describes recreating an app's functionality without saying the word "clone". Invoke via /shipify. (For a purely local, personal-use clone pipeline the sibling skill /cloneify also works; shipify is the right pick whenever deployment is possible or undecided.)
---

# shipify

A guided pipeline that turns "I want to clone X" into a single paste-ready prompt
that builds it — with the build's *destination* decided up front. You are the
conductor: you run four phases, **stop at every gate for the user's go-ahead**,
and compose two existing skills (`deep-research`, `grill-me-codex`) rather than
reinventing them.

The real deliverable is **Phase 3's goal-prompt** — one self-contained block the
user pastes into a fresh Claude Code session to actually build the clone. Phases
0–2 exist to make that prompt *correct*: scoped, researched, and hardened.

What makes shipify different from a plain clone pipeline: apps built for your
own machine and apps built for other people diverge on almost every axis that
matters — hosting, auth, data ownership, cost ceilings, observability, legal
surface. Deciding that late poisons the plan. So shipify asks first.

## The deployment-mode question

At the **start of Phase 0**, right after learning what the target is (the
target often arrives in the invocation itself — don't re-ask what's already
answered), ask the user (verbatim or near it):

> **"Is this an app for local/personal use, or are you considering deploying it
> at a larger scale?"**

Recommend an answer if the request already signals one ("for my customers" →
scale; "on my machine, offline" → local), but always confirm — this single
answer steers the rest of the run. The two modes:

| | **Local mode** | **Scale mode** |
|---|---|---|
| Who uses it | The user (maybe their household) | Other people: a team, community, or paying customers |
| Run root | `<cwd>/<slug>-local/` | `<cwd>/<slug>/` |
| Scope adds | Offline/no-account constraints | Target users + rough user count, hosting preference, auth needs, monthly cost ceiling |
| Research adds | — | How the original handles hosting/pricing/multi-tenancy; operational landmines a deployed clone inherits (abuse, rate limits, compliance, deliverability) |
| Grill adds | — | Deployment decisions as first-class branches: hosting platform, environments & how deploys happen, auth strategy, data privacy, cost model, observability/alerting, domain |
| Goal prompt adds | Runs-on-my-machine acceptance | Deployed-and-reachable acceptance (live URL / health check evidence) |

Record the chosen mode in `scope.md` and `STATE.md`. If the user changes their
mind mid-run, that's a Phase 0 revision — loop back through the gates, because
research and plan emphasis both shift with it. A mode switch also changes the
default run root: offer to `mv` the existing run root to the new default (or
keep it where it is if the user prefers), and record the outcome in `STATE.md`.

## Why gates matter

Each phase is expensive and consequential (research burns tokens; grilling takes
real user time; the plan steers everything downstream). The user must stay in the
driver's seat. **Never auto-advance.** Finish a phase, show what you produced,
then ask the explicit gate question and wait. If the user wants to revise the
previous phase instead of moving on, loop back — don't force forward.

## Run folder & state

Pick a short kebab-case slug for the target (e.g. `whisperflow`, `superhuman`,
`raycast`).

**Where the run folder lives — resolve this BEFORE writing any file.** Artifacts
must land in the **user's project, next to where they'll actually build**, NOT
inside this skill's own base directory. The base directory named in the skill
invocation is where the skill *lives*, never where its output goes. Concretely:

- The run folder is `<run-root>/ship-run/`, where `<run-root>` is a directory in
  the user's workspace that will become (or sit beside) the **target repo they run
  `/goal` in**.
- Default `<run-root>` by deployment mode: **local** → `<cwd>/<slug>-local/`;
  **scale** → `<cwd>/<slug>/`. Exception: if the cwd is clearly already the
  dedicated home for this build (empty, or named after the product being built),
  offer the cwd itself as the run root instead of nesting another folder inside it.
  When you confirm the deployment mode, state the run root it implies in the same
  turn and let the user redirect — e.g. "I'll put the run + build here:
  `<cwd>/<slug>/`. Good, or somewhere else?" — it's a statement they can veto,
  not a separate blocking question. Honor their answer.
- **Never** write to a path under `~/.claude/skills/` or wherever this SKILL.md
  resides. If you can't determine the cwd, ask — don't fall back to the skill dir.

Layout (all paths below are relative to the resolved `<run-root>`):

```
<run-root>/                 # e.g.  <cwd>/superhuman/  (scale)  or  <cwd>/superhuman-local/  (local)
└── ship-run/               # process artifacts, beside the app code
    ├── STATE.md            # phase progress + deployment mode; lets you resume across sessions
    ├── scope.md            # Phase 0 output
    ├── research.md         # Phase 1 output (from deep-research)
    ├── PLAN.md             # Phase 2 output (from grill-me-codex)
    ├── PLAN-REVIEW-LOG.md  # Phase 2 Codex argument (from grill-me-codex)
    └── GOAL-PROMPT.md      # Phase 3 output — the paste-ready prompt
```

At the **start of every invocation**, before asking anything, check **both**
candidate run roots for existing state — `<cwd>/<slug>-local/ship-run/STATE.md`
and `<cwd>/<slug>/ship-run/STATE.md` (the deployment mode is recorded *inside*
STATE.md, so you can't know which path is right until you look at both). If one
exists, read it and resume from the last completed phase in the recorded mode
instead of starting over — no need to re-ask the deployment-mode question. If
the user names a new target, start fresh (leave any previous target's run folder
untouched). While resolving, if you spot a `clone-run/` folder in the same run
root, mention it — a `/cloneify` run has touched this target, and the user may
want to continue that instead. Update `STATE.md` after each phase completes
(record phase, deployment mode, date, one-line status).

---

## Phase 0 · SCOPE

Goal: nail down *what* we're cloning, *where it will run*, and *how far*, so
research has a target and the plan has guardrails.

1. Ask first: **"What are we cloning?"** Get the target app/tool by name (or a
   description if it's niche/internal).
2. Ask the **deployment-mode question** (see above) and confirm the run root it
   implies.
3. Then interview for scope — **one focused question at a time**, recommending an
   answer for each so the user can just confirm. Cover:
   - **Platform / runtime** — Windows / macOS / Linux / web / cross-platform?
   - **Must-have features** — the 3–6 that define the clone. What's the core loop?
   - **Hard constraints** — the non-negotiables that are the *reason* to clone
     rather than just use the original (e.g. "100% local / offline", "no
     subscription", "open-source deps only", "runs on my GPU").
   - **Scale-mode extras** (skip in local mode): who the users are and a rough
     count, hosting preference (or "you choose"), whether accounts/auth are
     needed, and a monthly cost ceiling — cost is the constraint most likely to
     invalidate a deployed architecture later, so get a number now.
   - **Stack preferences** — language/framework, or "you choose."
   - **Explicit out-of-scope** — what we are deliberately *not* building in v1.
     This is as important as the must-haves; it keeps the plan honest.
4. Write `scope.md` with sections: Target, **Deployment mode**, Platform,
   Must-have features, Hard constraints (incl. cost ceiling in scale mode),
   Stack, Out of scope. Keep it tight and skimmable.

**Gate:** show `scope.md`, then ask: *"Scope locked. Ready for the deep research
phase? (It'll dig into how the original works, its real feature set, and the
gotchas — costs some time/tokens.)"* Wait for go-ahead.

---

## Phase 1 · RESEARCH

Goal: understand the target deeply enough to clone it — not vibes, sourced facts.

1. Invoke the **deep-research** skill via the Skill tool. Feed it a question built
   from `scope.md`, e.g.:
   > "Research <target> for a clone project. Cover: what it actually does and its
   > core UX loop; the full user-facing feature set; how it works technically
   > (architecture, key dependencies, models/APIs, platform tricks); known
   > limitations and the hard problems a clone must solve; any existing
   > open-source clones and what they got right/wrong. Constraints we care about:
   > <hard constraints from scope>."

   In **scale mode**, extend the question with: how the original is hosted and
   priced; how it handles multi-tenancy, auth, and abuse; what a deployed clone
   inherits operationally (rate limits, compliance, moderation, email
   deliverability, support burden); and realistic infra cost at the user's
   stated scale.
2. When deep-research returns, distill its report into `research.md` focused on
   what the *builder* needs: feature inventory, the technical approach, the
   landmines (the 3–5 things most likely to sink the build — in scale mode,
   operational landmines count double), and any decisions the research surfaced
   that the user will need to make in planning.
3. Summarize back to the user conversationally — lead with "here's what I found",
   highlight the landmines, and flag the open decisions planning will resolve.

**Gate:** ask: *"That's the research. Want to start the planning phase? I'll grill
you on the open decisions, then have Codex adversarially review the plan before we
lock it."* Wait for go-ahead.

---

## Phase 2 · PLAN

Goal: turn scope + research into a hardened, build-ready spec.

1. Invoke the **grill-me-codex** skill via the Skill tool. Hand it the context it
   needs: point it at `<run-root>/ship-run/scope.md` and `research.md`, and tell it
   the plan should target the must-have features under the hard constraints, with
   the out-of-scope list respected. Tell it the deployment mode explicitly.

   In **scale mode**, instruct the grill to treat deployment as part of the
   decision tree, not an afterthought: hosting platform and region, environments
   and how deploys happen, auth/account strategy, data storage and privacy
   posture, the cost model against the stated ceiling, observability and
   alerting, and the domain/DNS story. A scale-mode plan that only describes
   application code is incomplete — Codex should be told to attack the
   operational side too.
2. Let grill-me-codex run its two acts — the one-question-at-a-time interview,
   then the Codex review loop to APPROVED.
3. Ensure the locked plan lands as `<run-root>/ship-run/PLAN.md` (and the review
   argument as `PLAN-REVIEW-LOG.md`). If grill-me-codex wrote `PLAN.md` elsewhere
   (e.g. repo root), copy it into the run folder so the run is self-contained.

**Gate:** ask: *"Plan's locked and Codex-approved. Move to the execution phase? I'll
hand you the single prompt to paste into a fresh Claude Code session to build it."*
Wait for go-ahead.

---

## Phase 3 · HANDOFF

Goal: emit the paste-ready goal-prompt **plus a matching `/goal` completion
condition** — so the user can paste, set the finish line, and let Claude Code
build autonomously until it's met.

Write `GOAL-PROMPT.md`. It carries everything the build session needs without
access to this run, so **inline the essentials** rather than referencing files
the new session won't have open. Use this structure:

```markdown
# Build goal: clone of <target>

> HOW TO RUN THIS (two moves in a fresh Claude Code session, in your target repo):
> 1. Paste everything below this line as your first message.
> 2. Then set the finish line so Claude keeps working until it's done:
>    /goal "<completion condition — see the bottom of this file>"

---

You are building a <one-line description> — <deployment mode + hard constraints,
e.g. "deployed multi-user web app, ≤$20/mo" or "fully local, Windows-only">.
Build it from the locked spec below. Work in de-risking order, verify as you go,
and show each milestone working before moving on.

## What we're building (feature scope)
- <must-have feature 1>
...

## Deployment target
- <local: "runs on the user's machine, no hosted services"  |
   scale: hosting platform, environments, auth, cost ceiling — from the plan>

## Hard constraints (non-negotiable)
- <constraint 1>
...

## Explicitly out of scope (v1)
- <out-of-scope item 1>
...

## The plan
<paste the full, Codex-approved PLAN.md contents here>

## How to proceed
1. Confirm the environment / dependencies first (a doctor-style check — in scale
   mode this includes hosting CLI auth, e.g. `wrangler whoami` / `vercel whoami`,
   and which secrets exist vs. are needed).
2. Build in the plan's de-risk order; spike the riskiest unknowns first.
3. After each milestone, run it and show it working before moving on.

---

## Recommended /goal condition

Claude Code's `/goal` keeps working turn-after-turn until a small evaluator model
judges your condition met. The evaluator reads **what the build session surfaces
in the conversation** — it does NOT run commands itself — so phrase the condition
around something Claude's own output demonstrates. Derive it from the plan's
acceptance criteria. Local-mode example:

    /goal "the app builds and runs, and a self-test / acceptance run printed in
    this conversation shows <the plan's verifiable pass signal> with every
    must-have feature exercised"

Scale-mode example (deployment evidence is part of done):

    /goal "the app is deployed and reachable — the conversation shows a live URL
    responding (curl output or equivalent) plus <the plan's verifiable pass
    signal> with every must-have feature exercised against the deployed instance"

Keep it to one measurable end state + how Claude should prove it. `/goal` needs
Claude Code v2.1.139+, an accepted workspace-trust dialog, and hooks enabled; it
auto-resumes across `--continue`/`--resume`, so a long build can span sessions.
```

Fill the `<...>` placeholders from `scope.md` and `PLAN.md`. For the `/goal`
condition, pull the plan's actual acceptance check (e.g. a self-test or doctor
command whose output names a clear pass string) so the evaluator has something
concrete to read.

Then present it to the user: show the prompt, say where it's saved
(`<run-root>/ship-run/GOAL-PROMPT.md`), and walk the two-move handoff — paste the
prompt into a fresh Claude Code session **opened in `<run-root>`** (the build
directory — usually not a git repo yet; the build session should `git init` as
one of its first moves), then run the `/goal` line so it builds until the
condition holds. The app code builds in `<run-root>`; the reference artifacts
sit beside it in `ship-run/`.

Mark `STATE.md` complete.

---

## Operating principles

- **Deployment mode first.** It's the cheapest question in the run and the most
  expensive one to get wrong late. Ask it before scoping features.
- **One question at a time** in interviews; recommend an answer so the user can
  confirm fast. Don't dump a questionnaire.
- **Gates are hard stops.** Produce → show → ask → wait. The user can always say
  "go back" and you revise the prior phase.
- **Compose, don't reinvent.** Research is `deep-research`'s job; grilling and the
  Codex review are `grill-me-codex`'s job. You sequence them and own the artifacts.
- **Everything to disk.** Each phase leaves a file in the run folder so the run is
  resumable and the process is visible (useful if this is being recorded/taught).
- **The goal-prompt must stand alone.** Inline the plan and scope into it; the
  build session won't have this run's files.
