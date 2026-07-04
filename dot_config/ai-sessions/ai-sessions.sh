#!/usr/bin/env zsh
# ai-sessions: tmux launcher + pipe-pane logging for Claude Code / OpenCode / Codex / Droid / pi.
# Sourced from ~/.zshrc (after ~/.config/zsh/*.zsh). Self-contained: owns spawn naming,
# launching (agents are born as windows of the shared `isengard` session), logging,
# and the `ais` status picker.
#
# Source of truth for "what happened":
#   1. tmux session persistence (session keeps running on detach)
#   2. tmux scrollback (history-limit 100000, copy mode via prefix [)
#   3. Tool-native history (claude --continue/--resume, opencode sessions)
#   4. tmux pipe-pane byte stream in $AI_LOGS_DIR (forensic only)
# Logs are raw byte streams piped off the pane; TUI redraws fill them with escape
# sequences. Read with `less -R`. Log filename == the stamped spawn name + ".log";
# each agent pane carries its path in the @ai_log pane option.
#
# Public surface:
#   ai-claude / ai-opencode / ai-codex / ai-droid / ai-pi   launchers
#   ais (ai-status)   interactive table: enter attach · ^d cd · ^k kill · ^l log · ^r refresh
#   ai-attach / ai-cd / ai-kill [filter]            picker-based helpers
#   ai-go [filter]    Termius/phone entry: ail 1 + picker + attach
#   ai-new            spawn picker: agent → repo → launcher (tmux M-n popup)
#   ai-adopt          one-shot: move legacy per-agent sessions into isengard
#   ai-logs / ai-log-latest / ai-log-clean          log helpers

typeset -g AI_SESSIONS_FILE="${(%):-%N}"
typeset -g AI_SESSIONS_DIR="${AI_SESSIONS_DIR:-$HOME/ai-sessions}"
typeset -g AI_LOGS_DIR="$AI_SESSIONS_DIR/logs"
[[ -d "$AI_LOGS_DIR" ]] || mkdir -p "$AI_LOGS_DIR"

# ---- tmux seam ----

# Every tmux call in the launcher routes through here. AIL_SOCKET (optional)
# targets `tmux -L $AIL_SOCKET` — the test-isolation seam shared with ail
# (ai-run-smoke uses it); unset = default server. (${=...} forces word-
# splitting: zsh does not split unquoted expansions, and "-L airunsmoke"
# must be two argv words.)
_ai_tmux() { command tmux ${=AIL_SOCKET:+-L $AIL_SOCKET} "$@" }

# ---- naming ----

# _ai_repo_branch — print "repo branch" (branch may be empty), lowercased and
# sanitized to [a-z0-9_-]. Shared extraction for the two names below.
_ai_repo_branch() {
  local root repo branch
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$root" ]]; then
    repo="${root:t}"
    branch=$(git -C "$root" branch --show-current 2>/dev/null)
  else
    repo="${PWD:t}"
    branch=""
  fi
  repo="${repo:l}"; repo="${repo//[^a-z0-9_-]/-}"
  branch="${branch:l}"; branch="${branch//[^a-z0-9_-]/-}"
  print -r -- "$repo" "$branch"
}

# <prefix>-<repo>[-<branch>]-<MMDD>-<HHMMSS>-<PID>-<RANDOM>
# The 4 trailing dash-segments are the stamp; everything before is the "base".
# Survives only as the log filename (and _ai_run's transient window name).
_ai_session_name() {
  # $2 (optional): caller-supplied entropy. $RANDOM evaluated here runs in a
  # command-substitution subshell, which never advances the parent's RNG —
  # every call from one shell would yield the SAME number, so same-second
  # spawns would share a log file. Callers pass $RANDOM from their own context.
  local prefix="$1" repo branch base
  read -r repo branch <<< "$(_ai_repo_branch)"
  base="${prefix}-${repo}"
  [[ -n "$branch" ]] && base="${base}-${branch}"
  printf '%s-%s-%s-%s\n' "$base" "$(date +%m%d-%H%M%S)" "$$" "${2:-$RANDOM}"
}

# <prefix>:<repo>[/<branch>] — the display identity inside isengard: pane
# title + window name. Duplicates are allowed (two cc agents on one
# repo/branch); tab index and pane position disambiguate.
_ai_short_name() {
  local prefix="$1" repo branch short
  read -r repo branch <<< "$(_ai_repo_branch)"
  short="${prefix}:${repo}"
  [[ -n "$branch" ]] && short="${short}/${branch}"
  print -r -- "$short"
}

# ---- launcher ----

