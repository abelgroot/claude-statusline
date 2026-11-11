#!/bin/bash
# Claude Code status line, Catppuccin Mocha "rounded" pills (matches tmux theme)
input=$(cat)

# One jq call for every field (fast: this script can run every few seconds)
US=$'\x1f'
IFS="$US" read -r cwd proj model mid cost effort ctx h5 h5r d7 d7r < <(
  printf '%s' "$input" | jq -r '[
    (.workspace.current_dir // .cwd // ""), (.workspace.project_dir // ""),
    (.model.display_name // ""), (.model.id // ""), (.cost.total_cost_usd // ""),
    (.effort.level // .effort_level // .effortLevel // ""),
    (.context_window.used_percentage // ""),
    (.rate_limits.five_hour.used_percentage // ""), (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""), (.rate_limits.seven_day.resets_at // "")
  ] | map(tostring) | join("\u001f")' 2>/dev/null)
[ -z "$proj" ] && proj="$cwd"
if [ -z "$effort" ] && [ -f "$HOME/.claude/settings.json" ]; then
  effort=$(jq -r --arg id "$mid" '
    ((.modelSettings // {}) | to_entries
      | map(select(.key as $k | $id | startswith($k))) | sort_by(.key|length) | last | .value.effortLevel)
    // .effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi


# Cache model/effort for the tmux bar (keyed by working dir)
if [ -n "$model" ]; then
  mkdir -p "$HOME/.claude/.sl" 2>/dev/null
  mrec="$model|$effort"
  [ -n "$cwd" ] && printf '%s\n' "$mrec" > "$HOME/.claude/.sl/$(printf '%s' "$cwd" | cksum | cut -d' ' -f1)" 2>/dev/null
fi

# Usage limits are account-wide, but every Claude session only knows the snapshot from its OWN last
# response (older sessions report stale or empty values). Merge them so the freshest data always wins:
# a reading replaces the cache only if it is for a newer window, or the same window with >= usage.
# Empty readings never wipe anything. Windows that already reset are dropped.
LCACHE="$HOME/.claude/.statusline-limits"
now=$(date +%s)
c5=""; c5r=""; c7=""; c7r=""
[ -f "$LCACHE" ] && IFS='|' read -r c5 c5r c7 c7r < "$LCACHE"
fresher() { # in_pct in_reset cached_pct cached_reset -> success if incoming should replace cache
  [ -n "$1" ] && [ -n "$2" ] || return 1
  [ "$2" -gt "$now" ] 2>/dev/null || return 1
  [ -n "$4" ] && [ "$4" -gt "$now" ] 2>/dev/null || return 0
  [ "$2" -gt "$4" ] && return 0
  [ "$2" -eq "$4" ] && [ "${1%.*}" -ge "${3%.*}" ] && return 0
  return 1
}
changed=0
fresher "$h5" "$h5r" "$c5" "$c5r" && { c5=$h5; c5r=$h5r; changed=1; }
fresher "$d7" "$d7r" "$c7" "$c7r" && { c7=$d7; c7r=$d7r; changed=1; }
if [ "$changed" = 1 ]; then
  printf '%s|%s|%s|%s\n' "$c5" "$c5r" "$c7" "$c7r" > "$LCACHE.$$" 2>/dev/null && mv -f "$LCACHE.$$" "$LCACHE"
fi
h5=""; h5r=""; d7=""; d7r=""
[ -n "$c5" ] && [ "${c5r:-0}" -gt "$now" ] && { h5=$c5; h5r=$c5r; }
[ -n "$c7" ] && [ "${c7r:-0}" -gt "$now" ] && { d7=$c7; d7r=$c7r; }

# Display mode (data above is always cached for the tmux bar):
#   STATUSLINE_MODE=full  -> always draw the bar below the prompt
#   STATUSLINE_MODE=quiet -> never draw it (collect only)
#   STATUSLINE_MODE=auto  -> default: draw it, except inside tmux (tmux bar shows the info instead)
mode=${STATUSLINE_MODE:-$(cat "$HOME/.claude/.sl/bar-mode" 2>/dev/null)}; mode=${mode:-auto}   # env var > flag file (/status_bar) > auto
if [ "$mode" = quiet ] || { [ "$mode" = auto ] && [ -n "$TMUX" ]; }; then exit 0; fi

# Catppuccin Mocha (r;g;b)
BASE="30;30;46"; SURF0="43;43;43"; SURF1="69;71;90"; TEXT="205;214;244"; SUB="166;173;200"
BLUE="137;180;250"; MAUVE="203;166;247"; GREEN="166;227;161"; YELLOW="249;226;175"
RED="243;139;168"; PEACH="250;179;135"; TEAL="148;226;213"; LAV="180;190;254"; PINK="245;194;231"
fg() { printf '\e[38;2;%sm' "$1"; }
bg() { printf '\e[48;2;%sm' "$1"; }
RST=$'\e[0m'
LC=''; RC=''

# pill <accent> <icon> <text-with-inline-fg-codes>
pill() {
  printf '%s%s%s%s %s %s%s%s %s%s%s%s%s%s' \
    "$(fg "$1")" "$LC" \
    "$(bg "$1")$(fg "$BASE")" "$2" "" "$(bg "$SURF0")$(fg "$TEXT")" "" "" "$3" " " "$RST" "$(fg "$SURF0")" "$RC" "$RST"
}

sevcolor() {
  local p=${1%.*}; p=${p:-0}
  if [ "$p" -ge 85 ]; then echo "$RED"; elif [ "$p" -ge 60 ]; then echo "$PEACH"; else echo "$GREEN"; fi
}

bar() { # pct width color
  local p=${1%.*}; p=${p:-0}; local w=$2
  [ "$p" -gt 100 ] && p=100
  local f=$(( (p * w + 50) / 100 )) i
  printf '%s' "$(fg "$3")"
  for ((i=0;i<f;i++)); do printf '█'; done
  printf '%s' "$(fg "95;95;95")"
  for ((i=f;i<w;i++)); do printf '█'; done
  printf '%s' "$(fg "$TEXT")"
}

remaining() {
  local s=$(( $1 - $(date +%s) ))
  [ "$s" -le 0 ] && { printf 'now'; return; }
  local d=$((s/86400)) h=$(( (s%86400)/3600 )) m=$(( (s%3600)/60 ))
  if [ $d -gt 0 ]; then printf '%dd%dh' $d $h
  elif [ $h -gt 0 ]; then printf '%dh%02dm' $h $m
  else printf '%dm' $m; fi
}

meter() { # pct resets_at mode(abs|time|none) barwidth countdown(1|0)
  local c w=${4:-10}; c=$(sevcolor "$1")
  [ "$w" -gt 0 ] && printf '%s ' "$(bar "$1" "$w" "$c")"
  printf '%s%.0f%%%s' "$(fg "$c")" "$1" "$(fg "$TEXT")"
  [ -n "$2" ] && [ "${5:-1}" = 1 ] && printf ' %s↻ %s%s' "$(fg "$SUB")" "$(remaining "$2")" "$(fg "$TEXT")"
  if [ -n "$2" ] && [ -n "$3" ] && [ "$3" != none ]; then
    local day=""; [ "$3" = abs ] && day="$(date -r "$2" '+%a') "
    printf ' %s· %s%s%s' "$(fg "$SUB")" "$day" "$(date -r "$2" '+%-I:%M%p' | tr 'A-Z' 'a-z')" "$(fg "$TEXT")"
  fi
}

# ---- terminal width ----
cols=""
[ -n "$TMUX" ] && cols=$(tmux display -p -t "${TMUX_PANE:-}" '#{pane_width}' 2>/dev/null)
[ -z "$cols" ] && cols=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
[ -z "$cols" ] && cols=${COLUMNS:-0}
[ -n "$SL_COLS" ] && cols=$SL_COLS   # test override
vis() { printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }

folder="${cwd##*/}"; [ -z "$folder" ] && folder="/"
pname="${proj##*/}"
br=""; dirty=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  br=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null | head -1)" ] && dirty="*"
fi

# build <level>: 0 = full ... 6 = most compact, 7 = folder only (ultra narrow)
build() {
  local L=$1 bw lab_s lab_w lab_c
  case $L in 0) bw=10;; 1) bw=8;; 2) bw=6;; 3) bw=4;; *) bw=0;; esac
  if [ "$L" -ge 3 ]; then lab_s="SES"; lab_w="WK"; lab_c='$'; else lab_s="SESSION"; lab_w="WEEK"; lab_c="COST"; fi

  local ltxt="$folder"
  [ -n "$br" ] && [ "$L" -le 6 ] && ltxt+=" $(fg "$SUB")git:${br}${dirty}$(fg "$TEXT")"
  if [ "$L" -ge 7 ]; then   # ultra narrow: folder only, truncated to fit
    local room=$(( cols - MARGIN - $(vis "$(pill "$BLUE" DIR "")") ))
    [ "$room" -lt 3 ] && room=3
    [ ${#folder} -gt "$room" ] && ltxt="${folder:0:$((room-1))}…"
  fi
  left="$(pill "$BLUE" 'DIR' "$ltxt")"
  [ "$L" -le 1 ] && [ "$pname" != "$folder" ] && left+=" $(pill "$MAUVE" 'PROJECT' "$pname")"

  right=""
  [ "$L" -ge 7 ] && return
  if [ -n "$model" ] && [ "$L" -le 4 ]; then
    local mtxt="$model"
    if [ -n "$effort" ]; then
      case $L in 0) mtxt+=" $(fg "$SUB")· ${effort} effort$(fg "$TEXT")";;
                 1|2) mtxt+=" $(fg "$SUB")· ${effort}$(fg "$TEXT")";; esac
    fi
    right+=" $(pill "$PINK" 'MODEL' "$mtxt")"
  fi
  [ -n "$ctx" ] && [ "$L" -le 5 ] && right+=" $(pill "$TEAL" 'CTX' "$(meter "$ctx" "" none "$bw")")"

  if [ -n "$h5" ] || [ -n "$d7" ]; then
    local s_mode=time w_mode=abs cd=1
    [ "$L" -ge 1 ] && cd=0
    [ "$L" -ge 2 ] && { s_mode=none; w_mode=none; }
    [ "$L" -ge 2 ] && cd=0
    if [ "$L" -le 1 ]; then s_mode=time; w_mode=abs; fi
    [ -n "$h5" ] && right+=" $(pill "$YELLOW" "$lab_s" "$(meter "$h5" "$h5r" "$s_mode" "$bw" "$cd")")"
    [ -n "$d7" ] && right+=" $(pill "$LAV" "$lab_w" "$(meter "$d7" "$d7r" "$w_mode" "$bw" "$cd")")"
  else
    [ "$L" -le 3 ] && right+=" $(pill "$SURF1" "$lab_s" "$(fg "$SUB")limits n/a yet")"
  fi
  # Cost is only an estimate. Show it when there are no plan limits (API billing), when a limit
  # is used up (extra/credit usage takes over), or when forced with STATUSLINE_SHOW_COST=1.
  show_cost=0
  if [ -z "$h5" ] && [ -z "$d7" ]; then show_cost=1; fi
  if [ "${h5%.*:-0}" -ge 100 ] 2>/dev/null || [ "${d7%.*:-0}" -ge 100 ] 2>/dev/null; then show_cost=1; fi
  [ "${STATUSLINE_SHOW_COST:-0}" = 1 ] && show_cost=1
  if [ -n "$cost" ] && [ "$show_cost" = 1 ]; then
    local ctxt
    if [ "$L" -ge 3 ]; then ctxt=$(printf '%.2f' "$cost"); else ctxt=$(printf '$%.2f' "$cost"); fi
    right+=" $(pill "$PEACH" "$lab_c" "$ctxt")"
  fi
}

# columns Claude Code reserves around the status line (its own left indent + right edge)
MARGIN=4
if [ "$cols" -le 0 ]; then
  build 0; printf '%s  %s\n' "$left" "$right"; exit 0
fi
for L in 0 1 2 3 4 5 6 7; do
  build "$L"
  lw=$(vis "$left"); rw=$(vis "$right")
  [ $(( lw + rw + 1 + MARGIN )) -le "$cols" ] && break
done
gap=$(( cols - lw - rw - MARGIN ))
[ "$gap" -lt 1 ] && gap=1
printf '%s%*s%s\n' "$left" "$gap" "" "$right"
