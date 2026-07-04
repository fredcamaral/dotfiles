# ================================================================
# ALIASES
# ================================================================

# System Shortcuts
alias c="clear"
alias zshconfig="micro ~/.zshrc"

# Directory Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias d='dirs -v'
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'

# File Operations
alias ls="eza --icons=auto --group-directories-first"
alias l="eza --icons=auto --group-directories-first -l --git --header"
alias ll="eza --icons=auto --group-directories-first -l --git --header --git-ignore"
alias la="eza --icons=auto --group-directories-first -l --git --header -a"
alias lt="eza --icons=auto --tree --level=2 --group-directories-first"
alias lta="eza --icons=auto --tree --level=2 --group-directories-first -a"
alias ltl="eza --icons=auto --tree --level=3 --group-directories-first"
alias lsize="eza --icons=auto --group-directories-first -l --sort=size --reverse"
alias ltime="eza --icons=auto --group-directories-first -l --sort=modified --reverse"
alias ldirs="eza --icons=auto --group-directories-first -l -D"
alias lfiles="eza --icons=auto --group-directories-first -l -f"
alias tree="eza --icons=auto --tree --group-directories-first"
alias dsize="du -hs"
alias space="ncdu"

# Development Tools
alias py="python"
alias py313="python3.13"
alias pip313="python3.13 -m pip"
alias lg="lazygit"
alias ld="lazydocker"
alias zj="zellij"
alias cx-fred="$HOME/Repos/codex/codex-rs/target/debug/codex --dangerously-bypass-approvals-and-sandbox"
alias cr-all="coderabbit review --plain --base main --type all --config $HOME/repos/lerianstudio/ring/docs/coderabbit-instructions.md > review.txt"
alias cr-unc="coderabbit review --plain --base main --type uncommitted --config $HOME/repos/lerianstudio/ring/docs/coderabbit-instructions.md > review.txt"

# Git Shortcuts
alias gcai="mkdir docs && cd docs && git clone https://github.com/lerianstudio/ai-prompts"
alias gs="git status -sb"
alias gd="git diff"
alias gp="git push"
alias gl="git pull"
alias gco="git checkout"
alias gcb="git checkout -b"
alias glog="git log --oneline --graph --decorate --all"
alias gunstage="git restore --staged"
alias gundo="git reset --soft HEAD~1"

# SSH Connections
alias clotilde="ssh root@100.126.231.67"
alias firmino="ssh root@100.115.193.91"
alias mordor="ssh fredamaral@100.87.109.57"

# System Shortcuts
alias reload="source ~/.zshrc"
alias myip="curl -s ifconfig.me"
alias ports="lsof -i -P | grep LISTEN"

alias rw="cd ~/.config/ring/worktrees"

# MLX local model server
alias mlx-start="mlxserve"
alias mlx-stop="mlxstop"
alias mlx-status="mlxstatus"

# workstation (dev VM no beleriand) — simetrico ao ssh-rivendell do workstation
alias ssh-workstation="ssh workstation"
