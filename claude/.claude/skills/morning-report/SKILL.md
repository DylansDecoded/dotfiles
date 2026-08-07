---
name: morning-report
version: 1.1.0
description: "Daily AI trend briefing — scans YouTube, web, X/Twitter, and GitHub for what's new and trending across Claude Code, Codex, and the major LLMs (Anthropic, OpenAI, Google, etc.). No topic needed by default, but accepts an optional focus (e.g. 'homelab', 'MCP servers'). Ends with a ranked 'Worth Writing About' shortlist that the outline-content skill chains off. Use this skill whenever the user wants a morning briefing, daily trend scan, wants to know what's happening in AI today, or says things like 'morning report', 'morning scan', 'scan LLM news', 'run my digest', 'what's new in Claude Code', 'what's trending', 'daily briefing', 'what's new in AI today', 'catch me up', or 'what did I miss'. Also triggers on 'what are people talking about right now' when no specific topic is given."
---

# Morning Report v1.1.0

A fast daily radar scan across YouTube, web, X/Twitter, and GitHub for the AI space — Claude Code, Codex, and the major LLMs. Designed to be run first thing in the morning — gives you a scannable briefing in ~2 minutes so you know what's happening, what's trending, and where the content opportunities are. It ends with a ranked shortlist of ideas worth writing about, which the `outline-content` skill reads to draft an outline.

## Input (optional)

Runs with no input by default (scans the whole Claude Code / Codex / major-LLM space). If the user names a focus — "morning report on homelab", "scan LLM news but MCP servers" — treat that as a weight on the scan, not a replacement: emphasize the focus in the queries while keeping the broad radar. Keep it fast; this is still a morning scan, not deep-research.

## How this differs from /deep-research

| | Morning Report | Deep Research |
|---|---|---|
| **Input** | None needed — auto-scans Claude Code / Codex / LLMs (optional focus) | Requires a specific topic |
| **YouTube** | yt-search (fast metadata scan) | yt-pipeline (NotebookLM deep analysis) |
| **Depth** | Breadth — what's happening NOW | Depth — comprehensive landscape |
| **Speed** | ~2 minutes | ~5+ minutes |
| **Purpose** | Daily awareness | Pre-production research |

## How it works

### Step 1: Fire all searches in a single message

Run ALL of these in one message so they execute in parallel. No subagents — run WebSearch and Bash directly so permissions work. In every query below, replace `{current_year}` with the current year from the environment's date.

If the user gave a focus (see Input), add one YouTube and one web query weighted to that focus, and lean the synthesis toward it. Otherwise run the default set below as-is.

**YouTube (via yt-search script — fast metadata, no NotebookLM; `--days 1` restricts to the last 24h):**
```bash
python "~/.claude/skills/yt-search/scripts/search.py" "Claude Code" --count 10 --days 1
```
```bash
python "~/.claude/skills/yt-search/scripts/search.py" "OpenAI Codex" --count 10 --days 1
```
```bash
python "~/.claude/skills/yt-search/scripts/search.py" "AI agents LLM 2026" --count 10 --days 1
```

**Web searches (WebSearch tool) — always include "today" or "past 24 hours" in queries:**
1. `"Claude Code" news today {current_year}` — Claude Code specific news
2. `"Anthropic" OR "OpenAI" OR "Google DeepMind" announcement today {current_year}` — official lab news across the major LLM providers
3. `"Codex" OR "AI coding agent" OR "AI coding assistant" news today {current_year}` — Codex + broader AI coding tools landscape
4. `new LLM model release OR benchmark today {current_year}` — major model launches, updates, benchmarks

**X/Twitter (WebSearch tool):**
5. `"Claude Code" OR "Codex" site:x.com today` — coding-agent conversation
6. `new LLM OR "AI agents" trending site:x.com today {current_year}` — broader model + agent buzz

**GitHub (WebSearch tool):**
7. `"Claude Code" OR "Codex" site:github.com` — repos, issues, community projects

That's 10 parallel calls (3 Bash + 7 WebSearch), plus up to 2 more if the user gave a focus. Fire them all at once.

### Step 2: Synthesize the briefing

Once all results are back, write a morning briefing. The format should be **scannable in 2 minutes** — imagine reading this over coffee. Lead with the headlines, then drill into each source.

Key things to surface:
- **Breaking news** — only things from the last 24 hours. If a story is older than 24 hours, skip it entirely — it's stale.
- **Trending content** — videos/posts getting unusual traction, posted in the last 24 hours only
- **Sentiment shifts** — is the community excited, frustrated, or debating something?
- **Content opportunities** — gaps where a new video or post would land. Be specific about the angle and why it would work. These feed the ranked **Worth Writing About** shortlist (see template) that `outline-content` reads.
- **Competitor moves** — what are other AI / Claude Code / Codex creators posting?

