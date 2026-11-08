#!/usr/bin/env bash
set -u
auth_dir='/Users/dylan/.grok/hooks/fm-turn-end.d'
workspace=${GROK_WORKSPACE_ROOT:-}
[ -n "$workspace" ] || exit 0
p="$workspace/.fm-grok-turnend"
[ -f "$p" ] || exit 0
first=
IFS= read -r -n 256 first < "$p" 2>/dev/null || [ -n "$first" ] || exit 0
case "$first" in token=*) token=${first#token=} ;; *) exit 0 ;; esac
case "$token" in fm.????????????) : ;; *) exit 0 ;; esac
case "$token" in *[!A-Za-z0-9._-]*) exit 0 ;; esac
t=$(cat "$auth_dir/$token" 2>/dev/null) || exit 0
case "$t" in /*.turn-ended) : ;; *) exit 0 ;; esac
touch "$t" 2>/dev/null || true
exit 0
