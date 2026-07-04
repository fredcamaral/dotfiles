# simple-fred.zsh-theme
# Format: hostname : ~/a/b/dir (branch ✔) ↑3↓1 base↓2 ❯
# Path: fish-style collapsed parents. Arrows: ahead/behind remote. base↓N: commits added to recorded base branch.
# ❯ turns red on non-zero exit.

# Use LocalHostName (rivendell) instead of %m which resolves to the
# short DNS hostname (mac). Cache at theme-load time to avoid repeated
# subshell calls on every prompt render.
local _sf_host="${$(scutil --get LocalHostName 2>/dev/null):-$(hostname -s)}"

# Path helper: fish-style collapsed directories.
# Abbreviates parent dirs to first char (dot-dirs keep two: .config → .c),
# current directory always shown in full.  ~/repos/project/src → ~/r/p/src
function _sf_path() {
  local full="${(%):-%~}"

  # Nothing to collapse if fewer than 2 path separators
  [[ "$full" != */*/* ]] && { echo "$full"; return }

  local base="${full##*/}"   # last component – always shown in full
  local dir="${full%/*}"     # everything before last /
  local abbreviated=""
  local segment

  for segment in ${(s:/:)dir}; do
    if [[ "$segment" == "~" ]]; then
      abbreviated+="~/"
    elif [[ -n "$segment" ]]; then
      # dot-dirs: keep first two chars for readability
      if [[ "$segment" == .* && ${#segment} -gt 1 ]]; then
        abbreviated+="${segment[1,2]}/"
      else
        abbreviated+="${segment[1]}/"
      fi
    fi
  done

  # Restore leading / for absolute paths outside ~
  [[ "$full" == /* ]] && abbreviated="/${abbreviated}"

  echo "${abbreviated}${base}"
}

# Ahead/behind remote: single git call, no network, fails silently outside repos.
# Cyan ↑N = unpushed commits, red ↓N = need to pull.
function _sf_git_arrows() {
  local counts
  counts="$(command git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)" || return
  local ahead="${counts%%$'\t'*}"
  local behind="${counts##*$'\t'}"

  local arrows=""
  (( ahead > 0 ))  && arrows+="%{$fg[cyan]%}↑${ahead}"
  (( behind > 0 )) && arrows+="%{$fg[red]%}↓${behind}"

  [[ -n "$arrows" ]] && echo " ${arrows}%{$reset_color%}"
}

# Commits the recorded base branch has that the current branch does not.
function _sf_git_base_behind() {
  local branch base count
  branch="$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)" || return
  base="$(command git config --get "branch.${branch}.base" 2>/dev/null)" || return

  [[ -n "$base" ]] || return
  command git rev-parse --verify --quiet "${base}^{commit}" >/dev/null || return

  count="$(command git rev-list --count "HEAD..${base}" 2>/dev/null)" || return
  (( count > 0 )) && echo " %{$fg[red]%}base↓${count}%{$reset_color%}"
}

PROMPT='%{$fg_bold[cyan]%}${_sf_host}%{$reset_color%} %{$fg[white]%}:%{$reset_color%} %{$fg_bold[yellow]%}$(_sf_path)%{$reset_color%}$(git_prompt_info)$(_sf_git_arrows)$(_sf_git_base_behind) %(?.%{$fg[magenta]%}.%{$fg[red]%})❯%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX=" %{$fg[white]%}(%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg[white]%})%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✘%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"
