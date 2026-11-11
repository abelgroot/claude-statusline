# Dev notes / context handoff

Compact summary of how this project was built, so a future Claude session (or you) can fix bugs without re-deriving everything.
To resume: start Claude in a clone of this repo and say "read docs/DEV-NOTES.md, then fix <bug>".

## Goal
A Claude Code status line (folder, git branch, project, model+effort, context, 5h session / 7d week limits with reset times, cost)
styled as Catppuccin Mocha rounded pills, responsive to terminal width, plus a compact version inside the tmux bar.

## Files and data flow
```
Claude Code --(JSON on stdin, every refreshInterval s + after each response)--> claude-code/statusline.sh
  statusline.sh does, in this order:
    1. ONE jq call parses all fields (script runs often; keep it cheap)
    2. caches model|effort  -> ~/.claude/.sl/<cksum of cwd>  and ~/.claude/.sl/last
    3. merges limits        -> ~/.claude/.statusline-limits   ("h5|h5reset|d7|d7reset", atomic write)
    4. reads mode           -> env STATUSLINE_MODE > ~/.claude/.sl/bar-mode (/status_bar) > auto
       quiet, or auto inside tmux ($TMUX set) -> exit 0 (prints nothing, bar hidden)
    5. otherwise renders the pills (responsive, 7 width levels)
tmux (status-interval 5) --> tmux/tmux-claude.sh bars <pane_current_path> --> reads the caches, prints tmux style codes
toggle: claude-code/toggle-statusbar.sh  (slash command claude-code/commands/status_bar.md, tmux key prefix+B)
```

## Key facts / decisions (and why)
- **Claude Code only exposes limits, model, effort and cost to the status-line script**, so statusline.sh is also the data collector for tmux.
  It cannot be told to redraw from outside: SIGWINCH has no effect; tmux send-keys into Claude's pane is blocked by auto-mode safety.
  Hence `"refreshInterval": 5` in settings (polling) and a fast script (~25 ms/run).
- **Limits are account-wide but each session only has its own last snapshot** (older sessions report stale/empty values).
  Cache merge rule: a reading replaces the cache only if it is for a newer window, or the same window with >= usage; empty never wipes;
  expired windows are dropped. This fixed the tmux "S" pill flickering/disappearing/showing a bogus 0. A real 0% right after a window reset is correct.
- **Cost** is a local estimate (tokens x API price), not a bill. Shown only without plan limits (API billing), when a limit hits 100%, or with STATUSLINE_SHOW_COST=1.
- **Width:** `MARGIN=4` leaves room for Claude Code's own left indent + right edge. `"padding": 0` is the minimum. In tmux the width comes from
  `tmux display -p -t $TMUX_PANE '#{pane_width}'` (NOT the active pane: that was a bug), then `stty size </dev/tty`, then $COLUMNS. `SL_COLS=<n>` overrides for tests.
- **Visible width** is computed by stripping ANSI and `wc -m` (Nerd Font glyphs count 1). Emoji would count 1 but render 2: avoid emoji in pills.
- **Labels are text (DIR, PROJECT, MODEL, CTX, SESSION, WEEK, COST)**, not icons: Nerd icons rendered badly / didn't explain the values. Only the rounded caps use Nerd glyphs (U+E0B6 / U+E0B4).
- **Colors:** pill text background neutral gray 43;43;43, empty bar track 95;95;95, severity fill green <60, peach <85, red >=85.
- **tmux module is hand-built** (tmux/claude-catppuccin.conf). Catppuccin's own `source -F .../status_module.conf` does NOT work from ~/.tmux.conf:
  sourced files run after the current file finishes, so the %hidden MODULE_NAME is out of scope. Use `#{E:@catppuccin_status_module_text_bg}` (it is a conditional string).
- `#(...)` inside a tmux `#{?...}` condition doesn't evaluate reliably; the pill's visibility uses the native
  `#{m/r:^(claude|[0-9]+\.[0-9]+\.[0-9]+)$,#{pane_current_command}}` instead (Claude's process name shows as its version, e.g. 2.1.322).
- Theme: catppuccin/tmux v2.1.2, mocha, rounded window style.
- Bash gotchas hit: `until` is a reserved word (function renamed `remaining`); macOS bash 3.2 has no `\u` escapes (glyphs are written literally); BSD `date -r <epoch>` and `sed -i ''`.

## Debug recipes
```sh
# render with fake data at a given width (full mode forces drawing even inside tmux)
echo '{"workspace":{"current_dir":"/tmp/x","project_dir":"/tmp/x"},"model":{"id":"a","display_name":"Sonnet 5.5"},"effort":{"level":"medium"},
"rate_limits":{"five_hour":{"used_percentage":35,"resets_at":'$(( $(date +%s)+8000 ))'}}}' | STATUSLINE_MODE=full SL_COLS=120 bash claude-code/statusline.sh
# strip colors:  | sed $'s/\x1b\\[[0-9;]*m//g'
~/.claude/tmux-claude.sh bars "$PWD"        # what the tmux pill will print
cat ~/.claude/.statusline-limits ~/.claude/.sl/last
tmux display -p -t %N '#{E:@catppuccin_window_text}'   # test window-name format for a pane
# see what a live session actually sends: temporarily set statusLine.command to
#   tee /tmp/sl.input | bash ~/.claude/statusline.sh   and inspect /tmp/sl.input (restore afterwards)
```
Careful: tests that run the real script write the real caches (limits/model). Back up `~/.claude/.statusline-limits` first or expect a live session to overwrite it within seconds.

## Known limitations / ideas
- Limits are only as fresh as the last Claude response; model/effort are matched per working folder (no cross-session fallback: a new window shows no model until its first refresh, within `refreshInterval`).
- The tmux pill shows only while the active pane runs Claude; other panes/sessions don't show it.
- Ultra narrow terminals: level 7 shows only a truncated folder; below ~25 columns it can still overflow.
- `/status_bar` takes a model turn to print its one-line reply; `prefix + B` is instant (applies within refreshInterval seconds).
- Done since the first version: reset countdown + git branch in the tmux pill, theme-agnostic script (`@claude_*` options, `tmux/claude-plain.conf`), ultra-narrow level 7.
- Ideas not done: dirty marker for the tmux branch (git status every 5 s may be slow in big repos), more themes with ready-made snippets, a per-pane (instead of per-folder) model cache.
