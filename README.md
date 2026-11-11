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
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" }
```
