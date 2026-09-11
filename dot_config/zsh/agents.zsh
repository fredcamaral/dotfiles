# ================================================================
# AI AGENT WRAPPERS — thin launchers over ai-sessions
# ================================================================
# TUI invocations route through ai-* (tmux session + pipe-pane log),
# defined in ~/.config/ai-sessions/ai-sessions.sh (sourced after this file;
# resolution happens at call time, so ordering is fine).
# Non-TUI subcommands pass straight through to the binary — no tmux, no log.

cl() {
  case "$1" in
    # These touch the installation, not an account: keep them off the wrapper.
    update|upgrade|install|migrate-installer|--help|-h|--version|-v)
      command claude "$@"
      ;;
    # `mcp` and `doctor` read the ACTIVE account's config dir, and `-p` spends
    # its quota — all three go through the account-aware `claude` function so
    # they answer for the account this repo is on, not the default one.
    mcp|doctor)
      claude "$@"
      ;;
    # Background-session management (`claude --bg`): these open or control an
    # EXISTING Claude process, so the wrapper must not wrap them — ai-claude
    # would prepend --session-id and Claude would reject the mix. `attach`
    # takes over the terminal like a TUI but is logged by the daemon, not us.
    attach|stop|logs|agents|rm|respawn)
      claude "$@"
      ;;
    -p|--print)
      claude --dangerously-skip-permissions "$@"
      ;;
    *)
      ai-claude "$@"
      ;;
  esac
}

opencode() {
  case "$1" in
    run|auth|agent|github|models|serve|stats|export|update|upgrade|--help|-h|--version|-v)
      command opencode "$@"
      ;;
    *)
      ai-opencode "$@"
      ;;
  esac
}
alias oc=opencode

opencode2() {
  case "$1" in
    run|auth|agent|github|models|serve|stats|export|update|upgrade|--help|-h|--version|-v)
      command opencode2 "$@"
      ;;
    *)
      ai-opencode2 "$@"
      ;;
  esac
}
alias oc2=opencode2

cx() {
  case "$1" in
    exec|e|login|logout|mcp|proto|completion|debug|apply|update|upgrade|--help|-h|--version|-v)
      command codex "$@"
      ;;
    *)
      ai-codex "$@"
      ;;
  esac
}

droid() {
  case "$1" in
    update|upgrade|exec|daemon|mcp|plugin|search|find|computer|--help|-h|--version|-v)
      command droid "$@"
      ;;
    *)
      ai-droid "$@"
      ;;
  esac
}

pi() {
  case "$1" in
    install|remove|uninstall|update|list|config|--help|-h|--version|-v)
      command pi "$@"
      ;;
    *)
      ai-pi "$@"
      ;;
  esac
}

gac() {
  local yes=0
  local msg="updating..."

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        yes=1
        shift
        ;;
      -m|--message)
        msg="$2"
        shift 2
        ;;
      *)
        msg="$1"
        shift
        ;;
    esac
  done

  git status -sb
  echo "This will run: git add . && git commit -m \"$msg\"" >&2
  if [[ $yes -eq 1 ]] || _confirm "Proceed?"; then
    git add . && git commit -m "$msg"
  fi
}
