# ================================================================
# FUNCTIONS
# ================================================================

_confirm() {
  [[ -t 0 ]] || return 1
  local prompt="$1" reply
  read -r "reply?$prompt [y/N] "
  [[ "$reply" == [Yy]* ]]
}

cleanup() {
  local yes=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes) yes=1; shift ;;
      *) shift ;;
    esac
  done

  echo "This will run: brew cleanup && docker system prune -af" >&2
  if [[ $yes -eq 1 ]] || _confirm "Proceed?"; then
    brew cleanup && docker system prune -af
  fi
}

# mkdir + cd combined
mkcd() { mkdir -p "$1" && cd "$1" }

# Quick file backup with timestamp
bak() { cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)" }

# Universal archive extraction
extract() {
  if [[ ! -f "$1" ]]; then
    echo "extract: '$1' is not a file"
    return 1
  fi
  case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz)  tar xzf "$1" ;;
    *.tar.xz)  tar xJf "$1" ;;
    *.tar.zst) tar --zstd -xf "$1" ;;
    *.bz2)     bunzip2 "$1" ;;
    *.gz)      gunzip "$1" ;;
    *.tar)     tar xf "$1" ;;
    *.tbz2)    tar xjf "$1" ;;
    *.tgz)     tar xzf "$1" ;;
    *.zip)     unzip "$1" ;;
    *.Z)       uncompress "$1" ;;
    *.7z)      7z x "$1" ;;
    *.rar)     unrar x "$1" ;;
    *)         echo "extract: unknown format '$1'" ;;
  esac
}

# Interactive git branch checkout with fzf
fbr() {
  local branch=$(git branch -a --color=always | grep -v HEAD |
    fzf --ansi --preview 'git log --oneline --graph --color=always $(echo {} | sed "s/.*\///"| xargs) -- | head -20' |
    sed 's/.*remotes\/origin\///' | xargs)
  [[ -n "$branch" ]] && git checkout "$branch"
}

# Interactive git log browser with fzf
flog() {
  git log --oneline --graph --decorate --all --color=always |
    fzf --ansi --no-sort --reverse --preview 'git show --color=always $(echo {} | grep -o "[a-f0-9]\{7,\}" | head -1)' |
    grep -o "[a-f0-9]\{7,\}" | head -1 | xargs git show
}

# Interactive history search with fzf
fh() {
  local output
  output=$(builtin history -n 1 | fzf --no-sort --reverse --query="$*" --no-multi)
  print -z -- "$output"
}

# Audit PATH for security issues
path-audit() {
  echo "Checking PATH for potential issues..."
  echo

  if [[ "$PATH" == *"::"* ]] || [[ "$PATH" == ":"* ]] || [[ "$PATH" == *":" ]]; then
    echo "WARNING: Empty PATH component detected"
  fi

  for dir in ${(s/:/)PATH}; do
    if [[ ! -d "$dir" ]]; then
      echo "WARNING: Non-existent: $dir"
      continue
    fi

    local perms=$(stat -f %A "$dir" 2>/dev/null)
    if [[ "$perms" == *"7" ]]; then
      echo "WARNING: World-writable: $dir ($perms)"
    else
      echo "OK: $dir"
    fi
  done
}

# Check required tools are installed
check-tools() {
  local tools=(fd fzf rg eza lazygit starship zoxide)
  echo "Tool status:"
  for tool in $tools; do
    if command -v $tool &> /dev/null; then
      echo "  OK: $tool"
    else
      echo "  MISSING: $tool"
    fi
  done
}

