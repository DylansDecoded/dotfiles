#!/usr/bin/env bash
# Run one review round for one reviewer, read-only, with a hard timeout.
# Usage: council-run.sh <reviewer> <round> <prompt-file> <out-dir>
#   Round 1 starts a fresh session and saves its id to <out-dir>/<reviewer>.session
#   Round >1 resumes that session.
#   Critique text lands in <out-dir>/<reviewer>.round<N>.txt
# Exit 0 = got a critique; non-zero = failed (auth/model/timeout) — caller must stop, not retry blind.
set -u
reviewer="$1"; round="$2"; prompt_file="$3"; out="$4"
mkdir -p "$out"
sess="$out/$reviewer.session"
txt="$out/$reviewer.round$round.txt"
prompt="$(cat "$prompt_file")"
TIMEOUT="${COUNCIL_TIMEOUT:-600}"
# ponytail: macOS has no `timeout`; perl alarm is the stdlib equivalent.
# < /dev/null on every CLI: codex (and, observed once, opencode) block on inherited stdin under non-TTY drivers.
t() { perl -e 'alarm shift; exec @ARGV' "$TIMEOUT" "$@" < /dev/null; }

case "$reviewer" in
  codex)
    if [ "$round" = 1 ]; then
      t codex exec -s read-only --json -o "$txt"  "$prompt" 2>/dev/null \
        | grep '"type":"thread.started"' | sed -E 's/.*"thread_id":"([^"]+)".*/\1/' > "$sess"
    else
      # resume rejects -s; -c sandbox_mode is the only thing keeping it read-only.
      t codex exec resume "$(cat "$sess")" -c sandbox_mode="read-only" --json -o "$txt" "$prompt" >/dev/null 2>&1
    fi ;;
  claude)
    if [ "$round" = 1 ]; then
      t claude -p "$prompt" --output-format json --permission-mode plan --tools "Read,Grep,Glob" 2>/dev/null
    else
      t claude -p "$prompt" --resume "$(cat "$sess")" --output-format json --permission-mode plan --tools "Read,Grep,Glob" 2>/dev/null
    fi | python3 -c '
import sys,json; d=json.load(sys.stdin)
open(sys.argv[1],"w").write(d.get("result","")); open(sys.argv[2],"w").write(d["session_id"])' "$txt" "$sess" ;;
  grok)
    RO=(--tools "read_file,grep,list_dir,glob" --disallowed-tools "Agent" --deny "Write" --deny "Edit" --deny "Bash")
    if [ "$round" = 1 ]; then
      t grok -p "$prompt" --output-format json "${RO[@]}" 2>/dev/null
    else
      t grok -p "$prompt" --resume "$(cat "$sess")" --output-format json "${RO[@]}" 2>/dev/null
    fi | python3 -c '
import sys,json; d=json.load(sys.stdin)
open(sys.argv[1],"w").write(d.get("text","")); open(sys.argv[2],"w").write(d["sessionId"])' "$txt" "$sess" ;;
  opencode)
    if [ "$round" = 1 ]; then
      t opencode run --agent plan --format json "$prompt" 2>/dev/null
    else
      t opencode run --agent plan --format json --session "$(cat "$sess")" "$prompt" 2>/dev/null
    fi | python3 -c '
import sys,json
parts=[]; sid=""
for l in sys.stdin:
    try: d=json.loads(l)
    except ValueError: continue
    sid=d.get("sessionID",sid)
    if d.get("type")=="text": parts.append(d["part"]["text"])
open(sys.argv[1],"w").write("\n".join(parts)); open(sys.argv[2],"w").write(sid)' "$txt" "$sess" ;;
  kimi)
    if [ "$round" = 1 ]; then
      t kimi -p "$prompt" > "$txt" 2>/dev/null
      grep -oE 'session_[0-9a-f-]+' "$txt" | tail -1 > "$sess"
    else
      t kimi -S "$(cat "$sess")" -p "$prompt" > "$txt" 2>/dev/null
    fi ;;
  *) echo "unknown reviewer: $reviewer" >&2; exit 2 ;;
esac

[ -s "$txt" ] && [ -s "$sess" ] || { echo "$reviewer round $round produced no critique/session — auth, model, or timeout failure" >&2; exit 1; }
echo "$reviewer: $(grep -oE 'VERDICT: *(APPROVED|REVISE)' "$txt" | tail -1)"