**Freshness rules — apply strictly:**
- Include only items from the last 24 hours. Anything older is stale: drop it.
- A result with no visible date counts as stale, unless another source confirms it's from the last 24 hours.
- If nothing new happened in a category, write "Nothing new in the last 24 hours" and move on. If *every* section is empty (weekends are often quiet), say so up front in Headlines rather than stretching thin material.
- The same story often appears on web, X, and GitHub at once. Report it once in Headlines and reference it briefly in the source sections — don't repeat the same summary four times.

**Fallbacks:**
- If a `--days 1` YouTube search returns zero videos, rerun once with `--days 3`, mark those rows' Posted dates clearly, and exclude them from Headlines.
- If the `site:x.com` searches return nothing usable (common — search engines index X poorly), write "X coverage thin today" in that section instead of guessing at sentiment.

### Step 3: Save the briefing

**Path:** `/Users/dylan/Projects/personal/obsidian/Inbox/YYYY-MM-DD-morning-report.md`

Use today's date. Create the `Inbox/` directory if it doesn't exist. If a morning report already exists for today, append `-2` (then `-3`, etc.) — never overwrite an earlier report.

The `-morning-report.md` suffix and the dated filename are a contract: `outline-content` finds the latest digest by globbing `Inbox/*-morning-report.md` and taking the newest date, then parses the **Worth Writing About** shortlist. Don't rename the suffix or drop the date without updating that skill.

> **Placeholder — revisit in Part 2 (Obsidian memory layer).** The Obsidian vault's real inbox location isn't finalized yet. This path matches the existing `obsidian/` vault used by `morning-briefing`. If the vault moves or the inbox is renamed, update this path (and `outline-content`'s glob) then.

## Output template

```markdown
# Morning Report
**Date:** YYYY-MM-DD

## Headlines
- [Biggest story — 1 sentence]
- [Second biggest — 1 sentence]
- [Third — 1 sentence]

## YouTube — What's Trending
| Video | Creator | Views | Posted |
|-------|---------|-------|--------|
| [Title] | Creator | views | date |

- **Hot topics:** [what creators are making videos about right now]
- **Gaps:** [topics trending elsewhere but no YouTube coverage yet]

## Web — News & Articles
- **[Headline](URL)** — [1-line summary]
- **[Headline](URL)** — [1-line summary]
- **Official Anthropic:** [any announcements, changelog updates, blog posts]

## X / Twitter — The Conversation
- **Mood:** [one word — excited / frustrated / debating / quiet]
- **Top voices:** [who's posting and what they're saying]
- **Hot takes:** [any spicy or contrarian tweets worth noting]
- **Questions people are asking:** [common pain points or curiosities]

## GitHub — Builder Activity
- **New/trending repos:** [anything interesting popping up]
- **Claude Code repo:** [recent releases, notable issues, community PRs]
- **Ecosystem health:** [growing / stable / quiet]

## Worth Writing About
<!-- Ranked best-first. outline-content reads this section. Keep each item's shape stable. -->
1. **[Idea title / angle]** — [why it lands now, in one line]
   - Sources: [URL], [URL]
2. **[Idea title / angle]** — [why it lands now, in one line]
   - Sources: [URL]
3. **[Idea title / angle]** — [why it lands now, in one line]
   - Sources: [URL]
```

**Shortlist rules — this section is a contract with `outline-content`:**
- Always present, always titled exactly `## Worth Writing About`, always a numbered list ranked best-first (item 1 = strongest idea today).
- Each item is one bold title/angle + a one-line "why now", then a `Sources:` sub-bullet with the links that back it. This is what `outline-content` parses when you fire it with no topic.
- 3–5 items. If the day is genuinely thin, it's fine to list fewer (even one) rather than padding with weak ideas — a truthful short list beats a stretched one.
- Ground each idea in something that actually surfaced in today's scan. Don't invent evergreen topics that ignore the day's signal.

## What NOT to do

- Don't use yt-pipeline — that's for deep-research. Morning report uses yt-search for speed.
- Don't run searches via subagents — they can't get WebSearch permission approval.
- Don't write walls of text — this is a morning scan, not a research paper. Tables and bullet points only.
- Don't skip Worth Writing About — that's the most actionable section, and outline-content depends on it.
- Don't rehash old news — the freshness rules in Step 2 are the contract. The morning report should never contain yesterday's news.
