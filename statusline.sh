#!/bin/bash
# Claude Code status line, Catppuccin Mocha "rounded" pills (matches tmux theme)
input=$(cat)
j() { echo "$input" | jq -r "$1 // empty" 2>/dev/null; }

cwd=$(j '.workspace.current_dir'); [ -z "$cwd" ] && cwd=$(j '.cwd')
proj=$(j '.workspace.project_dir'); [ -z "$proj" ] && proj="$cwd"
model=$(j '.model.display_name')
mid=$(j '.model.id')
cost=$(j '.cost.total_cost_usd')
effort=$(j '.effort.level // .effort_level // .effortLevel')
if [ -z "$effort" ] && [ -f "$HOME/.claude/settings.json" ]; then
  effort=$(jq -r --arg id "$mid" '
    ((.modelSettings // {}) | to_entries
      | map(select(.key as $k | $id | startswith($k))) | sort_by(.key|length) | last | .value.effortLevel)
    // .effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi
ctx=$(j '.context_window.used_percentage')
h5=$(j '.rate_limits.five_hour.used_percentage')
h5r=$(j '.rate_limits.five_hour.resets_at')
d7=$(j '.rate_limits.seven_day.used_percentage')
d7r=$(j '.rate_limits.seven_day.resets_at')

# Limits only arrive after the first API response. Cache them (account-wide) and
# reuse at session start until fresh data shows up; drop windows that already reset.
LCACHE="$HOME/.claude/.statusline-limits"
now=$(date +%s)
if [ -n "$h5" ] || [ -n "$d7" ]; then
  printf '%s|%s|%s|%s\n' "$h5" "$h5r" "$d7" "$d7r" > "$LCACHE" 2>/dev/null
elif [ -f "$LCACHE" ]; then
  IFS='|' read -r c5 c5r c7 c7r < "$LCACHE"
  [ -n "$c5" ] && [ "${c5r:-0}" -gt "$now" ] && { h5=$c5; h5r=$c5r; }
  [ -n "$c7" ] && [ "${c7r:-0}" -gt "$now" ] && { d7=$c7; d7r=$c7r; }
fi

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
[ -z "$cols" ] && cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
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

# build <level>: 0 = full ... 6 = most compact
build() {
  local L=$1 bw lab_s lab_w lab_c
  case $L in 0) bw=10;; 1) bw=8;; 2) bw=6;; 3) bw=4;; *) bw=0;; esac
  if [ "$L" -ge 3 ]; then lab_s="SES"; lab_w="WK"; lab_c='$'; else lab_s="SESSION"; lab_w="WEEK"; lab_c="COST"; fi

  local ltxt="$folder"
  [ -n "$br" ] && ltxt+=" $(fg "$SUB")git:${br}${dirty}$(fg "$TEXT")"
  left="$(pill "$BLUE" 'DIR' "$ltxt")"
  [ "$L" -le 1 ] && [ "$pname" != "$folder" ] && left+=" $(pill "$MAUVE" 'PROJECT' "$pname")"

  right=""
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
  if [ -n "$cost" ]; then
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
for L in 0 1 2 3 4 5 6; do
  build "$L"
  lw=$(vis "$left"); rw=$(vis "$right")
  [ $(( lw + rw + 1 + MARGIN )) -le "$cols" ] && break
done
gap=$(( cols - lw - rw - MARGIN ))
[ "$gap" -lt 1 ] && gap=1
printf '%s%*s%s\n' "$left" "$gap" "" "$right"