# Run an agent as a new window (one pane) of the shared `isengard` session,
# with pipe-pane byte-stream logging. Args: prefix agent-cmd agent-args...
# Outside tmux: spawn + attach. Inside tmux: spawn + switch-client (still logged).
_ai_run() {
  local prefix="$1"; shift

  if ! command -v tmux >/dev/null 2>&1; then
    echo "ai-sessions: tmux unavailable; running without logging" >&2
    command "$@"
    return $?
  fi
  # Non-interactive (piped/redirected): run direct, no tmux, no logging.
  if [[ ! -t 0 || ! -t 1 ]]; then
    command "$@"
    return $?
  fi

  mkdir -p "$AI_LOGS_DIR" 2>/dev/null

  local stamped short logfile rnd
  # Materialize $RANDOM via plain assignment BEFORE the command substitution:
  # $(...) forks first and expands its whole command line inside the fork, so
  # `$(f $RANDOM)` reads the RNG in the subshell and never advances the parent.
  rnd=$RANDOM
  stamped=$(_ai_session_name "$prefix" "$rnd")
  short=$(_ai_short_name "$prefix")
  logfile="$AI_LOGS_DIR/${stamped}.log"

  # Shell-quote the agent argv into a single string for tmux, which feeds
  # the command to /bin/sh -c. Without this, args with spaces/quotes corrupt.
  local cmd_quoted="" arg
  for arg in "$@"; do
    cmd_quoted+="${(q)arg} "
  done

  # Spawn + tag + wire logging in a single server round-trip, so pipe-pane
  # catches the agent's output from the first byte (a second client call would
  # race the agent's first writes). The window is born under the unique
  # stamped name purely as a target handle for the chain — short names can
  # collide — and is renamed to $short at the end. allow-rename off +
  # automatic-rename off pin the tab name: agent TUIs must not clobber it
  # (defense-in-depth — the global conf also sets allow-rename off, but the
  # pin must not depend on it). allow-set-title off pins the pane
  # title the same way — the title is the identity ail renders on deck borders
  # and copies into mode-1 tab names, and agent TUIs emit OSC 0/2 constantly.
  local target="=isengard:=${stamped}" pane
  local -a tag
  tag=(
    \; set-option -p -t "$target" @ai_agent "$prefix"
    \; set-option -p -t "$target" @ai_log "$logfile"
    \; pipe-pane -o -t "$target" "cat >> ${(q)logfile}"
    \; select-pane -t "$target" -T "$short"
    \; set-option -p -t "$target" allow-set-title off
    \; set-option -w -t "$target" allow-rename off
    \; set-option -w -t "$target" automatic-rename off
    \; rename-window -t "$target" "$short"
  )
  if _ai_tmux has-session -t "=isengard" 2>/dev/null; then
    pane=$(_ai_tmux new-window -t "=isengard:" -n "$stamped" -c "$PWD" \
             -PF '#{pane_id}' "$cmd_quoted" "${tag[@]}") || return $?
  else
    pane=$(_ai_tmux new-session -d -s isengard -n "$stamped" -c "$PWD" \
             -PF '#{pane_id}' "$cmd_quoted" "${tag[@]}") || return $?
  fi

  echo "ai-sessions: isengard window '$short' ($pane) → ${logfile/#$HOME/~}" >&2

  # Auto-pack: honor the session's declared mode. ail skips already-formed
  # decks, so this just slots the newborn into the last one; the newborn is
  # the active pane, so ail's focus-restore lands on it. Layout is cosmetic —
  # a failed pack must not fail the spawn. Absolute path: same binary the tmux
  # run-shell binds call. AIL_SOCKET is passed through explicitly: it may be a
  # non-exported shell var, and ail must hit the same server.
  # NB: show-options takes a target-PANE — exact-match needs "=isengard:"
  # (trailing colon); bare "=isengard" fails with "no such session".
  local mode
  mode=$(_ai_tmux show-options -v -t "=isengard:" @ai_mode 2>/dev/null)
  if [[ "$mode" == <-> ]] && (( mode > 1 )); then
    AIL_SOCKET="$AIL_SOCKET" "$HOME/.local/bin/ail" "$mode" >/dev/null 2>&1 || true
  fi

  if [[ -n "$TMUX" ]]; then
    # switch-client needs a client; a detached spawn (no client attached)
    # must not hard-fail — the agent is up and logged either way.
    _ai_tmux switch-client -t "=isengard" 2>/dev/null || true
  else
    _ai_tmux attach -t "=isengard"
  fi
}

# ---- public launchers ----

ai-claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "ai-claude: claude binary not found in PATH" >&2; return 127
  fi
  _ai_run cc claude --dangerously-skip-permissions "$@"
}

ai-opencode() {
  if ! command -v opencode >/dev/null 2>&1; then
    echo "ai-opencode: opencode binary not found in PATH" >&2
    echo "  install via: curl -fsSL https://opencode.ai/install | bash" >&2
    return 127
  fi
  _ai_run oc opencode "$@"
}

ai-codex() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "ai-codex: codex binary not found in PATH" >&2; return 127
  fi
  _ai_run cx codex --dangerously-bypass-approvals-and-sandbox "$@"
}

ai-droid() {
  if ! command -v droid >/dev/null 2>&1; then
    echo "ai-droid: droid binary not found in PATH" >&2; return 127
  fi
  _ai_run dr droid "$@"
}

ai-pi() {
  if ! command -v pi >/dev/null 2>&1; then
    echo "ai-pi: pi binary not found in PATH" >&2; return 127
  fi
  _ai_run pi pi "$@"
}

# ---- migration ----

