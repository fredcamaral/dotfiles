#!/bin/bash
# Claude Code status line — repo-forward, 2 lines, yellow banner.
# Reads the harness JSON on stdin; emits 2 lines.

input=$(cat)
cwd=$(echo "$input"      | jq -r '.workspace.current_dir')
model=$(echo "$input"    | jq -r '.model.display_name')
version=$(echo "$input"  | jq -r '.version')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

# --- repo identity: git toplevel basename, else cwd basename ---
repo=$(cd "$cwd" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
[ -n "$repo" ] && repo=$(basename "$repo") || repo=$(basename "$cwd")
repo_uc=$(echo "$repo" | tr '[:lower:]' '[:upper:]')

# --- branch, or @sha when detached, or no-git ---
branch=$(cd "$cwd" 2>/dev/null && git symbolic-ref -q --short HEAD 2>/dev/null)
if [ -z "$branch" ]; then
  sha=$(cd "$cwd" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null)
  [ -n "$sha" ] && branch="@$sha" || branch="no-git"
fi

# --- git working state: dirty count + ahead/behind upstream ---
dirty=$(cd "$cwd" 2>/dev/null && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
ahead=$(cd "$cwd" 2>/dev/null && git rev-list --count @{u}..HEAD 2>/dev/null)
behind=$(cd "$cwd" 2>/dev/null && git rev-list --count HEAD..@{u} 2>/dev/null)

# --- context bar ---
bar_width=20
used_int=${used_pct%.*}; [ -z "$used_int" ] && used_int=0
filled=$(( used_int * bar_width / 100 ))
[ "$filled" -gt "$bar_width" ] && filled=$bar_width
[ "$filled" -lt 0 ] && filled=0
empty=$(( bar_width - filled ))

bar=""
i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$((i+1)); done
i=0; while [ "$i" -lt "$empty" ];  do bar="${bar}░"; i=$((i+1)); done

# --- palette: bright yellow is reserved for the repo banner (single accent) ---
RESET=$'\033[0m'
DIM=$'\033[2m'
# repo banner: stable color per repo via hashed hue (HSL→RGB), fg by luminance for contrast
N=30                                              # ponytail: distinct hues; bump for more colors
hue=$(( $(cksum <<<"$repo" | cut -d' ' -f1) % N * 360 / N ))
S=70; L=55                                        # fixed vivid mid-tone; only hue varies
d=$(( 2*L - 100 )); d=${d#-}                       # |2L-100|
c=$(( (100 - d) * S / 10 ))                         # chroma           (×1000)
hm=$(( hue % 120 - 60 )); hm=${hm#-}                # |(hue mod 120)-60|
x=$(( c * (60 - hm) / 60 ))                         # 2nd component    (×1000)
m=$(( L*10 - c/2 ))                                 # lightness match  (×1000)
case $(( hue / 60 )) in
  0) r=$c; g=$x; b=0  ;; 1) r=$x; g=$c; b=0  ;; 2) r=0;  g=$c; b=$x ;;
  3) r=0;  g=$x; b=$c ;; 4) r=$x; g=0;  b=$c ;; *) r=$c; g=0;  b=$x ;;
esac
r=$(( (r+m)*255/1000 )); g=$(( (g+m)*255/1000 )); b=$(( (b+m)*255/1000 ))
lum=$(( (r*299 + g*587 + b*114) / 1000 ))           # ponytail: 145 cutoff for black/white fg
[ "$lum" -gt 145 ] && fg="0;0;0" || fg="255;255;255"
REPO=$'\033['"48;2;${r};${g};${b};38;2;${fg}m"
DIRTY=$'\033[31m'       # red — uncommitted changes
SYNC=$'\033[36m'        # cyan — ahead/behind upstream

if   [ "$used_int" -lt 50 ]; then BARC=$'\033[32m'   # green
elif [ "$used_int" -lt 80 ]; then BARC=$'\033[33m'   # yellow
else                              BARC=$'\033[31m'   # red
fi

# assemble git-state suffix (only shows what's non-zero)
state=""
[ "${dirty:-0}" -gt 0 ] 2>/dev/null && state="${state} ${DIRTY}●${dirty}${RESET}"
[ "${ahead:-0}" -gt 0 ] 2>/dev/null && state="${state} ${SYNC}↑${ahead}${RESET}"
[ "${behind:-0}" -gt 0 ] 2>/dev/null && state="${state} ${SYNC}↓${behind}${RESET}"

printf '%s\n' "${REPO} ${repo_uc} ${RESET}  ${DIM}⎇ ${branch}${RESET}${state}"
printf '%s\n' "${DIM}${model} · v${version}${RESET}"
printf '%s\n' "${DIM}ctx${RESET} ${BARC}${bar}${RESET} ${DIM}${used_pct}%${RESET}"
