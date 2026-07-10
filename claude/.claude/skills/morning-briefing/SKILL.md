---
name: morning-briefing
description: Generate Dylan's daily morning briefing — overnight tech/AI news (Databricks, the AI space, data/AI consulting trends) plus a markets section covering the top 25 cryptos and blue-chip stocks with breaking news. Saves the briefing as a dated markdown file in the Obsidian vault and emails it. Use whenever the user says "morning briefing", "daily briefing", "catch me up", "what happened overnight", or when a scheduled daily-briefing job fires. Do NOT use for AI-coding-agent trend scans (that's the morning-report skill) or research on a single named topic (deep-research).
---

# Morning Briefing

Produce one markdown briefing with two sections, save it to the vault, and email it. Written for Dylan: technical director at a data/AI consultancy, follows crypto and blue-chip stocks.

## Config

- **Vault destination:** `/Users/dylan/Projects/personal/obsidian/Briefings/YYYY-MM-DD-briefing.md` (create the folder if missing)
- **Email:** drobson94@icloud.com, subject `Morning Briefing — <Month D, YYYY>`
- **News interests:** Databricks (product, funding, partnerships, competitive moves), the AI space broadly (models, agents, enterprise adoption), data/AI consulting industry trends
- **Markets:** top 25 cryptos by market cap + notable risers outside the top 25; blue-chip stocks (megacap tech, Dow-type names) with breaking news

## Workflow

### 1. Gather news (searches can run in parallel)

Search for stories from the last ~24 hours across the three interest areas. Use `mcp__searxng__search` (fall back to WebSearch only if unavailable). Suggested queries, adjusted to today's date:

- `Databricks news`
- `AI industry news today` / `enterprise AI adoption announcement`
- `data AI consulting market news`
- `stock market news today` (for section 2 breaking news)
- `crypto news today`

Prefer primary/reputable sources. Skip stories older than ~48h unless they broke overnight relative to the user's morning. 5–8 stories total is right; a thin news day should yield a short section, not padding.

### 2. Gather market data

Crypto — CoinGecko public API (no key needed):

```bash
curl -s "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=25&page=1&price_change_percentage=24h"
```

For risers, also pull `order=market_cap_desc&per_page=250` and flag anything ranked 26–250 with >15% 24h gain and market cap >$100M (filters pump-and-dump dust).

Stocks — Yahoo Finance quotes (fetch via web, ~10-12 blue chips: AAPL MSFT GOOGL AMZN NVDA META TSLA BRK-B JPM V UNH WMT).

If a data source is down, use another reputable quote source and label the substitution; never invent numbers. Note: pre-market US time means stock quotes are the prior close — label them as such.

### 3. Write the briefing

Use this structure:

```markdown
# Morning Briefing — <Day>, <Month D, YYYY>

## Tech & AI
- **<Headline>** — 1–2 sentence summary, why it matters to a data/AI consultancy. [Source](url)
(5–8 items; lead with the most consequential)

## Markets

### Crypto
| # | Coin | Price | 24h |
(top 25, arrows or +/- % for 24h moves)

<one-sentence tape read interpreting the table — e.g. "Red across the board apart from privacy coins">

**On the rise:** <ranked-26+ movers, one line each on why if discoverable>
**Crypto news:** <2–4 breaking items with sources>

### Stocks
| Ticker | Close | Change |
(blue chips)

<one-sentence tape read — biggest mover and the day's theme>

**Stock news:** <2–4 breaking items with sources>
```

Keep summaries tight and opinionated — "why it matters" beats restating the headline. The one-line tape reads under each table are required: they're the difference between a data dump and a briefing. No filler on slow days.

### 4. Deliver

1. Write the markdown file to the vault destination (overwrite if the day's file already exists — reruns should refresh, not duplicate). Markdown, not HTML — Obsidian renders it natively.
2. Email it as **HTML**: convert the briefing to clean inline-styled HTML (readable tables, linked sources, system font stack, no external CSS — email clients strip it) and send to the config email with the config subject via the available Gmail tool/connector. If email sending is unavailable in this environment, still write the vault file and note that email was skipped.
