#!/bin/sh
# Grok has no rate-limit payload; effort + turn timer fill that slot.
input=$(cat)

eval "$(printf '%s\n' "$input" | jq -r '
  "model=\(.model.display_name // "Unknown Model" | @sh)",
  "used=\(.context_window.used_percentage // "" | @sh)",
  "worktree=\(.worktree.name // .workspace.git_worktree // "" | @sh)",
  "total_cost=\(.cost.total_cost_usd // "" | @sh)",
  "current_dir=\(.workspace.current_dir // .cwd // "" | @sh)",
  "repo_root=\(.workspace.repo_root // "" | @sh)",
  "json_branch=\(.workspace.branch // "" | @sh)",
  "effort=\(.effort.level // "" | @sh)",
  "started_ms=\(.turn.started_at_ms // "" | @sh)"
')"

if [ -n "$used" ]; then
  used_display=$(printf "%.0f" "$used")
else
  used_display=0
fi

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

if [ "$used_display" -ge 90 ]; then
  usage_str="${RED}${used_display}%${RESET}"
elif [ "$used_display" -ge 80 ]; then
  usage_str="${YELLOW}${used_display}%${RESET}"
else
  usage_str="${used_display}%"
fi

if [ -n "$worktree" ]; then
  worktree_str="${worktree}"
else
  worktree_str="no worktree"
fi

if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
  cd "$current_dir" || true
fi

git_str=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  branch=$json_branch
  [ -z "$branch" ] && branch=$(git branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  staged=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  modified=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')

  git_str="$branch"
  [ "$staged" -gt 0 ] && git_str="${git_str} $(printf "${GREEN}+${staged}${RESET}")"
  [ "$modified" -gt 0 ] && git_str="${git_str} $(printf "${YELLOW}~${modified}${RESET}")"
else
  git_str="no branch"
fi

if [ -n "$total_cost" ]; then
  cost_display=$(awk "BEGIN { printf \"%.2f\", $total_cost }")
  block_str="\$${cost_display}"
else
  block_str="\$0.00"
fi

extra_str=""
if [ -n "$effort" ]; then
  extra_str="⚡ ${effort}"
fi
if [ -n "$started_ms" ]; then
  now_s=$(date +%s)
  elapsed=$(( now_s - started_ms / 1000 ))
  [ "$elapsed" -lt 0 ] && elapsed=0
  if [ "$elapsed" -ge 60 ]; then
    timer_str="$((elapsed / 60))m$((elapsed % 60))s"
  else
    timer_str="${elapsed}s"
  fi
  if [ -n "$extra_str" ]; then
    extra_str="${extra_str} | ⏱️ ${timer_str}"
  else
    extra_str="⏱️ ${timer_str}"
  fi
fi

if [ -n "$repo_root" ]; then
  dir_display=$(basename "$repo_root")
elif [ -n "$current_dir" ]; then
  dir_display=$(basename "$current_dir")
else
  dir_display="."
fi

line1="🤖 ${model} | 🧠 ${usage_str} | 💰 ${block_str}"
[ -n "$extra_str" ] && line1="${line1} | ${extra_str}"

printf '%b\n' "$line1"
printf '%b\n' "📁 ${dir_display} | 🌳 ${worktree_str} | 🌿 ${git_str}"
