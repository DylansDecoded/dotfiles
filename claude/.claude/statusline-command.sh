#!/bin/sh
input=$(cat)
now=$(date +%s)

# Ceilings for the local spend bars, in USD. No server-side quota reaches an
# org/enterprise seat, so the bar needs a number you pick. Tune these.
budget_5h="${CLAUDE_BUDGET_5H:-10}"
budget_7d="${CLAUDE_BUDGET_7D:-200}"

# One jq call for every field: 15 separate invocations cost ~300ms per render.
# \037 (unit separator) can't appear in any of these values, unlike '|'.
IFS=$(printf '\037')
read -r model used worktree total_cost current_dir session_id \
  rl_5h_pct rl_5h_reset rl_7d_pct rl_7d_reset rl_sl_pct rl_sl_reset <<EOF
$(echo "$input" | jq -r '[
  .model.display_name // "Unknown Model",
  .context_window.used_percentage // "",
  .worktree.name // "",
  .cost.total_cost_usd // "",
  .worktree.original_cwd // "",
  .session_id // "",
  .rate_limits.five_hour.used_percentage // "",
  .rate_limits.five_hour.resets_at // "",
  .rate_limits.seven_day.used_percentage // "",
  .rate_limits.seven_day.resets_at // "",
  .rate_limits.spend_limit.used_percentage // "",
  .rate_limits.spend_limit.resets_at // ""
] | map(tostring) | join("\u001f")')
EOF
unset IFS

if [ -n "$used" ]; then
  used_display=$(printf "%.0f" "$used")
  usage_str="${used_display}%"
else
  usage_str="0%"
fi

if [ -n "$worktree" ]; then
  worktree_str="${worktree}"
else
  worktree_str="no worktree"
fi

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

git_str=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null)
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

make_bar() {
  pct="$1"
  width=10
  [ "$pct" -gt 100 ] && pct=100
  filled=$(( pct * width / 100 ))
  empty=$(( width - filled ))
  bar=""
  i=0
  while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i + 1 )); done
  while [ $i -lt $width ];  do bar="${bar}░"; i=$(( i + 1 )); done
  printf "%s" "$bar"
}

# label, integer percent, trailing detail. Suffix is an argument, not part of
# the format string, so a '$' or '%' in it can't be read as a directive.
bar_line() {
  if [ "$2" -ge 90 ]; then color="$RED"
  elif [ "$2" -ge 70 ]; then color="$YELLOW"
  else color="$GREEN"
  fi
  printf "${color}$1 %s %d%%%s${RESET}" "$(make_bar "$2")" "$2" "$3"
}

# rate_limits.*.resets_at is Unix epoch seconds. Render it as time-remaining so
# the 7d and spend_limit windows stay readable when they're days out.
fmt_reset() {
  diff=$(( $1 - now ))
  [ "$diff" -lt 0 ] && diff=0
  if [ "$diff" -ge 86400 ]; then
    printf "%dd%dh" $(( diff / 86400 )) $(( diff % 86400 / 3600 ))
  elif [ "$diff" -ge 3600 ]; then
    printf "%dh%dm" $(( diff / 3600 )) $(( diff % 3600 / 60 ))
  else
    printf "%dm" $(( diff / 60 ))
  fi
}

rate_limit_str=""
append_bar() {
  [ -n "$1" ] && rate_limit_str="${rate_limit_str}${rate_limit_str:+ }${1}"
}

# Server-reported windows. Absent on org/enterprise seats; spend_limit appears
# only behind a Claude apps gateway. Free when missing, correct when present.
add_rl() {
  [ -z "$2" ] && return
  # used_percentage is a float; the test and arithmetic below need an integer.
  pct=$(printf "%.0f" "$2" 2>/dev/null) || return
  detail=""
  [ -n "$3" ] && detail=" in $(fmt_reset "$3")"
  append_bar "$(bar_line "$1" "$pct" "$detail")"
}
add_rl "5h" "$rl_5h_pct" "$rl_5h_reset"
add_rl "7d" "$rl_7d_pct" "$rl_7d_reset"
add_rl "spend" "$rl_sl_pct" "$rl_sl_reset"

# Local spend ledger, since no quota is reported to this account.
# Columns: epoch, session_id, session cumulative cost, delta since last append.
# Append-only, so concurrent sessions can't clobber each other. Summing deltas
# (not per-session cumulatives) is what makes a rolling 5h window honest: a
# session running longer than 5h contributes only what it spent inside it.
cost_log="$HOME/.claude/session-costs.tsv"
if [ -n "$session_id" ] && [ -n "$total_cost" ]; then
  # printf, not `print p + 0`: awk's default OFMT is %.6g, which rounds the
  # previous cumulative and manufactures phantom sub-cent deltas every render.
  prev=$(awk -F'\t' -v s="$session_id" '$2 == s { p = $3 } END { printf "%.10f", p + 0 }' \
    "$cost_log" 2>/dev/null)
  delta=$(awk -v c="$total_cost" -v p="${prev:-0}" \
    'BEGIN { d = c - p; if (d > 0) printf "%.10f", d }')
  if [ -n "$delta" ]; then
    printf '%s\t%s\t%s\t%s\n' "$now" "$session_id" "$total_cost" "$delta" >> "$cost_log"
    # Prune here rather than every render: this branch only runs when the cost
    # actually moved, so the rewrite is rare and the race window is tiny.
    if [ "$(wc -l < "$cost_log" 2>/dev/null || echo 0)" -gt 5000 ]; then
      tmp="${cost_log}.$$"
      awk -F'\t' -v w=$(( now - 604800 )) '$1 >= w' "$cost_log" > "$tmp" 2>/dev/null \
        && mv -f "$tmp" "$cost_log" 2>/dev/null
      rm -f "$tmp" 2>/dev/null
    fi
  fi
  read -r spend_5h spend_7d <<EOF
$(awk -F'\t' -v h=$(( now - 18000 )) -v w=$(( now - 604800 )) \
  '$1 >= w { s7 += $4 } $1 >= h { s5 += $4 } END { printf "%.2f %.2f", s5 + 0, s7 + 0 }' \
  "$cost_log" 2>/dev/null)
EOF
  add_spend() {
    [ -z "$2" ] && return
    pct=$(awk -v s="$2" -v b="$3" 'BEGIN { if (b > 0) printf "%.0f", s / b * 100 }')
    [ -z "$pct" ] && return
    append_bar "$(bar_line "$1" "$pct" " \$$2/\$$3")"
  }
  add_spend "5h" "$spend_5h" "$budget_5h"
  add_spend "7d" "$spend_7d" "$budget_7d"
fi

repo_root=$(cd "$current_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$current_dir")
dir_display=$(basename "$repo_root")

line1="🤖 $model | 🧠 $usage_str | 💰 $block_str"
[ -n "$rate_limit_str" ] && line1="$line1 | ⏱️ $rate_limit_str"
printf "%s\n📁 %s | 🌳 %s | 🌿 %s" "$line1" "$dir_display" "$worktree_str" "$git_str"
