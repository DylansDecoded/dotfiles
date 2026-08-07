# Trigger — install / remove

Install (copies the plist into launchd's watched folder and loads it):

```bash
cp ~/.claude/skills/daily-ai-radar-workspace/com.dylan.daily-ai-radar.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dylan.daily-ai-radar.plist
```

Loading it fires `RunAtLoad` immediately — the run.sh guard makes that a no-op if
today already ran. After install it fires at every login and at 7:30am when awake.

Change the schedule: edit `StartCalendarInterval` in the plist, then:

```bash
launchctl bootout gui/$(id -u)/com.dylan.daily-ai-radar
cp ~/.claude/skills/daily-ai-radar-workspace/com.dylan.daily-ai-radar.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dylan.daily-ai-radar.plist
```

Remove entirely:

```bash
launchctl bootout gui/$(id -u)/com.dylan.daily-ai-radar
rm ~/Library/LaunchAgents/com.dylan.daily-ai-radar.plist
```

Pause without removing: `touch ~/.claude/skills/daily-ai-radar-workspace/disabled`
