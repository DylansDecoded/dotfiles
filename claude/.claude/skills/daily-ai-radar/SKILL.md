---
name: daily-ai-radar
description: "Daily AI news + GitHub trending loop — scans for new models, benchmarks, and lab announcements, pulls GitHub's top 10 trending repos for the day/week/month, curates by importance, dedupes against prior runs via state, writes the briefing to the Obsidian vault, pings Discord, and has Codex judge the result so tomorrow's run improves. Use when the user says 'daily ai radar', 'run the radar', 'ai radar', or when the scheduled daily-ai-radar job fires. NOT for content-idea scans (morning-report) or markets (morning-briefing)."
---

# Daily AI Radar

One run = one curated briefing. This is a **loop**: read state first, do the work
informed by prior runs, log the result, get judged. Workspace:
`~/.claude/skills/daily-ai-radar-workspace/` (call it `$WS` below).

## Step 0 — State and guards

1. Read `$WS/state.json`.
2. If `$WS/disabled` exists, stop: "daily-ai-radar is disabled."
3. If a run record for today's date already exists in state, stop: "already ran today."
4. From the last run's `judge.instructions_for_tomorrow` and any `user_feedback`
   entries in the last 7 runs, note what to do differently today. **User feedback
   outranks judge notes.** Apply these throughout — they are the self-improvement.
5. Collect from the last 7 runs: `headlines_covered` (story keys) and
   `repos_featured` (repo full names). These drive dedupe below.

## Step 1 — Gather (fire everything in parallel, one message)

**AI news** — `mcp__crawler__search` (WebSearch is denied in this environment).
Include today's date/year in each query; only the last 24h matters:

1. `new LLM model release announcement <today>`
2. `AI benchmark results <month year>` — leaderboard moves, new evals, SOTA claims
3. `Anthropic OR OpenAI OR Google DeepMind OR Meta AI announcement <today>`
4. `open source AI model release <today>`
5. `AI news <today>` — catch-all for anything the targeted queries miss

**GitHub trending** — `mcp__crawler__crawl` these three URLs (fallback: `curl -s`):

- `https://github.com/trending?since=daily`
- `https://github.com/trending?since=weekly`
- `https://github.com/trending?since=monthly`

Extract the **top 10** from each: `owner/repo`, one-line description, language,
total stars, stars gained this period.

## Step 2 — Curate

- **Freshness:** news older than 24h is out. Undated results count as stale unless
  corroborated. Thin day → say so; never pad.
- **Dedupe (state-driven):** a story whose key matches `headlines_covered` from the
  last 7 runs is out unless there's a genuinely new development — then frame it as
  the update, not the original story.
- **Repos:** repos in `repos_featured` are holdovers — keep them in the table (it's
  a top-10 list, accuracy wins) but mark new entries with **▲ new** and write
  commentary only about new entries or big rank moves.
- **Importance ranking:** lead with what changes decisions — new frontier/open
  models, benchmark shake-ups, pricing/capability changes. Funding rounds and
  opinion pieces rank below. For each headline, one line on *why it matters*.

## Step 3 — Write the briefing

Path: `/Users/dylan/Projects/personal/obsidian/Inbox/YYYY-MM-DD-ai-radar.md`
(create `Inbox/` if missing; if the file exists, stop — the guard should have caught it).

```markdown
# AI Radar — YYYY-MM-DD

## Top Signal
- **[Headline](url)** — why it matters, one line. (3–6 items, ranked by importance)

## New Models & Benchmarks
- **[Model/benchmark](url)** — what's new, who it beats, why care. ("Nothing new in 24h" if so)

## GitHub Trending
### Today
| # | Repo | Description | Lang | Stars | Δ period |
(10 rows; ▲ new marks repos not featured in the last 7 runs)
### This Week
(same table)
### This Month
(same table)

**Read on the repos:** 2–3 sentences — what the new entries say about where builders are heading.

## Noise Filter
- One-line list of stories seen and deliberately excluded, with the reason (stale / rehash / hype).
```

The **Noise Filter** section is required — it's the evidence of curation and what
the judge grades hardest.

## Step 4 — Verify (structural gate, tier 2)

Check: all five sections present; each trending table has exactly 10 rows with real
star counts; no Top Signal item older than 24h; no headline repeats a
`headlines_covered` key. If a check fails, fix the briefing before delivering. If it
can't be fixed (e.g. GitHub unreachable), note the gap in the briefing honestly and
record `structural_pass: false` with the reason.

## Step 5 — Judge (tier 4, Codex — never self-judge)

```bash
codex exec --sandbox read-only "$(cat ~/.claude/skills/daily-ai-radar-workspace/judge-prompt.md)

Briefing file: /Users/dylan/Projects/personal/obsidian/Inbox/<today>-ai-radar.md
Prior scores (context): <last 3 judge scores + one-line notes from state>"
```

Parse the JSON verdict (`score`, `strengths`, `problems`,
`instructions_for_tomorrow`). If codex fails or returns non-JSON, retry once, then
record `judge: null` with the error — never fabricate a score.

## Step 6 — Notify Discord

Read `discord_webhook_url` from `$WS/config.json`. If empty, skip and note it.
Otherwise POST (keep under 2000 chars):

```bash
curl -sf -X POST -H 'Content-Type: application/json' \
  -d "$(jq -n --arg c "$MSG" '{content: $c}')" "$WEBHOOK_URL"
```

Message: `**AI Radar YYYY-MM-DD** (judge: N/10)` + the Top Signal bullets (titles
only) + `▲ new trending: repo1, repo2` + the vault path.

## Step 7 — Log state

Append a run record to `$WS/state.json` matching `$WS/state.schema.json`:
date, briefing_path, headline keys, repos featured per period, structural_pass,
judge verdict, empty user_feedback. Keep all history — the file stays small.

If the user later reacts to a briefing in conversation ("good one", "too noisy",
"more benchmark detail"), append it to that run's `user_feedback` in state — that's
the strongest steering signal the loop has.
