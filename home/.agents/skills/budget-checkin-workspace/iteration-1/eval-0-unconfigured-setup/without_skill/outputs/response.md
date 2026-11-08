Can't run a real budget check for July — there's no July data to check.

What I found:

- **`~/Documents/Finances/Plans/Budget/robson_financial_tracker.xlsx`** is your source of truth. It has a full budget for **2026-05 only** (47 line items), and every `actual_amount` is blank. No 2026-06 or 2026-07 rows exist, and the ReviewLog (your twice-weekly snapshot log) has zero entries.
- The older `Robson_Budget_Tracker.xlsx` and the 2024 bills CSV in the same folder are stale.
- `~/Projects/personal/finance-os` is an empty directory.

So the only pacing math possible is plan-vs-plan, which tells you nothing about actual spending. For reference, the May plan you'd presumably carry forward:

| Variable category | Planned | July 17 pace point (55%) |
|---|---|---|
| Grocery | $1,400 | $770 |
| Shopping | $1,600 | $880 |
| Dining Out | $500 | $275 |
| Medical | $350 | $193 |
| Gas & Transport | $300 | $165 |

Fixed picture from the plan: $16,360 net income, ~$3,558 mortgage, $1,768 daycare, ~$3,195 in debt minimums, planned surplus $2,065/mo (split $1,445.50 EF / $619.50 to Milestone-4144, current attack target at $204).

One flag from the dashboard regardless of spending: **EF balance is $200 against a $1,500 Phase 1 target — marked CRITICAL** in your own tracker, and "Debt Paid Down (All Time)" still reads $0, so the plan started 2026-05-01 but nothing's been logged since.

To make "budget check" actually work, I need one of:
1. July rows in `BudgetHistory` with actuals filled in as you spend (the tracker is built for this), or
2. A transactions export (CSV from your bank/card) I can categorize against the May plan, or
3. Tell me rough spend-to-date per category and I'll do the pacing math now.

Fastest fix: copy the 2026-05 rows to 2026-07 in BudgetHistory and start filling column G. I can script that copy if you want.
