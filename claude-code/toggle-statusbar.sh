#!/bin/bash
# Show/hide Claude's status bar. Usage: toggle-statusbar.sh [on|off|toggle|auto|status]
# Writes the mode to ~/.claude/.sl/bar-mode, which statusline.sh reads on every refresh.
f="$HOME/.claude/.sl/bar-mode"; mkdir -p "$(dirname "$f")"
cur=$(cat "$f" 2>/dev/null); cur=${cur:-auto}
case "${1:-toggle}" in
  on)   new=full;;
  off)  new=quiet;;
  auto) new=auto;;
  status) echo "Status bar mode: $cur"; exit 0;;
  toggle)
    case "$cur" in
      full)  new=quiet;;
      quiet) new=full;;
      *)     if [ -n "$TMUX" ]; then new=full; else new=quiet; fi;;  # auto: hidden in tmux, shown outside
    esac;;
  *) echo "Usage: on | off | toggle | auto | status"; exit 1;;
esac
printf '%s\n' "$new" > "$f"
case "$new" in
  full)  echo "Status bar: ON (always shown). Appears on the next refresh, i.e. after your next message.";;
  quiet) echo "Status bar: OFF (hidden everywhere; tmux bar still gets data). Takes effect on the next refresh.";;
  auto)  echo "Status bar: AUTO (shown outside tmux, hidden inside tmux). Takes effect on the next refresh.";;
esac
