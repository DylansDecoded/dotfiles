#!/bin/zsh
# daily-ai-radar launchd runner: once-per-day guard + network wait + headless claude
set -u
WS="$HOME/.claude/skills/daily-ai-radar-workspace"
LOG="$WS/run.log"
TODAY=$(date +%F)

exec >> "$LOG" 2>&1
echo "--- $(date) trigger fired"

[ -f "$WS/disabled" ] && { echo "disabled file present, skipping"; exit 0; }

# Guard: skip if today's briefing already exists
if [ -f "/Users/dylan/Projects/personal/obsidian/Inbox/$TODAY-ai-radar.md" ]; then
  echo "already ran today, skipping"; exit 0
fi

# Wait for network (up to 5 min) — login often precedes Wi-Fi
for i in $(seq 1 30); do
  nc -z -w 2 github.com 443 2>/dev/null && break
  sleep 10
done
nc -z -w 2 github.com 443 2>/dev/null || { echo "no network after 5m, giving up"; exit 1; }

echo "running claude"
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
# Scoped allowlist: only the tools the radar skill actually uses. No blanket
# permission skip — anything outside this list fails rather than prompts.
claude -p "Run the daily-ai-radar skill." \
  --allowedTools "Skill,Read,Write,Edit,mcp__crawler__search,mcp__crawler__crawl,Bash(curl:*),Bash(codex:*),Bash(jq:*),Bash(cat:*),Bash(date:*),Bash(mkdir:*),Bash(ls:*)"
echo "exit: $?"
