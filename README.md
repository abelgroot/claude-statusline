# claude-statusline

Two parts that work together. Use one or both.

1. **Claude Code status line** (`claude-code/statusline.sh`) – Catppuccin-style rounded pills below the prompt: folder + git branch, project, model + effort, context, session/week limits (with reset time), cost (API billing only).
2. **tmux integration** (`tmux/`) – the same info (compact) in your tmux bar, plus `✻ folder` window names while Claude runs.

> Claude Code only exposes usage limits / model / effort to its status-line script, so part 1 is also the
> **data collector** for part 2. Inside tmux it stays silent by default (see *Modes*) and just caches data.

## Requirements
`bash`, `jq`, `git`, a Nerd Font (rounded pill caps), Claude Code 2.1+ (Pro/Max shows limits). For tmux: tmux ≥ 3.2.

## Part 1 – Claude Code status line
```sh
mkdir -p ~/.claude
cp claude-code/statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
```
Add to `~/.claude/settings.json`:
```json
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh", "padding": 0, "refreshInterval": 5 }
```
Layout adapts to terminal width. `MARGIN=4` near the bottom of the script controls the right edge.

**Modes** (`STATUSLINE_MODE`, e.g. `"command": "STATUSLINE_MODE=full bash ~/.claude/statusline.sh"`):
- `auto` (default): draw the bar, except inside tmux where it stays silent and only caches data for the tmux bar
- `full`: always draw it
- `quiet`: never draw it (collect only)

**Show/hide on demand** – `/status_bar` slash command (and `prefix + B` in tmux):
```sh
cp claude-code/toggle-statusbar.sh ~/.claude/toggle-statusbar.sh && chmod +x ~/.claude/toggle-statusbar.sh
mkdir -p ~/.claude/commands && cp claude-code/commands/status_bar.md ~/.claude/commands/
```
Usage: `/status_bar` (toggle), `/status_bar on`, `off`, `auto`, `status`. It writes the mode to `~/.claude/.sl/bar-mode`
(global for all sessions); the change shows within `refreshInterval` seconds (5 with the setting above; without it, only after your next message). `STATUSLINE_MODE` in the
command still takes priority over this setting. Data collection for the tmux bar continues even when the bar is off.

**Cost pill:** Claude Code's local estimate (tokens × API prices), not a bill. Shown only without plan limits (API billing), when a limit hits 100%, or with `STATUSLINE_SHOW_COST=1`.

## Part 2 – tmux integration (Catppuccin theme)
**Theme:** [catppuccin/tmux](https://github.com/catppuccin/tmux) v2.x (built and tested on **v2.1.2, flavor `mocha`, `@catppuccin_window_status_style "rounded"`**). The pill uses the theme's own colors, separators and text background, so it follows your flavor. Other themes will need the colors in `tmux/claude-catppuccin.conf` adapted.

Setup:
1. Install Part 1 (it writes the cache files `~/.claude/.statusline-limits` and `~/.claude/.sl/*`).
2. Install the tmux script:
   ```sh
   cp tmux/tmux-claude.sh ~/.claude/tmux-claude.sh && chmod +x ~/.claude/tmux-claude.sh
   ```
3. Copy `tmux/claude-catppuccin.conf` to `~/.config/tmux/claude-catppuccin.conf` and in `~/.tmux.conf`, **after** the catppuccin plugin is loaded:
   ```tmux
   source-file ~/.config/tmux/claude-catppuccin.conf
   set -g status-right "#{?#{m/r:^(claude|[0-9]+\.[0-9]+\.[0-9]+)$,#{pane_current_command}},#{E:@catppuccin_status_claude},}#{E:@catppuccin_status_application}"
   ```
   (keep your other modules; `tmux/example-tmux.conf` is my full config for reference).
4. Reload: `tmux source-file ~/.tmux.conf`.

What you get: `✻ So5.5·M  S ████ 14%  W ████ 55%` on the right while the active pane runs Claude (`So5.5·M` = Sonnet 5.5, medium effort; `S` = 5-hour session, `W` = 7-day week), and window tabs named `✻ foldername`.

**Why polling:** Claude Code can't be told to redraw its status line from outside (I tested SIGWINCH and tmux key presses: no effect), so `refreshInterval` is the only way for `/status_bar` or `prefix + B` to apply without sending a message. The script is built to make this nearly free: one `jq` call and an early exit when hidden (~25 ms per run). Remove `refreshInterval` if you prefer; toggles then apply after your next message.

**Polling:** tmux re-runs the script every `status-interval` seconds (5 by default, set in the snippet). The script only reads small cache files, so it is cheap. Data itself refreshes whenever Claude Code re-runs the status line (every `refreshInterval` seconds and after each response); expired windows are hidden automatically.
