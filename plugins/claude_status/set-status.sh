#!/bin/bash
# Usage: set-status.sh <working|stopped|waiting|end>
# Reads the Claude Code hook payload (JSON) from stdin and maintains
# ~/.claude/status.json with one entry per session.
# A "stopped" event is reported as "working" if background tasks are still running.

event="$1"
status="$event"
input=$(cat)
dir="$HOME/.claude"
file="$dir/status.json"
lock="$dir/status.lock"

mkdir -p "$dir"

sid=$(echo "$input" | jq -r '.session_id // empty')
[ -z "$sid" ] && exit 0

[ "$event" = "end" ] && end=true || end=false

# Turn ended, but background work (run_in_background shells / subagents) is still running?
bgdesc=""
if [ "$event" = "stopped" ]; then
  bgdesc=$(echo "$input" | jq -r '
    [ (.background_tasks // [])[]
      | select(.status == "running")
      | (.description // .command // .id) ]
    | join("; ") | gsub("\\s+"; " ")')
  [ -n "$bgdesc" ] && status="working"
fi

# Latest user prompt (only present on UserPromptSubmit), collapsed and truncated
prompt=$(echo "$input" | jq -r '(.prompt // empty) | gsub("\\s+"; " ") | .[0:100]')

# Context for the current state:
#  - waiting: what Claude is waiting for (permission or question)
#  - stopped: start of Claude's final message
#  - working because of background tasks: what is running
detail=$(echo "$input" | jq -r --arg status "$status" '
  (if $status == "waiting" and .tool_name then
     (if .tool_name == "AskUserQuestion" then "Asking a question"
      else "Permission: " + .tool_name + " " + ((.tool_input.command // .tool_input.file_path // "") | tostring)
      end)
   else (.message // .last_assistant_message // empty) end)
  | gsub("\\s+"; " ") | .[0:150]')
[ -n "$bgdesc" ] && detail="Background: ${bgdesc:0:140}"

# Session name from the transcript (last custom-title event).
# Only looked up on prompt/stop, since transcripts can be large.
name=""
tp=$(echo "$input" | jq -r '.transcript_path // empty')
tp="${tp/#\~/$HOME}"
if { [ -n "$prompt" ] || [ "$event" = "stopped" ]; } && [ -f "$tp" ]; then
  name=$(grep -F 'custom-title' "$tp" \
    | jq -r 'select(.type == "custom-title") | .customTitle' 2>/dev/null \
    | tail -1)
fi

# Serialize read-modify-write across concurrent sessions.
# mkdir is atomic and works on macOS and Linux (no flock needed).
acquired=0
for _ in $(seq 1 50); do
  if mkdir "$lock" 2>/dev/null; then acquired=1; break; fi
  sleep 0.1
done
if [ "$acquired" -eq 0 ]; then
  # Lock held for 5s+ -> assume stale (crashed hook) and take over
  rmdir "$lock" 2>/dev/null
  mkdir "$lock" 2>/dev/null || exit 0
fi
trap 'rmdir "$lock" 2>/dev/null' EXIT

# Start fresh if the file is missing or invalid
if ! jq -e . "$file" >/dev/null 2>&1; then
  echo '{"sessions":{}}' > "$file"
fi

tmp=$(mktemp "$dir/status.json.XXXXXX") || exit 0

if jq --arg sid "$sid" --arg status "$status" --arg prompt "$prompt" \
      --arg detail "$detail" --arg name "$name" --argjson end "$end" '
    (now | floor) as $now
    | .sessions //= {}
    | (.sessions[$sid] // {}) as $old
    | if $end then
        del(.sessions[$sid])
      else
        .sessions[$sid] = {
          name: (if $name != "" then $name else $old.name end),
          status: $status,
          prompt: (if $prompt != "" then $prompt else $old.prompt end),
          detail: (if $detail != "" then $detail else null end),
          updated_at: ($now | todate)
        }
      end
    # Cleanup: drop stopped sessions older than 1 hour
    | .sessions |= with_entries(
        select(
          .value.status != "stopped"
          or ($now - (.value.updated_at | fromdateiso8601)) < 3600
        )
      )
  ' "$file" > "$tmp"; then
  mv "$tmp" "$file"
else
  rm -f "$tmp"
fi
exit 0
