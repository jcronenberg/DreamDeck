#!/bin/bash
# Claude Code status line command: mirrors rate limits into ~/.claude/status.json
# Prints nothing, so the status bar stays empty.
input=$(cat)
dir="$HOME/.claude"
file="$dir/status.json"
lock="$dir/status.lock"

rl=$(echo "$input" | jq -c '.rate_limits // empty')
[ -z "$rl" ] && exit 0

acquired=0
for _ in $(seq 1 50); do
  if mkdir "$lock" 2>/dev/null; then acquired=1; break; fi
  sleep 0.1
done
if [ "$acquired" -eq 0 ]; then
  rmdir "$lock" 2>/dev/null
  mkdir "$lock" 2>/dev/null || exit 0
fi
trap 'rmdir "$lock" 2>/dev/null' EXIT

jq -e . "$file" >/dev/null 2>&1 || echo '{"sessions":{}}' > "$file"
tmp=$(mktemp "$dir/status.json.XXXXXX") || exit 0

if jq --argjson rl "$rl" '
     .rate_limits = ($rl | .updated_at = (now | floor | todate))
   ' "$file" > "$tmp"; then
  mv "$tmp" "$file"
else
  rm -f "$tmp"
fi
exit 0
