# ================================================================
# ZSH CORE CONFIGURATION
# ================================================================

# Profiling (uncomment both lines to diagnose slow startup)
# zmodload zsh/zprof

# Auto-start Zellij
#if [[ -z "$ZELLIJ" ]]; then
#    if command -v zellij &> /dev/null; then
#        eval "$(zellij setup --generate-auto-start zsh)"
#    fi
#fi

# Hardcoded brew prefix for ARM Mac (avoids subprocess call on every shell)
export BREW_PREFIX="/opt/homebrew"

# Completions
fpath=(
  $HOME/.docker/completions
  ~/.zsh/completion
  /Applications/Ghostty.app/Contents/Resources/zsh/site-functions
  $fpath
)

autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# Advanced completion settings
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
setopt AUTO_MENU

# Disable software flow control (Ctrl-S/Ctrl-Q freeze/resume)
stty -ixon -ixoff 2>/dev/null

# History Configuration
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# Better Directory Navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Extended Globbing
setopt EXTENDED_GLOB
setopt NULL_GLOB

# ================================================================
# ENVIRONMENT VARIABLES
# ================================================================

export GOPATH=$HOME/go
export GPG_TTY=$(tty)
export COMPOSE_BAKE=true
export OLLAMA_API_BASE=http://21.26.7.4:11434
export EDITOR=nvim
export VISUAL=nvim

# Claude Code
export CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=100000
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=128000
export CLAUDE_CODE_MAX_THINKING_TOKENS=32000

# OpenCode
export OPENCODE_EXPERIMENTAL_PLAN_MODE=true

export _ZO_DOCTOR=0

# Load sensitive environment variables
if [[ -f ~/.config/envvars/api_keys.env ]]; then
  perms=$(stat -f %A ~/.config/envvars/api_keys.env 2>/dev/null)
  if [[ "$perms" != "600" && "$perms" != "640" ]]; then
    echo "WARNING: ~/.config/envvars/api_keys.env has insecure permissions: $perms" >&2
    echo "  Run: chmod 600 ~/.config/envvars/api_keys.env" >&2
  fi
  source ~/.config/envvars/api_keys.env
fi

# ================================================================
# PATH CONFIGURATION
# ================================================================

typeset -U path PATH

export BUN_INSTALL="$HOME/.bun"

path=(
  "$BUN_INSTALL/bin"
  "$HOME/.opencode/bin"
  "$HOME/.antigravity/antigravity/bin"
  "$BREW_PREFIX/opt/openssl/bin"
  "$HOME/.codeium/windsurf/bin"
  $path
  "$GOPATH/bin"
  "$HOME/.lmstudio/bin"
  "$HOME/.cargo/bin"
  "$HOME/.local/bin"
  "/opt/homebrew/opt/node@22/bin"
  "$HOME/.omnara/bin"
)

for v in 3.14 3.13 3.12 3.11 3.10 3.9; do
  [[ -d "$HOME/Library/Python/$v/bin" ]] && path+=("$HOME/Library/Python/$v/bin")
done

export PATH

# Local binaries environment
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# ================================================================
# DIRECTORY BOOKMARKS
# ================================================================
hash -d repos=~/Repos
hash -d config=~/.config
hash -d claude=~/.claude

# ================================================================
# EXTERNAL INTEGRATIONS
# ================================================================

# Kiro Terminal Integration
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# Just completions
if command -v just &> /dev/null; then
  eval "$(just --completions zsh)"
fi

# Bun completions
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# ZSH Auto-suggestions
if [[ -f $BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source $BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# ZSH Syntax Highlighting
if [[ -f $BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source $BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# FZF Integration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --multi
  --preview-window=border-left
  --bind ctrl-/:toggle-preview
'

if command -v fd &> /dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git --exclude node_modules --exclude dist --exclude .venv'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'
fi

# Zoxide (using --cmd cd for proper cd wrapper instead of alias)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# Key Bindings
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

ctrl-z-toggle() {
  if [[ $#BUFFER -eq 0 ]]; then
    BUFFER="fg"
    zle accept-line
  else
    zle push-input
    zle clear-screen
  fi
}
zle -N ctrl-z-toggle
bindkey '^Z' ctrl-z-toggle

# Yazi: exit into the directory selected inside the file manager.
y() {
  local tmp="$(mktemp -t yazi-cwd.XXXXXX)" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [[ "$cwd" != "$PWD" && -d "$cwd" ]] && builtin cd -- "$cwd"
  command rm -f -- "$tmp"
}

# NVM (lazy-loaded; full nvm sourcing is expensive on every interactive shell)
export NVM_DIR="$HOME/.nvm"
_load_nvm() {
  unset -f nvm _load_nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm() {
  _load_nvm
  nvm "$@"
}

# omnara
export OMNARA_INSTALL="$HOME/.omnara"

# Profiling output
# zprof
