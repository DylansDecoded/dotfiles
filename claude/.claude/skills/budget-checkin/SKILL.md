---
name: budget-checkin
description: Daily family budget pacing check — compares actual spending against budgeted amounts per category for the current month and flags categories on track to overshoot. Use whenever the user says "budget check", "budget checkin", "morning budget", "how are we tracking", or asks in any way whether spending or the budget is on track this month, how much is left in a category, or whether they can afford something this month.
---

# Budget Check-in

Two steps, deliberately separated: **fetch** (data source, swappable) and **analyze** (source-agnostic). The data source today is Actual Budget; it may become YNAB later. Keep all analysis out of the fetch layer so a source swap never touches the logic below.

## Step 1: Fetch

```bash
node ~/.claude/skills/budget-checkin/scripts/fetch.mjs
```

On success it prints normalized JSON:

```json
{
  "month": "2026-07",
  "as_of": "2026-07-17",
  "day_of_month": 17,
  "days_in_month": 31,
  "pct_month_elapsed": 55,
  "categories": [
    { "name": "Groceries", "group": "Variable", "budgeted": 1000, "spent": 412.35 }
  ]
}
```

On failure it prints `{ "error": ..., "message": ... }`. In that case relay the message, walk the user through Setup (below) if it's a config problem, and stop. Never invent budget numbers — a check-in with fabricated data is worse than no check-in.

## Step 2: Analyze pacing

Use only the JSON from step 1. For each category with `budgeted > 0`, compute percent used = spent / budgeted. Compare against `pct_month_elapsed`.

Status per category:
- ✅ on track — percent used ≤ percent elapsed + 5 points, or spending naturally front-loaded (see below)
- ⚠️ pacing hot — percent used exceeds percent elapsed by more than 5 points and the linear projection (spent ÷ fraction of month elapsed) lands above budget
- 🔴 over budget — spent > budgeted, full stop
- ❓ unbudgeted — budgeted is 0 but spent > 0

Apply judgment before flagging: linear pacing only makes sense for flow categories (groceries, eating out, gas) where spending accrues through the month. A bill-like category paid once — spent within a few percent of budget, typical for rent/mortgage, insurance, subscriptions — is *paid*, not overshooting; mark it ✅ paid. Don't project a mortgage paid on the 1st to 200% of budget.

## Output format

Keep it short — this runs as a morning glance, not a report. ALWAYS use this structure:

```markdown
# Budget Check-in — July 2026
Day 17 of 31 — 55% of month elapsed

| Category | Spent | Budget | Used | Status |
|---|---:|---:|---:|---|
| Groceries | $412 | $1,000 | 41% | ✅ |
| Eating Out | $310 | $400 | 78% | ⚠️ |

**Flags**
- ⚠️ Eating Out: 78% used at 55% elapsed — pacing to ~$565 vs $400 budgeted.

**Verdict:** one line — overall on/off track and the single most useful action today.
```

Every flag is one line: category, percent used vs percent elapsed, projected month-end vs budget. No flags → say "All categories on track." Order the table by group if groups exist, otherwise by percent used descending.

## Setup (config missing or incomplete)

Config lives at `~/.config/budget-checkin/config.json`:

```json
{
  "source": "actual",
  "actual": {
    "serverURL": "http://localhost:5006",
    "password": "FILL_ME_IN",
    "syncId": "FILL_ME_IN",
    "encryptionPassword": null
  }
}
```

- `syncId`: in Actual, Settings → Show advanced settings → Sync ID.
- Password can instead come from the `ACTUAL_PASSWORD` env var; prefer that over the file. If it must live in the file, `chmod 600` it.
- First run against a real server needs the API package: `npm install --prefix ~/.claude/skills/budget-checkin/scripts`
- For a demo without a server, set `"source": "fixture"` and `"fixture": { "path": "/path/to/normalized.json" }` — a file matching the step-1 JSON shape (only `categories` is read from it).

## Swapping data sources later

Add a loader in `scripts/fetch.mjs` that returns `[{name, group, budgeted, spent}]` (spent as positive dollars for the current month), register it under a new `source` name, update config. Steps 2 and 3 need no changes.