# Zellij pane title helper
function _zellij_last_two_dirs() {
    local cwd="${PWD/#$HOME/~}"
    local parts=("${(@s:/:)cwd}")
    (( ${#parts} >= 2 )) && echo "${parts[-2]}/${parts[-1]}" || echo "$cwd"
}

function _zellij_title_precmd() {
    print -Pn "\e]0;../$(_zellij_last_two_dirs) - zsh\a"
}

function _zellij_title_preexec() {
    local cmd="${1%% *}"
    print -Pn "\e]0;../$(_zellij_last_two_dirs) - ${cmd}\a"
}

if [[ -n "$ZELLIJ" ]]; then
    precmd_functions+=(_zellij_title_precmd)
    preexec_functions+=(_zellij_title_preexec)
fi

# Interactive MLX server launcher for local Qwen models.
mlxserve() {
  local base_dir="$HOME/ai/mlx"
  local log_file="$base_dir/mlx_lm.server.log"
  local pid_file="$base_dir/mlx_lm.server.pid"
  local host="${MLX_SERVER_HOST:-127.0.0.1}"
  local port="${MLX_SERVER_PORT:-8080}"

  if ! command -v mlx_lm.server >/dev/null 2>&1; then
    echo "mlxserve: mlx_lm.server not found on PATH"
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    echo "mlxserve: fzf not found on PATH"
    return 1
  fi

  mkdir -p "$base_dir"

  # Model list built dynamically from ~/ai/mlx/models (symlinks + real dirs),
  # so it auto-tracks every downloaded model. Each row is tagged with the backend
  # that can serve it: [8080] = mlx_lm.server (spawned below); [oMLX] = the
  # always-on oMLX server on :8000 (VLM/unified arches mlx_lm can't load, e.g.
  # gemma4_unified). label|path|context|note.
  local models_dir="$base_dir/models"
  # arches mlx_lm.server can load = modules under ITS OWN interpreter's mlx_lm.models
  local mlxpy mlxlm_archs
  mlxpy=$(sed -n '1s/^#!//p' =mlx_lm.server 2>/dev/null)
  [[ -n "$mlxpy" ]] && mlxlm_archs=$("$mlxpy" -c "import mlx_lm.models as m,os;print(' '.join(f[:-3] for f in os.listdir(os.path.dirname(m.__file__)) if f.endswith('.py')))" 2>/dev/null)
  local selected label model context note
  selected=$(
    for d in "$models_dir"/*(N); do
      [[ -e "$d/config.json" ]] || continue
      row=$(python3 -c "import json;c=json.load(open('$d/config.json'));print((c.get('model_type') or '?'),(c.get('max_position_embeddings') or c.get('text_config',{}).get('max_position_embeddings') or '?'))" 2>/dev/null)
      mt=${row%% *}; cx=${row##* }
      backend='[oMLX]'
      [[ -n "$mlxlm_archs" && " $mlxlm_archs " == *" $mt "* ]] && backend='[8080]'
      printf '%s|%s|%s|%s\n' "${d:t}" "$d" "$cx" "$backend ctx ${cx:-?}  ($mt)"
    done | fzf --delimiter='|' --with-nth=1,4 --header='MLX model  [8080]=mlx_lm.server  [oMLX]=oMLX :8000' --prompt='mlx model> ')

  [[ -n "$selected" ]] || return 1
  IFS='|' read -r label model context note <<< "$selected"

  local mtype
  mtype=$(python3 -c "import json;print(json.load(open('$model/config.json')).get('model_type',''))" 2>/dev/null)

  # Route arches mlx_lm.server can't load (VLM/unified) to the always-on oMLX.
  if [[ -n "$mtype" && -n "$mlxlm_archs" && " $mlxlm_archs " != *" $mtype "* ]]; then
    local omlx_port="${OMLX_PORT:-8000}"
    echo "mlxserve: '$label' (arch=$mtype) isn't loadable by mlx_lm.server — served by oMLX."
    echo "mlxserve: use http://127.0.0.1:$omlx_port/v1  (model id: '$label')"
    echo "mlxserve: if oMLX doesn't list it yet (downloaded after last start), refresh with:"
    echo "          launchctl kickstart -k gui/$UID/homebrew.mxcl.omlx"
    return 0
  fi

  # Thinking profiles only apply to Qwen-family chat templates (incl. Qwopus,
  # arch qwen3_5_moe). Non-Qwen models get plain profiles, no template args.
  local profile profile_name max_tokens chat_template_args profile_note
  if [[ "${mtype:l}" == *qwen* || "${label:l}" == *qwen* || "${label:l}" == *qwopus* ]]; then
    profile=$(printf '%s\n' \
      'direct|32768|{"enable_thinking":false}|Direct answers, lower token burn' \
      'thinking|32768|{"enable_thinking":true}|Emit thinking before final answer' \
      'preserve-thinking|32768|{"enable_thinking":true,"preserve_thinking":true}|Keep prior thinking traces (long agent sessions)' \
      'benchmark|81920|{"enable_thinking":true}|Huge output budget for hard math/coding' | \
      fzf --delimiter='|' --with-nth=1,2,4 --header='Choose serving profile (Qwen)' --prompt='mlx profile> ')
  else
    profile=$(printf '%s\n' \
      'standard|32768||Default output budget' \
      'large-output|81920||Huge output budget for hard tasks' | \
      fzf --delimiter='|' --with-nth=1,2,4 --header='Choose serving profile' --prompt='mlx profile> ')
  fi

  [[ -n "$profile" ]] || return 1
  IFS='|' read -r profile_name max_tokens chat_template_args profile_note <<< "$profile"

  local existing_pids
  existing_pids=$(pgrep -f 'mlx_lm.server' 2>/dev/null)
  if [[ -n "$existing_pids" ]]; then
    echo "mlxserve: existing mlx_lm.server process(es): $existing_pids"
    local reply
    read -r "reply?Stop existing MLX server and replace it? [y/N] "
    if [[ "$reply" != [Yy]* ]]; then
      echo "mlxserve: leaving existing server running"
      return 1
    fi
    pkill -f 'mlx_lm.server' || return 1
    sleep 1
  fi

  echo "mlxserve: starting $label"
  echo "mlxserve: context=$context output=$max_tokens profile=$profile_name"
  echo "mlxserve: log=$log_file"

  local -a launch_args=(--model "$model" --host "$host" --port "$port" --max-tokens "$max_tokens")
  [[ -n "$chat_template_args" ]] && launch_args+=(--chat-template-args "$chat_template_args")
  nohup mlx_lm.server "${launch_args[@]}" > "$log_file" 2>&1 &

  local pid=$!
  print -r -- "$pid" > "$pid_file"

  local ready=0
  for _ in {1..60}; do
    if curl -fsS --max-time 2 "http://$host:$port/v1/models" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 2
  done

  if [[ "$ready" -eq 1 ]]; then
    echo "mlxserve: ready at http://$host:$port/v1"
    curl -fsS --max-time 2 "http://$host:$port/v1/models"
    echo
  else
    echo "mlxserve: server is still warming up; check $log_file"
  fi
}

mlxstop() {
  local pids
  pids=$(pgrep -f 'mlx_lm.server' 2>/dev/null)
  if [[ -z "$pids" ]]; then
    echo "mlxstop: no mlx_lm.server process is running"
    return 0
  fi
  echo "mlxstop: stopping $pids"
  pkill -f 'mlx_lm.server'
}

mlxstatus() {
  local host="${MLX_SERVER_HOST:-127.0.0.1}"
  local port="${MLX_SERVER_PORT:-8080}"
  pgrep -fl 'mlx_lm.server' || true
  curl -fsS --max-time 2 "http://$host:$port/v1/models" || true
  echo
}