# ai-adopt — one-shot: move every legacy per-agent session (cc-*/oc-*/cx-*/
# dr-*/pi-*) into isengard as tagged panes. Idempotent: a second run finds
# nothing. Panes are tagged BEFORE moving (pane options travel with the pane).
# Agent heuristic: the FIRST pane of the FIRST window is the agent — that is
# how legacy _ai_run birthed sessions; extra panes/windows move along
# untagged (non-agent — ail never touches them). pipe-pane is NOT re-wired:
# legacy panes already pipe to their log and the pipe survives the move.
ai-adopt() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "ai-adopt: tmux not installed" >&2; return 1
  fi

  local -a legacy
  local line
  while IFS= read -r line; do
    [[ "$line" =~ '^(cc|oc|cx|dr|pi)-' ]] && legacy+=("$line")
  done < <(_ai_tmux list-sessions -F '#{session_name}|#{session_created}|#{session_path}' 2>/dev/null)
  if (( ${#legacy} == 0 )); then
    echo "ai-adopt: nothing to adopt"
    return 0
  fi

  # Bootstrap: no isengard → RENAME the first legacy session into it. This
  # preserves any attached client and leaves no junk shell window behind (a
  # new-session bootstrap would). The renamed session still needs tagging —
  # it stays in the loop below, minus the move.
  local renamed=""
  if ! _ai_tmux has-session -t "=isengard" 2>/dev/null; then
    renamed="${legacy[1]%%|*}"
    _ai_tmux rename-session -t "=$renamed" isengard || return 1
  fi

  # Client-last: if the attached client sits on a legacy session, park it on
  # isengard now and process its old session last — the client must never
  # watch its own session dissolve mid-loop.
  local client_sess=""
  [[ -n "$TMUX" ]] && client_sess=$(_ai_tmux display-message -p '#{session_name}' 2>/dev/null)
  if [[ -n "$client_sess" && "$client_sess" != "$renamed" && \
        "$client_sess" =~ '^(cc|oc|cx|dr|pi)-' ]]; then
    _ai_tmux switch-client -t "=isengard" 2>/dev/null || true
    local -a reordered
    for line in "${legacy[@]}"; do
      [[ "${line%%|*}" == "$client_sess" ]] || reordered+=("$line")
    done
    for line in "${legacy[@]}"; do
      [[ "${line%%|*}" == "$client_sess" ]] && reordered+=("$line")
    done
    legacy=("${reordered[@]}")
  fi

  local -i adopted=0 skipped=0
  local name created spath prefix src short logfile first_win agent_pane win
  local -a wins
  for line in "${legacy[@]}"; do
    name="${line%%|*}"; line="${line#*|}"
    created="${line%%|*}"
    spath="${line#*|}"
    prefix="${name%%-*}"
    if [[ "$name" == "$renamed" ]]; then src="=isengard"; else src="=$name"; fi

    first_win=$(_ai_tmux list-windows -t "$src" -F '#{window_id}' 2>/dev/null | head -n1)
    agent_pane=$(_ai_tmux list-panes -t "$first_win" -F '#{pane_id}' 2>/dev/null | head -n1)
    if [[ -z "$first_win" || -z "$agent_pane" ]]; then
      (( ++skipped )); continue
    fi

    # Display identity from LIVE git state at the session's path — beats
    # parsing the sanitized session name; de-stamped base as the fallback
    # when the directory is gone.
    short=""
    [[ -d "$spath" ]] && short=$(cd "$spath" 2>/dev/null && _ai_short_name "$prefix")
    [[ -z "$short" ]] && short="${prefix}:${${name%-*-*-*-*}#${prefix}-}"

    _ai_tmux set-option -p -t "$agent_pane" @ai_agent "$prefix"
    logfile=$(_ai_find_log "$name" "$created") && \
      _ai_tmux set-option -p -t "$agent_pane" @ai_log "$logfile"
    _ai_tmux select-pane -t "$agent_pane" -T "$short"
    _ai_tmux set-option -p -t "$agent_pane" allow-set-title off
    _ai_tmux set-option -w -t "$first_win" allow-rename off
    _ai_tmux set-option -w -t "$first_win" automatic-rename off
    _ai_tmux rename-window -t "$first_win" "$short"

    if [[ "$name" != "$renamed" ]]; then
      # Move every window (index order, appended after isengard's last); the
      # legacy session dies naturally when its last window leaves.
      wins=("${(@f)$(_ai_tmux list-windows -t "$src" -F '#{window_id}' 2>/dev/null)}")
      for win in "${wins[@]}"; do
        [[ -z "$win" ]] && continue
        _ai_tmux move-window -a -s "$win" -t '=isengard:{end}' 2>/dev/null
      done
    fi
    (( ++adopted ))
  done

  # Same auto-pack as _ai_run: honor the declared mode; layout is cosmetic —
  # a failed pack must not fail the adopt.
  local mode
  mode=$(_ai_tmux show-options -v -t "=isengard:" @ai_mode 2>/dev/null)
  if [[ "$mode" == <-> ]] && (( mode > 1 )); then
    AIL_SOCKET="$AIL_SOCKET" "$HOME/.local/bin/ail" "$mode" >/dev/null 2>&1 || true
  fi

  echo "ai-adopt: adopted $adopted session(s), skipped $skipped"
}

# ---- pickers ----

# _ai_pick_pane [filter] — shared picker for ai-attach/ai-cd/ai-kill over the
# agent panes of isengard. Agent-name filters (claude|cc|…) match @ai_agent;
# anything else is a substring on pane_title + pane_current_path.
# Stdout: chosen pane_id. Return non-zero on no-match or fzf cancel.
# Honors $AI_PICK_PROMPT (default "ai-pick> ").
_ai_pick_pane() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "_ai_pick_pane: tmux not installed" >&2; return 1
  fi
  local filter="$1" prefix="" rows
  case "$filter" in
    claude|cc)   prefix=cc ;;
    opencode|oc) prefix=oc ;;
    codex|cx)    prefix=cx ;;
    droid|dr)    prefix=dr ;;
    pi)          prefix=pi ;;
  esac
  rows=$(_ai_tmux list-panes -s -t "=isengard" -f '#{@ai_agent}' \
           -F $'#{pane_id}\t#{@ai_agent}\t#{pane_title}\t#{pane_current_path}' 2>/dev/null)
  if [[ -n "$prefix" ]]; then
    rows=$(printf '%s\n' "$rows" | awk -F'\t' -v p="$prefix" '$2 == p')
  elif [[ -n "$filter" ]]; then
    rows=$(printf '%s\n' "$rows" | awk -F'\t' -v f="$filter" 'index($3 $4, f)')
  fi
  if [[ -z "$rows" ]]; then
    echo "_ai_pick_pane: no agent panes matching '${filter:-*}'" >&2
    return 1
  fi
  local count target prompt="${AI_PICK_PROMPT:-ai-pick> }"
  count=$(printf '%s\n' "$rows" | wc -l | tr -d ' ')
  if [[ "$count" -eq 1 ]]; then
    target="$rows"
  elif command -v fzf >/dev/null 2>&1; then
    # --with-shell: zsh would apply equals-expansion inside bound commands;
    # not needed here (no binds), kept off. Display fields 2-4, act on 1.
    target=$(printf '%s\n' "$rows" | fzf --prompt="$prompt" --height=40% --reverse \
               --delimiter=$'\t' --with-nth=2,3,4)
  else
    echo "_ai_pick_pane: multiple panes, install fzf or pass a more specific filter:" >&2
    printf '  %s\n' ${(f)rows} >&2
    return 1
  fi
  [[ -z "$target" ]] && return 1
  printf '%s\n' "${target%%$'\t'*}"
}

