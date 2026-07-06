---
name: morning-report
version: 1.0.0
description: "Daily AI/Claude Code trend briefing — scans YouTube, web, X/Twitter, and GitHub for what's new and trending in the AI coding agent space. No topic needed. Use this skill whenever the user wants a morning briefing, daily trend scan, wants to know what's happening in AI today, or says things like 'morning report', 'what's trending', 'daily briefing', 'what's new in AI today', 'catch me up', or 'what did I miss'. Also triggers on 'what are people talking about right now' when no specific topic is given."
---

# Morning Report v1.0.0

A fast daily radar scan across YouTube, web, X/Twitter, and GitHub for the AI/Claude Code/agents space. Designed to be run first thing in the morning — gives you a scannable briefing in ~2 minutes so you know what's happening, what's trending, and where the content opportunities are.

## How this differs from /deep-research

| | Morning Report | Deep Research |
|---|---|---|
| **Input** | None needed — auto-scans AI/Claude Code | Requires a specific topic |
| **YouTube** | yt-search (fast metadata scan) | yt-pipeline (NotebookLM deep analysis) |
| **Depth** | Breadth — what's happening NOW | Depth — comprehensive landscape |
| **Speed** | ~2 minutes | ~5+ minutes |
| **Purpose** | Daily awareness | Pre-production research |

## How it works

### Step 1: Fire all searches in a single message

Run ALL of these in one message so they execute in parallel. No subagents — run WebSearch and Bash directly so permissions work.

**YouTube (via yt-search script — fast metadata, no NotebookLM):**
```bash
python "~/.claude/skills/yt-search/scripts/search.py" "Claude Code" --count 10 --days 1
```
```bash
python "~/.claude/skills/yt-search/scripts/search.py" "AI agents 2026" --count 10 --days 1
```

**Web searches (WebSearch tool) — always include "today" or "past 24 hours" in queries:**
1. `"Claude Code" news today {current_year}` — Claude Code specific news
2. `"Anthropic" announcement today {current_year}` — official Anthropic news
3. `"AI coding agent" OR "AI coding assistant" news today {current_year}` — broader AI coding tools landscape

**X/Twitter (WebSearch tool):**
4. `"Claude Code" site:x.com today` — Claude Code conversation
5. `"AI agents" trending site:x.com today {current_year}` — broader AI agent buzz

**GitHub (WebSearch tool):**
6. `"Claude Code" site:github.com` — repos, issues, community projects

That's 8 parallel calls (2 Bash + 6 WebSearch). Fire them all at once.

### Step 2: Synthesize the briefing

Once all results are back, write a morning briefing. The format should be **scannable in 2 minutes** — imagine reading this over coffee. Lead with the headlines, then drill into each source.

Key things to surface:
- **Breaking news** — only things from the last 24 hours. If a story is older than 24 hours, skip it entirely — it's stale.
- **Trending content** — videos/posts getting unusual traction, posted in the last 24 hours only
- **Sentiment shifts** — is the community excited, frustrated, or debating something?
- **Your content opportunities** — gaps where your brand could make a video. Be specific about what angle and why it would work.
- **Competitor moves** — what are other AI/Claude Code creators posting?

**IMPORTANT:** Aggressively filter out anything older than 24 hours. If a web result, tweet, or video is from 2+ days ago, do NOT include it. The whole point of a morning report is what happened since the last one. If nothing new happened in a category, say "Nothing new in the last 24 hours" and move on.

### Step 3: Save the briefing

**Path:** `YOUR_VAULT_PATH/raw/YYYY-MM-DD-morning-report.md`

Use today's date. If a morning report already exists for today, append `-2` (e.g., `2026-04-07-morning-report-2.md`).

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
- **Your recent performance:** [any your brand videos in the results + how they're doing]
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

## Content Opportunities
- **[Opportunity 1]** — [why it would work, what angle to take]
- **[Opportunity 2]** — [why it would work, what angle to take]
- **[Opportunity 3]** — [why it would work, what angle to take]
```

## Customizing the scan

The default scan covers AI/Claude Code/agents. If the user wants to adjust the scope (e.g., "morning report but focus on MCP servers"), adapt the search queries to emphasize that topic while still maintaining the broad scan. Treat it as a weighted morning report, not a full deep-research — keep the speed.

## What NOT to do

- Don't use yt-pipeline — that's for deep-research. Morning report uses yt-search for speed.
- Don't run searches via subagents — they can't get WebSearch permission approval.
- Don't write walls of text — this is a morning scan, not a research paper. Tables and bullet points only.
- Don't skip Content Opportunities — that's the most actionable section for the user.
- Don't rehash old news — ONLY include things from the last 24 hours. If a result is older than 24 hours, drop it. If nothing is new in a section, write "Nothing new in the last 24 hours" and move on. The morning report should never contain yesterday's news.
