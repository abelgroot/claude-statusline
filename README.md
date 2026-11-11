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
