---
name: sow-rfp-writeups
description: >-
  Use when the user is drafting or responding to an RFP, RFQ, SOW, tender,
  capability statement, solution approach, engagement approach, or t-shirt
  sizing / effort estimate, or asks to draft, refine, or add recommended content
  to a proposal, scope of work, approach section, or sizing table. Produces
  research-backed client-facing enterprise writeups: parallel research
  sub-agents (tech stack, sector context, sizing benchmarks), a reviewer
  sub-agent that gates findings before writing, then a C-suite executive brief
  and a technical-depth document, each in a cited and a practitioner-voice
  version. NOT for internal engineering docs, implementation plans, READMEs, or
  code documentation.
---

# SOW / RFP / Data & AI Writeups

This skill turns a request like "draft the engagement approach and sizing for this RFP" into a
finished, research-backed deliverable. It exists because these documents fail in two predictable ways:
the claims are unsupported (made-up durations, vague capabilities, no evidence) or the prose reads like
a generated brochure that no buyer trusts. The pipeline fixes both. Research is cited hard so it can be
checked, a reviewer gates it before anyone writes, and the final document is rewritten to read like a
practitioner who has actually done the work.

Run it as four phases. The main agent owns intake and assembly. Sub-agents own research, review, and
writing. Never skip the review gate, because the whole point is that the writing rests on findings that
survived criticism rather than on the first thing a search returned.

## Phase 0: Intake and scoping (main agent, do this yourself)

Read the source material before spawning anything. If the user attached or referenced documents (a
scope of work, an RFP, a tender, a brief), read them in full. If there are none, the topic in the
prompt is your scope.

From that, write a short scoping note (keep it in your working context, you do not need a file) that
names:

- The **domain or sector** (for example public sector data platforms, retail forecasting, banking
  risk). This drives the industry research track.
- The **technology stack or platform** referenced (for example Palantir Foundry and AIP, Databricks,
  Snowflake, a bespoke pipeline). This drives the tech research track.
- The **specific asks** the deliverable must answer, quoted from the source where one exists. Map each
  ask to a section of the source document so nothing is missed.
- The **claims that need evidence**, especially any numbers (durations, team sizes, cost, throughput,
  adoption rates). These are what the reviewer will check hardest.
- **Audience and register.** This skill produces both a C-suite executive brief and a technical-depth
  document, so note what each audience cares about for this particular job.
- Any **constraints**: compliance, data residency, sovereignty, timelines, commercial model.

Getting this right is why the research comes back usable. On a real engagement, the researchers
returned sharp, non-overlapping briefs precisely because the main agent had already separated the
tech, sizing, and sector questions before fanning out. Do that work here.

## Phase 1: Parallel research fan-out

Spawn the research sub-agents in a single message so they run concurrently. Default to three tracks,
adjust to the topic, and never spawn exactly one. Use the `compound-engineering:ce-web-researcher`
agent type when it is available, otherwise `general-purpose` with web access.

Default tracks:

1. **Technology and delivery** — how the named stack or platform is actually delivered: methodology,
   delivery model, named capabilities that map to the asks, and any timeline or effort claims the
   vendor or community states.
2. **Industry and sector context** — comparable engagements, real deployments, precedents, sector
   risks, and what has gone wrong elsewhere. Cautionary precedents are valuable; a writeup that names a
   known failure mode and designs around it reads as experienced.
3. **Sizing and benchmarks** — durations, team composition, effort and cost conventions, and
   estimation norms for work of this kind. This is the track that keeps t-shirt sizing and timelines
   honest.

Each research sub-agent prompt must demand the same discipline. Read
`references/research-agent-brief.md` and fill its template per track. The non-negotiable parts: a
per-question structure, inline citations with source names and URLs on every factual claim, an
explicit split between **verified** facts and **inferred** reasoning, a flag wherever evidence is thin,
and no padding. Give each a concrete return format so the reviewer and writer can consume it.

## Phase 2: Review gate (move-on or redo loop)

Spawn one reviewer sub-agent that reads every research brief and decides, per track, whether to move on
or send it back. This is the step that makes the output trustworthy, so do not collapse it into your
own synthesis. An independent critic catches what the researcher (and you) talked yourself into.

Give the reviewer `references/reviewer-rubric.md`. It returns a verdict per track: **PASS** or
**REDO**, and on a REDO a specific, actionable list of gaps (not "do better", but "the 8 to 12 week
figure has one third-party source and no primary confirmation, find a primary source or downgrade the
claim to inferred").

Loop the gate:

- For each track marked REDO, re-spawn that research track with the reviewer's gap list appended to its
  brief. Run redos in parallel if more than one track failed.
- Cap at **two redo cycles per track.** After two, proceed with the best version you have and write the
  residual gaps into a short "open issues" note that you carry into Phase 3, so the writer hedges those
  claims honestly instead of asserting past them.
- If a track passes on the first look, it skips straight to writing. Tracks do not wait for each other.

## Phase 3: Writing handoff

Spawn the writing sub-agent(s) with the approved findings, the scoping note, and the open-issues list.
Give them `references/writing-style.md`, which carries the voice rules and the dual-register,
dual-version output spec.

Produce four files in a `deliverables/` folder next to the source material:

- `executive-brief.cited.md` and `executive-brief.md` — the C-suite register, cited and stripped.
- `technical-document.cited.md` and `technical-document.md` — the technical-depth register, cited and
  stripped.

The cited versions keep inline citations and a sources list. They are the audit trail and they double
as the evidence pack if an evaluator asks you to substantiate a number. The stripped versions remove
the citations and rewrite in experienced first-person enterprise prose, which is what the buyer
actually wants to read. Both states matter, which is why the skill keeps them separate rather than
forcing one.

You can run the C-suite and technical writers as two parallel sub-agents, or one agent producing both,
depending on size. If the source document has a structure (numbered sections, named domains), map the
deliverable onto it so a reviewer can trace coverage.

## Phase 4: Assembly and handback (main agent, do this yourself)

Collect the files, then write the user a tight summary that does three things:

1. Says what was produced and where.
2. Surfaces the **decisions and tensions** the research exposed, the way a good consultant flags them:
   where a number is aggressive, where scope and timeline disagree, where a recommended figure sits at
   the optimistic floor. On the reference engagement, the genuinely useful output was not the document,
   it was "Small at one month is the floor not the median, and Large at six months is conservative for
   this scope, here is what I'd defend." Reproduce that judgment.
3. Lists residual gaps from the gate so the user knows what is solid and what is inferred.

Do not declare the deliverable finished without naming what is inferred versus evidenced. That honesty
is the difference between a writeup a bidder can stand behind and one that collapses under a single
hard question.

## Reference files

- `references/research-agent-brief.md` — the template every research sub-agent prompt is built from.
- `references/reviewer-rubric.md` — the move-on / redo criteria the reviewer applies.
- `references/writing-style.md` — enterprise voice, anti-AI-slop rules, and the dual-register,
  dual-version output spec for the writing sub-agents.
