# daily-ai-radar — loop construct

Every morning (at login, or 7:30 if the Mac is already awake) this loop scans AI
news (new models, benchmarks, lab announcements), pulls GitHub's top-10 trending
repos for the day/week/month, curates it into one briefing in your Obsidian vault,
pings Discord, and has **Codex** grade the result so the next run improves.

## The four phases + stop rule

| Phase | Implementation |
|---|---|
| **Trigger** | `com.dylan.daily-ai-radar.plist` (launchd): `RunAtLoad` fires at login; `StartCalendarInterval` fires 7:30 daily. `run.sh` guards so only one run happens per day and waits for network first. |
| **Execution** | `~/.claude/skills/daily-ai-radar/SKILL.md` — reads state, scans, curates, writes `Inbox/YYYY-MM-DD-ai-radar.md`, posts Discord. |
| **Verification** | Tier 2: structural gate (sections present, 3×10 real repos, 24h freshness, no repeats). Tier 4: `codex exec` judges 1–10 with `judge-prompt.md` — a different model than the executor, so no self-grading. |
| **State** | `state.json` — per run: headlines covered, repos featured, judge verdict, your feedback. Next run reads it to dedupe and applies `instructions_for_tomorrow`. Your feedback outranks the judge. |
| **Stop rule** | Hard cap one run/day (file-exists guard). Kill switch: `touch disabled` in this folder, or `launchctl bootout gui/$(id -u)/com.dylan.daily-ai-radar`. |

## Maturity ladder position

Started at rung 2 (morning-report skill existed, run by hand, no memory). This
construct is rung 4: automated trigger + state + judge + stop rule. The GitHub
trending piece was new, so treat the first run's output as the validation pass —
if the tables look wrong, say so and the feedback lands in state.

## Files

- `run.sh` — launchd entrypoint (guard → network wait → headless `claude -p` with a scoped tool allowlist)
- `com.dylan.daily-ai-radar.plist` — the trigger (see trigger.md to install)
- `state.json` / `state.schema.json` — the loop's memory
- `judge-prompt.md` — what Codex grades against
- `config.json` — put your Discord webhook URL here (chmod 600)
- `run.log` — every trigger fire, skip, and exit code

## Debugging

- Briefing missing? Check `run.log` — you'll see "already ran", "no network", or the claude exit code.
- Judge null in state? Codex call failed; the briefing still ships, scoring resumes next run.
- Repeated stories? Check the run's `headlines_covered` keys — dedupe matches on those.
- To re-run today: delete today's `Inbox/*-ai-radar.md`, then `zsh run.sh` (or ask Claude to "run the daily-ai-radar skill").

## Steering it

Say "good report" / "too noisy" / "more benchmark depth" to Claude in any session —
it appends to that run's `user_feedback` in state, and that outranks the judge.