# _ai_goto_session <name> — attach (or switch-client when inside tmux); chdir after.
# Captures session_path BEFORE attaching: the session may die on agent exit.
# Survives only for the plain-session rows of `ais --all`; agent navigation
# is pane-based (isengard + select-window/select-pane).
_ai_goto_session() {
  # NB: "path" is OFF-LIMITS as a variable name — zsh ties it to PATH; assigning
  # it clobbers command lookup for the rest of the function.
  local target="$1" dest
  # NB: display-message takes a target-PANE: exact-match needs "=name:" (trailing
  # colon); bare "=name" silently returns empty. attach/switch/kill/has-session
  # take a target-SESSION and accept bare "=name".
  dest=$(tmux display-message -p -t "=${target}:" -F '#{session_path}' 2>/dev/null)
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "=$target"
    return $?
  fi
  tmux attach -t "=$target"
  if [[ -n "$dest" && -d "$dest" ]]; then
    cd "$dest"
  fi
}

# ai-attach [claude|opencode|codex|droid|<substring>] — focus an agent pane.
ai-attach() {
  local target
  target=$(AI_PICK_PROMPT="ai-attach> " _ai_pick_pane "$1") || return $?
  _ai_tmux select-window -t "$target" 2>/dev/null
  _ai_tmux select-pane -t "$target" 2>/dev/null
  if [[ -n "$TMUX" ]]; then
    _ai_tmux switch-client -t "=isengard" 2>/dev/null || true
  else
    _ai_tmux attach -t "=isengard"
  fi
}

# ai-go [filter] — phone/Termius entry point: pack mode 1 (one agent per
# window), pick an agent, land on it full-screen. Meant as the Termius
# host's startup command (`zsh -ic ai-go`); harmless anywhere else.
ai-go() {
  "$HOME/.local/bin/ail" 1 >/dev/null 2>&1
  AI_PICK_PROMPT="ai-go> " ai-attach "$@"
}

# ai-new — spawn picker: fzf step 1 agent, step 2 repo (dirs containing .git
# under ~/repos, depth ≤3), then cd + launcher. Bound to tmux M-n as a popup
# (`zsh -ic ai-new`); works from any plain shell too — the launcher handles
# inside/outside-tmux both ways. Esc at either step aborts cleanly.
ai-new() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "ai-new: fzf not installed" >&2; return 127
  fi
  local agent repo
  agent=$(print -rl -- claude opencode codex droid pi \
          | fzf --prompt='agent> ' --height=40% --reverse --no-multi) || return 0
  [[ -z "$agent" ]] && return 0
  # Repo = any dir holding .git (dir or file — worktrees use a .git file),
  # up to 3 levels below ~/repos; -prune keeps find out of .git internals.
  repo=$(find "$HOME/repos" -mindepth 2 -maxdepth 4 -name .git -prune 2>/dev/null \
         | sed 's|/\.git$||' | sort \
         | fzf --prompt='repo> ' --height=90% --reverse --no-multi) || return 0
  [[ -z "$repo" ]] && return 0
  cd "$repo" || return 1
  "ai-${agent}"
}

# ai-cd [filter] — chdir to the agent pane's cwd without attaching.
ai-cd() {
  local target dest
  target=$(AI_PICK_PROMPT="ai-cd> " _ai_pick_pane "$1") || return $?
  dest=$(_ai_tmux display-message -p -t "$target" -F '#{pane_current_path}' 2>/dev/null)
  if [[ -n "$dest" && -d "$dest" ]]; then
    cd "$dest"
    echo "ai-cd: → $dest" >&2
  else
    echo "ai-cd: pane path unavailable" >&2
    return 1
  fi
}

