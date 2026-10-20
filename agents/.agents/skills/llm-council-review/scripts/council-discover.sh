#!/usr/bin/env bash
# Print the LLM CLIs available on this machine, one per line, excluding the host.
# Usage: council-discover.sh <host>   (host ∈ claude|codex|grok|kimi|opencode)
# ponytail: PATH lookup only; auth is checked by the first real round, not here.
host="${1:?usage: council-discover.sh <host>}"
for c in codex claude grok kimi opencode; do
  [ "$c" = "$host" ] && continue
  command -v "$c" >/dev/null 2>&1 && echo "$c"
done
