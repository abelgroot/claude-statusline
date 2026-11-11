#!/bin/bash
# Claude usage for the tmux status bar (Catppuccin module). Reads limits cached by statusline.sh.
#   tmux-claude.sh bars <pane_current_path>  -> prints model·effort + session/week bars (tmux style codes)

f="$HOME/.claude/.statusline-limits"
th() { tmux show -gv "@thm_$1" 2>/dev/null; }   # follow the live Catppuccin flavor
FG=$(th fg); SUB=$(th subtext_0); EMPTY=$(th overlay_0); OK=$(th green); WARN=$(th peach); BAD=$(th red)
FG=${FG:-#cdd6f4}; SUB=${SUB:-#bac2de}; EMPTY=${EMPTY:-#6c7086}; OK=${OK:-#a6e3a1}; WARN=${WARN:-#fab387}; BAD=${BAD:-#f38ba8}
col() { local p=${1%.*}; if [ "$p" -ge 85 ]; then echo "$BAD"; elif [ "$p" -ge 60 ]; then echo "$WARN"; else echo "$OK"; fi; }
seg() { # label pct width
  local p=${2%.*} w=$3 f c i; c=$(col "$p"); [ "$p" -gt 100 ] && p=100
  f=$(( (p*w+50)/100 ))
  printf '#[fg=%s]%s #[fg=%s]' "$SUB" "$1" "$c"
  for ((i=0;i<f;i++)); do printf '█'; done
  printf '#[fg=%s]' "$EMPTY"; for ((i=f;i<w;i++)); do printf '█'; done
  printf ' #[fg=%s]%s%%' "$c" "$p"
}
out=""
dir="$2"; mf="$HOME/.claude/.sl/$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
[ -f "$mf" ] || mf="$HOME/.claude/.sl/last"
if [ -f "$mf" ]; then
  IFS='|' read -r mname meff < "$mf"
  fam=${mname%% *}; ver=${mname#* }; [ "$ver" = "$mname" ] && ver=""
  case "$fam" in Opus) fam=Op;; Sonnet) fam=So;; Haiku) fam=Ha;; Fable) fam=Fa;; *) fam=${fam:0:3};; esac
  case "$meff" in low) e=L;; medium) e=M;; high) e=H;; xhigh) e=XH;; max) e=MX;; "") e="";; *) e=${meff:0:2};; esac
  out="#[fg=$FG]${fam}${ver}"
  [ -n "$e" ] && out+="#[fg=$SUB]·#[fg=$FG]${e}"
fi
if [ -f "$f" ]; then
  IFS='|' read -r h5 h5r d7 d7r < "$f"; now=$(date +%s)
  [ -n "$h5" ] && [ "${h5r:-0}" -gt "$now" ] && { [ -n "$out" ] && out+="  "; out+="$(seg S "$h5" 4)"; }
  [ -n "$d7" ] && [ "${d7r:-0}" -gt "$now" ] && { [ -n "$out" ] && out+="  "; out+="$(seg W "$d7" 4)"; }
fi
[ -z "$out" ] && out="#[fg=$SUB]limits n/a"
printf '%s#[fg=%s]' "$out" "$FG"