# ai-kill [filter] — pick an agent pane and kill it (with confirm).
ai-kill() {
  local target title reply
  target=$(AI_PICK_PROMPT="ai-kill> " _ai_pick_pane "$1") || return $?
  title=$(_ai_tmux display-message -p -t "$target" -F '#{pane_title}' 2>/dev/null)
  read -q "reply?ai-kill: kill pane $target (${title:-?})? [y/N] " || { echo; return 0 }
  echo
  _ai_tmux kill-pane -t "$target" && echo "ai-kill: killed $target (${title:-?})" >&2
}

# ---- logs ----

# _ai_find_log <name> <created> — resolve the log for a stamped spawn name:
# exact <name>.log (new scheme), else the legacy closest-mtime heuristic —
# candidates share the name's base (the 4 trailing stamp segments stripped);
# pick the one whose mtime sits nearest <created>, ties → newer mtime.
# Prints the path; returns 1 when nothing matches. One implementation:
# ai-adopt tags @ai_log with it; _ai_status_rows reads @ai_log off the pane.
_ai_find_log() {
  setopt local_options null_glob
  local name="$1" created="${2:-0}" base best best_diff best_mtime cand cand_mtime diff
  local -a candidates
  if [[ -f "$AI_LOGS_DIR/${name}.log" ]]; then
    print -r -- "$AI_LOGS_DIR/${name}.log"
    return 0
  fi
  base="${name%-*-*-*-*}"
  candidates=("$AI_LOGS_DIR"/${base}-*.log)
  (( ${#candidates} == 0 )) && return 1
  best=""; best_diff=0; best_mtime=0
  for cand in "${candidates[@]}"; do
    cand_mtime=$(stat -f %m "$cand" 2>/dev/null) || continue
    diff=$(( cand_mtime - created ))
    (( diff < 0 )) && diff=$(( -diff ))
    if [[ -z "$best" ]] || (( diff < best_diff )) || { (( diff == best_diff )) && (( cand_mtime > best_mtime )); }; then
      best="$cand"; best_diff="$diff"; best_mtime="$cand_mtime"
    fi
  done
  [[ -z "$best" ]] && return 1
  print -r -- "$best"
}

# ai-logs [N] — list N most-recent logs (default 20)
ai-logs() {
  local n="${1:-20}"
  if [[ ! -d "$AI_LOGS_DIR" ]] || [[ -z "$(ls -A "$AI_LOGS_DIR" 2>/dev/null)" ]]; then
    echo "ai-logs: no logs in $AI_LOGS_DIR" >&2; return 1
  fi
  ls -lhtT "$AI_LOGS_DIR" 2>/dev/null | head -n $((n + 1))
}

# ai-log-latest [N] — open the N-th most-recent log in less (1 = newest)
ai-log-latest() {
  setopt local_options null_glob
  local n="${1:-1}" target
  local logs=("$AI_LOGS_DIR"/*.log(.om))
  if (( ${#logs} == 0 )); then
    echo "ai-log-latest: no logs in $AI_LOGS_DIR" >&2; return 1
  fi
  target="${logs[$n]}"
  if [[ -z "$target" ]]; then
    echo "ai-log-latest: no log at position $n (have ${#logs})" >&2; return 1
  fi
  echo "→ $target" >&2
  less -R "$target"
}

# ai-log-clean [DAYS] — remove logs older than DAYS (default 30)
ai-log-clean() {
  local days="${1:-30}"
  if [[ ! -d "$AI_LOGS_DIR" ]]; then
    echo "ai-log-clean: $AI_LOGS_DIR missing" >&2; return 1
  fi
  find "$AI_LOGS_DIR" -type f -name '*.log' -mtime "+${days}" -print -delete
}

# ---- formatting helpers ----

# Humanize a duration in seconds to compact form: Ns / Nm / NhMm / Nd.
_ai_humantime() {
  local s="$1"
  if (( s < 60 )); then
    printf '%ds' "$s"
  elif (( s < 3600 )); then
    printf '%dm' $(( s / 60 ))
  elif (( s < 86400 )); then
    printf '%dh%dm' $(( s / 3600 )) $(( (s % 3600) / 60 ))
  else
    printf '%dd' $(( s / 86400 ))
  fi
}

# Humanize byte size to K/M/G with one decimal.
_ai_humansize() {
  local b="$1"
  if (( b < 1024 )); then
    printf '%dB' "$b"
  elif (( b < 1048576 )); then
    awk -v b="$b" 'BEGIN { printf "%.1fK", b/1024 }'
  elif (( b < 1073741824 )); then
    awk -v b="$b" 'BEGIN { printf "%.1fM", b/1048576 }'
  else
    awk -v b="$b" 'BEGIN { printf "%.1fG", b/1073741824 }'
  fi
}

# _ai_pad <width> <text> — truncate with ellipsis (keeping a 2-space gap) and pad.
# Manual padding: printf %-*s pads by bytes, which breaks on multibyte "…".
_ai_pad() {
  local w="$1" s="$2"
  if (( ${#s} > w - 2 )); then
    s="${s[1,w-3]}…"
  fi
  printf '%s%*s' "$s" $(( w - ${#s} )) ''
}

# _ai_status_widths — compute "repo_w branch_w" from the available terminal width.
# Inside fzf reloads, FZF_COLUMNS is exported; interactively, zsh sets COLUMNS.
_ai_status_widths() {
  local cols
  cols="${FZF_COLUMNS:-${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}}"
  (( cols < 80 )) && cols=80
  # fixed: agent 10 + age 7 + write 8 + size 7 + st 1 + fzf chrome (gutter/border/scrollbar) ~8
  local flex=$(( cols - 41 ))
  local repo_w=$(( flex * 55 / 100 ))
  local branch_w=$(( flex - repo_w ))
  (( repo_w < 24 ))   && repo_w=24
  (( branch_w < 16 )) && branch_w=16
  # Cap so the numeric columns hug the content on very wide terminals.
  (( repo_w > 40 ))   && repo_w=40
  (( branch_w > 32 )) && branch_w=32
  printf '%d %d\n' "$repo_w" "$branch_w"
}

_ai_agent_label() {
  case "$1" in
    cc) print -rn -- "claude" ;;
    oc) print -rn -- "opencode" ;;
    cx) print -rn -- "codex" ;;
    dr) print -rn -- "droid" ;;
    pi) print -rn -- "pi" ;;
    *)  print -rn -- "$1" ;;
  esac
}

_ai_agent_color() {
  case "$1" in
    cc) print -rn -- $'\033[38;2;255;184;108m' ;;  # dracula orange
    oc) print -rn -- $'\033[38;2;80;250;123m'  ;;  # dracula green
    cx) print -rn -- $'\033[38;2;139;233;253m' ;;  # dracula cyan
    dr) print -rn -- $'\033[38;2;255;121;198m' ;;  # dracula pink
    pi) print -rn -- $'\033[38;2;241;250;140m' ;;  # dracula yellow
    *)  print -rn -- $'\033[0m' ;;
  esac
}

# ---- status table ----

# _ai_status_rows [plain] [all] — emit TAB-delimited rows, one per agent PANE:
#   field 1: pane_id (hidden, used for actions; session_name on plain rows)
#   field 2: @ai_log path or "-" (hidden, used for ^l)
#   field 3: formatted display row (ANSI-colored unless "plain")
# Agent rows come from isengard's tagged panes; repo/branch are live from
# pane_current_path; AGE = log birthtime, WRITE = log mtime, SIZE = log size
# (all "-" when the pane carries no log). ST ● marks the FOCUSED pane —
# session_attached is global now that every agent shares isengard.
# "all" adds plain tmux sessions (minus isengard) for hopping: the REPO column
# shows the session NAME, BRANCH the repo dir, WRITE last activity, SIZE the
# window count, ST attached.
# Sorted: most recent first (log mtime / activity).
# Return 1 if tmux missing, 2 if no matching rows.
_ai_status_rows() {
  if ! command -v tmux >/dev/null 2>&1; then
    return 1
  fi
  setopt local_options null_glob
  local color_on=1 scope_all=0 arg
  for arg in "$@"; do
    case "$arg" in
      plain) color_on=0 ;;
      all)   scope_all=1 ;;
    esac
  done

  local c_reset=$'\033[0m'
  local c_dim=$'\033[38;2;98;114;164m'    # dracula comment
  local c_green=$'\033[38;2;80;250;123m'

  local repo_w branch_w
  read -r repo_w branch_w <<< "$(_ai_status_widths)"

  local now; now=$(date +%s)
  local -a rows
  local raw line pid prefix logfile ppath active wactivity repo branch root
  local logbirth logmtime logsize age_h write_h size_h att_h sort_key
  local label color formatted repo_p branch_p

  # ---- agent panes ----
  raw=$(_ai_tmux list-panes -s -t "=isengard" -f '#{@ai_agent}' \
          -F '#{pane_id}|#{@ai_agent}|#{@ai_log}|#{pane_current_path}|#{?#{&&:#{pane_active},#{window_active}},1,0}|#{window_activity}' 2>/dev/null)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pid="${line%%|*}";       line="${line#*|}"
    prefix="${line%%|*}";    line="${line#*|}"
    logfile="${line%%|*}";   line="${line#*|}"
    ppath="${line%%|*}";     line="${line#*|}"
    active="${line%%|*}"
    wactivity="${line#*|}"

    if [[ -d "$ppath" ]]; then
      root=$(git -C "$ppath" rev-parse --show-toplevel 2>/dev/null)
      if [[ -n "$root" ]]; then
        repo="${root:t}"
        branch=$(git -C "$ppath" branch --show-current 2>/dev/null)
        [[ -z "$branch" ]] && branch="?"
      else
        repo="${ppath:t}"; branch="-"
      fi
    else
      repo="?"; branch="?"
    fi

    # @ai_log is authoritative (set by _ai_run / ai-adopt); a deleted or
    # never-found log renders as "-" columns.
    logbirth=0; logmtime=0; logsize=0
    if [[ -n "$logfile" && -f "$logfile" ]]; then
      logbirth=$(stat -f %B "$logfile" 2>/dev/null || echo 0)
      logmtime=$(stat -f %m "$logfile" 2>/dev/null || echo 0)
      logsize=$(stat -f %z "$logfile" 2>/dev/null || echo 0)
      age_h=$(_ai_humantime $(( now - logbirth )))
      write_h=$(_ai_humantime $(( now - logmtime )))
      size_h=$(_ai_humansize "$logsize")
      sort_key="$logmtime"
    else
      logfile=""
      age_h="-"; write_h="-"; size_h="-"
      sort_key="$wactivity"
    fi

    label=$(_ai_agent_label "$prefix")
    repo_p=$(_ai_pad "$repo_w" "$repo")
    branch_p=$(_ai_pad "$branch_w" "$branch")

    if (( color_on )); then
      color=$(_ai_agent_color "$prefix")
      if (( active )); then att_h="${c_green}●${c_reset}"; else att_h="${c_dim}○${c_reset}"; fi
      formatted="${color}${(r:10:)label}${c_reset}${repo_p}${c_dim}${branch_p}${c_reset}${(r:7:)age_h}${(r:8:)write_h}${(r:7:)size_h}${att_h}"
    else
      if (( active )); then att_h="*"; else att_h=""; fi
      formatted="${(r:10:)label}${repo_p}${branch_p}${(r:7:)age_h}${(r:8:)write_h}${(r:7:)size_h}${att_h}"
    fi

    rows+=("${sort_key}|${pid#%}|${pid}|${logfile:--}|${formatted}")
  done <<< "$raw"

  # ---- plain sessions (--all): everything except isengard itself ----
  if (( scope_all )); then
    local name created spath attached activity windows where
    raw=$(_ai_tmux list-sessions -F '#{session_name}|#{session_created}|#{session_path}|#{session_attached}|#{session_activity}|#{session_windows}' 2>/dev/null)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      name="${line%%|*}"; line="${line#*|}"
      created="${line%%|*}"; line="${line#*|}"
      spath="${line%%|*}"; line="${line#*|}"
      attached="${line%%|*}"; line="${line#*|}"
      activity="${line%%|*}"; line="${line#*|}"
      windows="$line"
      [[ "$name" == "isengard" ]] && continue

      if [[ -d "$spath" ]]; then
        root=$(git -C "$spath" rev-parse --show-toplevel 2>/dev/null)
        if [[ -n "$root" ]]; then
          repo="${root:t}"
          branch=$(git -C "$spath" branch --show-current 2>/dev/null)
          [[ -z "$branch" ]] && branch="?"
        else
          repo="${spath:t}"; branch="-"
        fi
      else
        repo="?"; branch="?"
      fi

      # NAME is the identity → REPO column; repo[@branch] → BRANCH column.
      label="tmux"
      where="$repo"
      [[ "$branch" != "-" && "$branch" != "?" ]] && where="${repo}@${branch}"
      age_h=$(_ai_humantime $(( now - created )))
      write_h=$(_ai_humantime $(( now - activity )))
      size_h="${windows}w"
      sort_key="$activity"
      repo_p=$(_ai_pad "$repo_w" "$name")
      branch_p=$(_ai_pad "$branch_w" "$where")

      if (( color_on )); then
        color=$'\033[38;2;189;147;249m'   # dracula purple
        if (( attached >= 1 )); then att_h="${c_green}●${c_reset}"; else att_h="${c_dim}○${c_reset}"; fi
        formatted="${color}${(r:10:)label}${c_reset}${repo_p}${c_dim}${branch_p}${c_reset}${(r:7:)age_h}${(r:8:)write_h}${(r:7:)size_h}${att_h}"
      else
        if (( attached >= 1 )); then att_h="*"; else att_h=""; fi
        formatted="${(r:10:)label}${repo_p}${branch_p}${(r:7:)age_h}${(r:8:)write_h}${(r:7:)size_h}${att_h}"
      fi

      rows+=("${sort_key}|${created}|${name}|-|${formatted}")
    done <<< "$raw"
  fi

  (( ${#rows} == 0 )) && return 2

  local -a sorted
  sorted=("${(@f)$(printf '%s\n' "${rows[@]}" | sort -t'|' -k1,1nr -k2,2nr)}")

  local row n lf fmt
  for row in "${sorted[@]}"; do
    [[ -z "$row" ]] && continue
    row="${row#*|}"; row="${row#*|}"      # drop sort_key, created
    n="${row%%|*}";  row="${row#*|}"
    lf="${row%%|*}"
    fmt="${row#*|}"
    printf '%s\t%s\t%s\n' "$n" "$lf" "$fmt"
  done
}

# ai-status [--all|-a] — table of running agent panes with repo, branch,
# log age/activity. With --all, plain tmux sessions ride along (session name
# in the REPO column) — used by the tmux M-s popup for session hopping.
# Non-TTY or no fzf: plain table. TTY+fzf: interactive picker with live pane preview:
#   Enter   → focus the pane in isengard (attach/switch-client); plain rows attach
#   Ctrl-D  → chdir-only to the pane's cwd
#   Ctrl-K  → kill the highlighted pane (confirm + instant refresh)
#   Ctrl-L  → open the pane's log in less
#   Ctrl-R  → refresh the table
ai-status() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "ai-status: tmux not installed" >&2; return 1
  fi

  local scope="" prompt="ais ❯ "
  case "$1" in
    --all|-a|all) scope="all"; prompt="tmux ❯ " ;;
  esac

  local -a data_rows
  data_rows=("${(@f)$(_ai_status_rows $scope)}")
  if (( ${#data_rows} == 0 )) || [[ -z "${data_rows[1]}" ]]; then
    echo "ai-status: no agent panes${scope:+ or sessions} running" >&2; return 0
  fi

  local header repo_w branch_w
  read -r repo_w branch_w <<< "$(_ai_status_widths)"
  header=$(printf '%-10s%-*s%-*s%-7s%-8s%-7s%s' AGENT "$repo_w" REPO "$branch_w" BRANCH AGE WRITE SIZE ST)

  # Non-TTY or no fzf → plain table.
  if [[ ! -t 1 ]] || ! command -v fzf >/dev/null 2>&1; then
    local -a plain_rows
    plain_rows=("${(@f)$(_ai_status_rows plain $scope)}")
    printf '%s\n' "$header"
    local r
    for r in "${plain_rows[@]}"; do
      [[ -z "$r" ]] && continue
      printf '%s\n' "${r##*$'\t'}"
    done
    return 0
  fi

  # TTY + fzf → interactive picker.
  local src reload_cmd kill_cmd tmux_bin preview_cmd
  src="source ${(q)AI_SESSIONS_FILE} && _ai_status_rows $scope"
  reload_cmd="command zsh -fc ${(q)src}"
  # Bind/preview strings run bare `tmux` under /bin/sh, which knows nothing of
  # the AIL_SOCKET seam — and pane ids (%N) collide across servers, so a bare
  # kill-pane would hit the DEFAULT server. Interpolate the socket here.
  tmux_bin="tmux${AIL_SOCKET:+ -L $AIL_SOCKET}"
  preview_cmd="$tmux_bin capture-pane -ep -t {1} 2>/dev/null || echo '(gone — ^r to refresh)'"
  # {1} is a pane_id (%N) on agent rows, a session name on --all plain rows.
  kill_cmd='printf "\n  kill %s? [y/N] " {1}; read -r r </dev/tty; case "$r" in [yY]*) case {1} in %*) '"$tmux_bin"' kill-pane -t {1};; *) '"$tmux_bin"' kill-session -t ={1};; esac;; esac'

  local result key selected target
  # --with-shell: zsh would apply equals-expansion to the `-t =name` exact-match
  # targets inside preview/execute commands; POSIX sh has no such expansion.
  # --height/--no-multi override the global FZF_DEFAULT_OPTS (40%, --multi).
  result=$(printf '%s\n' "${data_rows[@]}" | fzf \
    --with-shell='/bin/sh -c' \
    --height=100% \
    --no-multi \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=3 \
    --expect=ctrl-d \
    --prompt="$prompt" \
    --header=$'enter attach · ^d cd · ^k kill · ^l log · ^r refresh\n'"$header" \
    --reverse \
    --preview="$preview_cmd" \
    --preview-window='down,60%,border-top' \
    --preview-label=' live pane ' \
    --bind="ctrl-r:reload($reload_cmd)" \
    --bind='ctrl-l:execute(test -f {2} && less -R {2})' \
    --bind="ctrl-k:execute($kill_cmd)+reload($reload_cmd)" \
    --color='bg+:#44475a,fg+:#f8f8f2,hl:#bd93f9,hl+:#ff79c6,info:#6272a4,prompt:#50fa7b,pointer:#ff79c6,header:#6272a4,border:#6272a4,preview-border:#bd93f9,label:#bd93f9') || return 0
  [[ -z "$result" ]] && return 0

  # --expect output: line 1 is the key ("" on enter), line 2 the selection.
  key="${result%%$'\n'*}"
  selected="${result#*$'\n'}"
  target="${selected%%$'\t'*}"
  [[ -z "$target" ]] && return 0

  # Agent rows carry a pane_id (%N); --all plain rows carry a session name.
  if [[ "$target" == %* ]]; then
    # tmux 3.7b exits 0 with an EMPTY expansion for dead/unknown pane targets —
    # rc alone cannot detect a stale pane; check the expanded value instead.
    if [[ -z "$(_ai_tmux display-message -p -t "$target" '#{pane_id}' 2>/dev/null)" ]]; then
      echo "ais: pane '$target' no longer exists" >&2
      return 1
    fi
  elif ! _ai_tmux has-session -t "=$target" 2>/dev/null; then
    echo "ais: session '$target' no longer exists" >&2
    return 1
  fi

  case "$key" in
    ctrl-d)
      local p
      if [[ "$target" == %* ]]; then
        p=$(_ai_tmux display-message -p -t "$target" -F '#{pane_current_path}' 2>/dev/null)
      else
        p=$(_ai_tmux display-message -p -t "=${target}:" -F '#{session_path}' 2>/dev/null)
      fi
      if [[ -n "$p" && -d "$p" ]]; then
        cd "$p"
        echo "ais: → $p" >&2
      else
        echo "ais: path unavailable" >&2
        return 1
      fi
      ;;
    *)
      if [[ "$target" == %* ]]; then
        _ai_tmux select-window -t "$target" 2>/dev/null
        _ai_tmux select-pane -t "$target" 2>/dev/null
        if [[ -n "$TMUX" ]]; then
          _ai_tmux switch-client -t "=isengard" 2>/dev/null || true
        else
          _ai_tmux attach -t "=isengard"
        fi
      else
        _ai_goto_session "$target"
      fi
      ;;
  esac
}
alias ais=ai-status
