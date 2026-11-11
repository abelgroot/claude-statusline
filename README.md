# claude-statusline

My Claude Code status line: Catppuccin Mocha rounded pills, responsive to terminal width.

- Left: DIR (folder + git branch), PROJECT (only if different from folder)
- Right: MODEL (+ effort), CTX, SESSION (5h limit + reset time), WEEK (7d limit + reset day/time), COST
- Shrinks in 7 steps as the terminal narrows

Needs: `jq`, `git`, a Nerd Font (for the rounded pill caps), bash.

## Install
```sh
cp statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
```
Add to `~/.claude/settings.json`:
```json
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh", "padding": 0 }
```

## tmux
`tmux.conf` is my tmux config (Catppuccin Mocha, rounded windows). The tmux status bar sits at the top
(`set -g status-position top`), above the Claude Code pane. Claude's status line and the tmux bar stay separate.
Install: `cp tmux.conf ~/.tmux.conf` then `prefix + r` to reload (needs tpm + plugins).

## Cost pill
Cost is Claude Code's local estimate (tokens x API prices), not a bill. It is shown when no plan limits are
reported (API billing), when the session or week limit hits 100% (extra/credit usage takes over), or always if
`STATUSLINE_SHOW_COST=1` is set. Otherwise it is hidden on subscriptions.
