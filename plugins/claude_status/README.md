# Claude Status

A panel that shows a stop light per [Claude Code](https://claude.com/claude-code) session, so you can see at a glance which sessions are busy and which need you. A second panel, **Claude Usage**, shows how much of the 5-hour and weekly rate limits is used.

| Light  | Status    | Meaning                                                      |
|--------|-----------|--------------------------------------------------------------|
| Green  | `working` | Claude is working                                            |
| Yellow | `waiting` | Claude is waiting for your input (permission or a question) |
| Red    | `stopped` | Claude finished its turn                                     |

The panels don't talk to Claude Code directly. Instead, Claude Code hooks write each session's state to a JSON file, and the status line script adds the rate limits to it. The panels read the file once per second.

## Setup

### 1. Install the hook script

The hook script [`set-status.sh`](set-status.sh) maintains the status file (`~/.claude/status.json`). It needs `bash` and `jq`.

```bash
mkdir -p ~/.claude/hooks
cp set-status.sh ~/.claude/hooks/set-status.sh
chmod +x ~/.claude/hooks/set-status.sh
```

### 2. Register the hooks

Add the following to your `~/.claude/settings.json`:

```json
TODO
```

New sessions pick up the hooks automatically. Already running sessions have to be restarted.

### 3. Install the status line script (for Claude Usage)

Claude Code only passes the rate limits to the status line, so [`statusline.sh`](statusline.sh) copies them into the status file. It prints nothing, so the status line stays empty, and it replaces any status line you had.

```bash
cp statusline.sh ~/.claude/hooks/statusline.sh
```

And in your `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/hooks/statusline.sh"
}
```

The usage is only updated while a Claude Code session is open.

### 4. Add the panels

Enable the **Claude Status** plugin in the plugins menu, then add a **Claude Status** and/or **Claude Usage** panel to your layout.

## Settings

Each panel has its own settings:

- **Status file**: path to the status JSON, `$HOME/.claude/status.json` by default. `$HOME` and `~` are expanded.
- **Max sessions** (Claude Status only): how many stop lights are shown at most. If there are more sessions, the most recently updated ones are shown. Lights keep their position while sessions update.
- **Caption** (Claude Status only): what is shown below each stop light: nothing, the session ID, the session name (set via `/rename`), the last prompt, or the detail (what Claude is waiting for, or the start of its last message).
- **Read via SSH**: read the status file from another machine through a client of the SSH plugin, for example when Claude Code runs on a different computer than DreamDeck. The status file path is then the path on that machine. Only shown while the SSH plugin is enabled.
- **SSH client**: the SSH plugin client to read the status file through.

## Claude Usage

One bar per rate limit, with the time until it resets. The bar is green below 50%, yellow below 80% and red above. Once the reset time has passed the bar shows 0%, since the status line only writes new numbers once Claude Code is used again.

## Status file format

If you want to produce the status file some other way, this is what the panels expect:

```json
{
  "sessions": {
    "9dd3bfb8-3815-4bb4-860e-0940dad81396": {
      "name": "Testing",
      "status": "stopped",
      "prompt": "Hello",
      "detail": "Hello! What would you like to test?",
      "updated_at": "2026-09-30T09:46:55Z"
    }
  },
  "rate_limits": {
    "five_hour": {
      "used_percentage": 23,
      "resets_at": 1790905800
    },
    "seven_day": {
      "used_percentage": 44,
      "resets_at": 1791255600
    }
  }
}
```

- `status` is one of `working`, `waiting` or `stopped`. Any other value shows all lamps off.
- `name`, `prompt` and `detail` are optional and may be `null`.
- `updated_at` is an ISO 8601 UTC timestamp, used to pick the most recent sessions.
- `rate_limits` is only needed for Claude Usage. `used_percentage` is 0 to 100 and `resets_at` is a unix timestamp. A missing limit shows as 0%, and a missing `resets_at` hides the countdown.
