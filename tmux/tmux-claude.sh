#!/bin/bash
# Claude usage for the tmux status bar. Reads the caches written by statusline.sh.
#   tmux-claude.sh bars <pane_current_path>
# Prints: model·effort  git:branch  S ████ 14% 2h13m  W ████ 55% 2d7h   (tmux style codes)
#
# Theme-agnostic: every color/option is read from a tmux user option (@claude_*), then from the
# Catppuccin palette (@thm_*), then from a built-in default, so it works with any theme.
#   @claude_branch  on|off   show the git branch            (default on)
#   @claude_reset   on|off   show reset countdowns          (default on)
#   @claude_bar_width N      width of the usage bars        (default 4)
#   @claude_c_fg @claude_c_sub @claude_c_empty @claude_c_ok @claude_c_warn @claude_c_bad   colors

dir="$2"
tmuxopt() { tmux show -gqv "$1" 2>/dev/null; }
pick() { # pick <claude-name> <catppuccin-name> <default>
  local v; v=$(tmuxopt "@claude_c_$1"); [ -z "$v" ] && v=$(tmuxopt "@thm_$2"); echo "${v:-$3}"
}
FG=$(pick fg fg '#cdd6f4'); SUB=$(pick sub subtext_0 '#bac2de'); EMPTY=$(pick empty overlay_0 '#6c7086')
OK=$(pick ok green '#a6e3a1'); WARN=$(pick warn peach '#fab387'); BAD=$(pick bad red '#f38ba8')
SHOW_BRANCH=$(tmuxopt @claude_branch); SHOW_RESET=$(tmuxopt @claude_reset); BW=$(tmuxopt @claude_bar_width)
SHOW_BRANCH=${SHOW_BRANCH:-on}; SHOW_RESET=${SHOW_RESET:-on}; BW=${BW:-4}

col() { local p=${1%.*}; if [ "$p" -ge 85 ]; then echo "$BAD"; elif [ "$p" -ge 60 ]; then echo "$WARN"; else echo "$OK"; fi; }
remaining() { # epoch -> 2d7h / 2h13m / 14m
  local s=$(( $1 - $(date +%s) )); [ "$s" -le 0 ] && { printf 'now'; return; }
  local d=$((s/86400)) h=$(( (s%86400)/3600 )) m=$(( (s%3600)/60 ))
  if [ $d -gt 0 ]; then printf '%dd%dh' $d $h; elif [ $h -gt 0 ]; then printf '%dh%02dm' $h $m; else printf '%dm' $m; fi
}
seg() { # label pct resets_at
  local p=${2%.*} f c i; c=$(col "$p"); [ "$p" -gt 100 ] && p=100
  f=$(( (p*BW+50)/100 ))
  printf '#[fg=%s]%s #[fg=%s]' "$SUB" "$1" "$c"
  for ((i=0;i<f;i++)); do printf '█'; done
  printf '#[fg=%s]' "$EMPTY"; for ((i=f;i<BW;i++)); do printf '█'; done
  printf ' #[fg=%s]%s%%' "$c" "$p"
  [ "$SHOW_RESET" = on ] && [ -n "$3" ] && printf ' #[fg=%s]%s' "$SUB" "$(remaining "$3")"
}

out=""; add() { [ -n "$out" ] && out+="  "; out+="$1"; }

# model + effort (per working dir; no cross-session fallback, so it is never the wrong session's model)
mf="$HOME/.claude/.sl/$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
if [ -f "$mf" ]; then
  IFS='|' read -r mname meff < "$mf"
  fam=${mname%% *}; ver=${mname#* }; [ "$ver" = "$mname" ] && ver=""
  case "$fam" in Opus) fam=Op;; Sonnet) fam=So;; Haiku) fam=Ha;; Fable) fam=Fa;; *) fam=${fam:0:3};; esac
  case "$meff" in low) e=L;; medium) e=M;; high) e=H;; xhigh) e=XH;; max) e=MX;; "") e="";; *) e=${meff:0:2};; esac
  m="#[fg=$FG]${fam}${ver}"; [ -n "$e" ] && m+="#[fg=$SUB]·#[fg=$FG]${e}"
  add "$m"
fi

# git branch of the pane's folder
if [ "$SHOW_BRANCH" = on ] && [ -n "$dir" ]; then
  br=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$br" ]; then
    [ ${#br} -gt 18 ] && br="${br:0:17}…"
    add "#[fg=$SUB]git:#[fg=$FG]${br}"
  fi
fi

# usage limits (account-wide cache, merged by statusline.sh)
f="$HOME/.claude/.statusline-limits"
if [ -f "$f" ]; then
  IFS='|' read -r h5 h5r d7 d7r < "$f"; now=$(date +%s)
  [ -n "$h5" ] && [ "${h5r:-0}" -gt "$now" ] && add "$(seg S "$h5" "$h5r")"
  [ -n "$d7" ] && [ "${d7r:-0}" -gt "$now" ] && add "$(seg W "$d7" "$d7r")"
fi

[ -z "$out" ] && out="#[fg=$SUB]waiting for Claude…"
printf '%s#[fg=%s]' "$out" "$FG"
