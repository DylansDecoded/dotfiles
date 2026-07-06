---
name: deep-research
version: 1.1.0
description: "Multi-source research that fans out across YouTube (via yt-pipeline + NotebookLM), web articles, X/Twitter, and GitHub simultaneously. Use this skill whenever the user wants to research a topic deeply, investigate what people are saying about something, do competitive research for a video, or understand the landscape around a subject. Triggers on phrases like 'deep research on', 'research [topic] across everything', 'full research on', 'what are people saying about', 'research this topic', or any request that implies gathering intel from multiple platforms about a single subject."
---

# Deep Research v1.1.0

Fan out across YouTube, the web, X/Twitter, and GitHub in parallel to build a comprehensive research brief on any topic. The goal is to give the user a 360-degree view of what exists, what people are saying, and where the content gaps are — all in one document, fast.

## Why this exists

Researching a topic manually means opening tabs, running separate searches, cross-referencing results, and synthesizing across platforms. This skill does all of that in parallel so the user gets a single consolidated brief instead of spending 30+ minutes hunting across sources.

## How it works

### Step 1: Parse the topic

Extract the research topic from the user's message. If the topic is ambiguous, ask one clarifying question before proceeding. Construct search-friendly queries — the raw topic may need slight rewording per platform (e.g., "Claude Code MCP servers" for YouTube but "MCP server setup tutorial" for GitHub).

### Step 2: Launch YouTube pipeline + run direct searches in parallel

There are two tracks that run at the same time:

**Track A: YouTube deep dive (background agent)**

Launch a single background Agent that invokes the `/yt-pipeline` skill. This is the slow, heavy track — it searches YouTube, selects the best videos, creates a NotebookLM notebook, and runs analysis. Run it in the background so the rest of the research doesn't wait on it.

```
Agent (run_in_background: true):
  Use the /yt-pipeline skill to research "[TOPIC]" on YouTube.
  Search for the topic, let it auto-select the best videos,
  create a NotebookLM notebook, and run analysis.
  Report back with:
  - Which videos were found and selected (title, creator, views, date)
  - Key creators covering this topic
  - The NotebookLM analysis summary
  - Content gaps — angles nobody is covering yet
```

**Track B: Web + Twitter + GitHub (direct searches)**

While the YouTube pipeline runs, fire off WebSearch calls directly in the main thread. Run all of these in a **single message** so they execute in parallel:

1. **Web search (broad):** `"[TOPIC] 2026"` — blogs, articles, announcements
2. **Web search (targeted):** `"[TOPIC] tutorial OR guide OR announcement"` — how-to and news content
3. **X/Twitter:** `"[TOPIC] site:x.com"` — social conversation
4. **X/Twitter (alt):** `"[TOPIC] site:twitter.com"` — catches older-format URLs
5. **GitHub:** `"[TOPIC] site:github.com"` — repos, issues, discussions
6. **GitHub (targeted):** `"[TOPIC] github repo OR library OR tool"` — catch projects not on github.com directly

Also run the YouTube search script directly for quick metadata (this returns fast and gives us video data even before the yt-pipeline finishes):

```bash
python "~/.claude/skills/yt-search/scripts/search.py" "[TOPIC]" --count 15 --months 3
```

Why direct searches instead of subagents: Subagents can't prompt the user for WebSearch permissions — they silently fail. Running WebSearch directly in the main thread means the user approves once and all searches go through.

### Step 3: Synthesize into a research brief

Once all searches return (and the yt-pipeline agent completes), synthesize everything into a single brief. The synthesis is the most valuable part — don't just stack sections. Look for:

- **Patterns across sources** — If YouTube creators AND Twitter users AND blog authors are all saying the same thing, that's a strong signal worth highlighting in Key Takeaways.
- **Contradictions** — If one source says X is great and another says it's broken, call that out.
- **Gaps** — If nobody on YouTube has covered an angle that's blowing up on Twitter, that's a content opportunity.
- **Velocity** — Is this topic rising or fading? Compare view counts, post dates, and activity levels.

### Step 4: Save the brief

Write the research brief to the vault's `raw/` directory:

**Path:** `YOUR_VAULT_PATH/raw/YYYY-MM-DD-[topic-slug]-deep-research.md`

Use today's date. Convert the topic to a URL-friendly slug (lowercase, hyphens, no special chars).

## Output template

```markdown
# Deep Research: [Topic]
**Date:** YYYY-MM-DD
**Query:** [the topic as searched]

## Key Takeaways
- [Synthesized insight spanning multiple sources]
- [Another cross-platform finding]
- [Content opportunity or gap identified]
- [Notable trend or sentiment]
- [Actionable takeaway]

## YouTube Landscape

### Top Videos
| Video | Creator | Views | Date |
|-------|---------|-------|------|
| [Title] | Creator (subs) | views | date |

- **Key creators:** [who's covering this topic]
- **NotebookLM analysis:** [summary of what the deep analysis surfaced]
- **Content gaps:** [angles not yet covered on YouTube]
- **NotebookLM notebook:** [link if created]

## Web / Articles
- **[Article Title](URL)** — [1-2 line summary]
- **[Article Title](URL)** — [1-2 line summary]
- **Key themes:** [what the web consensus is]

## X / Twitter Pulse
- **Sentiment:** [excited / frustrated / mixed / emerging]
- **Notable voices:** [who's talking about this]
- **Common questions:** [what people are asking]
- **Key threads:** [paraphrased highlights with links]

## GitHub Activity
- **[repo-name](URL)** — [stars] stars — [what it does]
- **Community activity:** [active / growing / quiet]
- **Notable issues/PRs:** [what the community is working on or requesting]

## Content Opportunities
- [Gap: nobody on YouTube has covered X, but it's trending on Twitter]
- [Angle: most content focuses on X, but Y is underserved]
- [Question: people keep asking about X but no clear answer exists]
```

## Cross-linking

When the brief mentions concepts that have [[wiki]] articles, use wiki links. If the topic relates to an existing project in `projects/`, mention it. This keeps the vault interconnected.

## What NOT to do

- Don't use yt-search alone for the deep dive — always use yt-pipeline so videos go through NotebookLM analysis. (yt-search is fine as a quick metadata layer alongside yt-pipeline.)
- Don't run web searches via subagents — they can't get WebSearch permission approval. Run WebSearch directly.
- Don't write a 2,000-word essay — keep it concise with bullet points and tables.
- Don't skip the synthesis — raw dumps from each source aren't useful without cross-referencing.
- Don't wait for yt-pipeline before starting web searches — run them in parallel.
