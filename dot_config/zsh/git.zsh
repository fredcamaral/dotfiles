# ================================================================
# GIT WORKFLOW HELPERS
# ================================================================

zmodload zsh/datetime 2>/dev/null
: ${GIT_PROMPT_BASE_FETCH_INTERVAL:=600}

_git_normalized_base_ref() {
  local base="$1" upstream
  [[ -n "$base" ]] || return 1

  # If the base is a local branch with an upstream, track the upstream ref.
  # That makes base↓N update from the remote-tracking ref without checking out the base branch.
  if command git show-ref --verify --quiet "refs/heads/$base"; then
    upstream="$(command git rev-parse --abbrev-ref --symbolic-full-name "${base}@{upstream}" 2>/dev/null)"
    [[ -n "$upstream" ]] && { print -r -- "$upstream"; return 0; }
  fi

  print -r -- "$base"
}

_git_set_branch_base() {
  local branch="$1" base="$2" normalized
  [[ -n "$branch" && -n "$base" && "$branch" != -* ]] || return 0

  normalized="$(_git_normalized_base_ref "$base")" || return 0
  command git rev-parse --verify --quiet "${normalized}^{commit}" >/dev/null || return 0
  command git config "branch.${branch}.base" "$normalized" >/dev/null 2>&1 || return 0
}

_git_base_fetch_target() {
  local base="$1" upstream remote remote_ref
  [[ -n "$base" ]] || return 1

  if command git show-ref --verify --quiet "refs/heads/$base"; then
    upstream="$(command git rev-parse --abbrev-ref --symbolic-full-name "${base}@{upstream}" 2>/dev/null)" || return 1
    base="$upstream"
  fi

  [[ "$base" == refs/remotes/*/* ]] && base="${base#refs/remotes/}"

  remote="${base%%/*}"
  remote_ref="${base#*/}"
  [[ "$remote_ref" != "$base" && -n "$remote" && -n "$remote_ref" ]] || return 1
  command git remote get-url "$remote" >/dev/null 2>&1 || return 1

  print -r -- "$remote $remote_ref"
}

_git_prompt_fetch_base_precmd() {
  [[ "${GIT_PROMPT_AUTO_FETCH:-1}" == "0" ]] && return
  (( GIT_PROMPT_BASE_FETCH_INTERVAL > 0 )) || return

  local branch base target remote remote_ref git_common_dir cache_dir cache_key stamp lock now last
  branch="$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)" || return
  base="$(command git config --get "branch.${branch}.base" 2>/dev/null)" || return
  target="$(_git_base_fetch_target "$base")" || return
  remote="${target%% *}"
  remote_ref="${target#* }"

  git_common_dir="$(command git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [[ -n "$git_common_dir" ]] || git_common_dir="$(command git rev-parse --absolute-git-dir 2>/dev/null)" || return
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-git-base-fetch"
  cache_key="${git_common_dir//\//_}"
  stamp="$cache_dir/${cache_key}.stamp"
  lock="$cache_dir/${cache_key}.lock"
  now="${EPOCHSECONDS:-$(command date +%s)}"

  [[ -r "$stamp" ]] && last="$(<"$stamp")"
  [[ "$last" == <-> && $(( now - last )) -lt $GIT_PROMPT_BASE_FETCH_INTERVAL ]] && return

  command mkdir -p "$cache_dir" 2>/dev/null || return
  command mkdir "$lock" 2>/dev/null || return
  print -r -- "$now" >| "$stamp" 2>/dev/null

  (
    command git fetch --quiet --no-tags "$remote" "+refs/heads/${remote_ref}:refs/remotes/${remote}/${remote_ref}"
    command rmdir "$lock" 2>/dev/null
  ) >/dev/null 2>&1 &!
}

if [[ ${precmd_functions[(Ie)_git_prompt_fetch_base_precmd]} -eq 0 ]]; then
  precmd_functions+=(_git_prompt_fetch_base_precmd)
fi

# Show or override the base used by the prompt's base↓N indicator.
unalias gbase 2>/dev/null
gbase() {
  local branch base normalized
  branch="$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)" || {
    echo "gbase: not on a branch"
    return 1
  }

  if [[ "$1" == "--unset" ]]; then
    command git config --unset "branch.${branch}.base"
    return $?
  fi

  if [[ -z "$1" ]]; then
    base="$(command git config --get "branch.${branch}.base" 2>/dev/null)"
    [[ -n "$base" ]] && echo "$branch base: $base" || echo "$branch base: not set"
    return 0
  fi

  normalized="$(_git_normalized_base_ref "$1")" || return 1
  if ! command git rev-parse --verify --quiet "${normalized}^{commit}" >/dev/null; then
    echo "gbase: ref not found: $1"
    return 1
  fi

  command git config "branch.${branch}.base" "$normalized" || return 1
  echo "$branch base: $normalized"
}

# Record branch base when using the normal branch-creation commands.
git() {
  local exit_code base

  if [[ "$1" == "checkout" && "$2" == "-b" && -n "$3" ]]; then
    base="${4:-$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)}"
    command git "$@"
    exit_code=$?
    (( exit_code == 0 )) && _git_set_branch_base "$3" "$base"
    return $exit_code
  fi

  if [[ "$1" == "switch" && ( "$2" == "-c" || "$2" == "--create" ) && -n "$3" ]]; then
    base="${4:-$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)}"
    command git "$@"
    exit_code=$?
    (( exit_code == 0 )) && _git_set_branch_base "$3" "$base"
    return $exit_code
  fi

  command git "$@"
}

# Delete local and remote branch
unalias grm 2>/dev/null
grm() {
  if [[ -z "$1" ]]; then
    echo "Usage: grm <branch-name>"
    return 1
  fi
  git branch -d "$1" && git push origin --delete "$1"
}

# Find unmerged branches
unalias gunmerged 2>/dev/null
gunmerged() {
  git branch --no-merged
}

# Squash last N commits
unalias gsquash 2>/dev/null
gsquash() {
  if [[ -z "$1" ]]; then
    echo "Usage: gsquash <number-of-commits>"
    return 1
  fi
  git reset --soft HEAD~"$1" && git commit
}

# Create worktree with new branch from current branch
unalias gwt 2>/dev/null
gwt() {
  if [[ -z "$1" ]]; then
    echo "Usage: gwt <branch-name>"
    return 1
  fi
  local safe="${1//\//-}"
  local base="$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)"
  git worktree add -b "$1" "./worktrees/$safe" && _git_set_branch_base "$1" "$base" && cd "./worktrees/$safe"
}

# Remove a worktree created by gwt (and delete its branch)
#   gwtrm <branch>     safe: refuses if worktree dirty or branch unmerged
#   gwtrm -f <branch>  force: nukes worktree and branch regardless
unalias gwtrm 2>/dev/null
gwtrm() {
  local force=0
  if [[ "$1" == "-f" || "$1" == "--force" ]]; then
    force=1
    shift
  fi
  if [[ -z "$1" ]]; then
    echo "Usage: gwtrm [-f|--force] <branch-name>"
    return 1
  fi

  local branch="$1"
  local safe="${branch//\//-}"

  # Locate main worktree (always the first entry in porcelain output)
  local main_wt
  main_wt=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / { print $2; exit }')
  if [[ -z "$main_wt" ]]; then
    echo "gwtrm: not inside a git repository"
    return 1
  fi

  local target="$main_wt/worktrees/$safe"

  # Pre-validate: at least one of (branch, worktree) must exist
  local branch_exists=0 wt_exists=0
  git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null && branch_exists=1
  [[ -d "$target" ]] && wt_exists=1
  if (( ! branch_exists && ! wt_exists )); then
    echo "gwtrm: no branch or worktree named '$branch' found"
    return 1
  fi

  # If we're inside the target worktree, escape to main worktree first.
  # Compare canonicalized paths (git resolves symlinks, $PWD often doesn't —
  # e.g. macOS /tmp → /private/tmp).
  local current_wt
  current_wt=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$current_wt" && "$current_wt" == "$target" ]]; then
    echo "Currently inside target worktree; moving to $main_wt"
    cd "$main_wt" || return 1
  fi

  # Step 1: remove worktree (must happen before branch delete — git refuses
  # to delete a branch that has a worktree checked out)
  if (( wt_exists )); then
    if (( force )); then
      git worktree remove --force "$target" 2>/dev/null
    else
      git worktree remove "$target" || {
        echo "gwtrm: worktree dirty — re-run with: gwtrm -f $branch"
        return 1
      }
    fi
  fi

  # Step 2: delete branch
  if (( branch_exists )); then
    if (( force )); then
      git branch -D "$branch" 2>/dev/null
    else
      git branch -d "$branch" || {
        echo "gwtrm: branch '$branch' unmerged — re-run with: gwtrm -f $branch"
        return 1
      }
    fi
  fi

  echo "Removed: $branch"
}

# GitHub PR and local branch housekeeping helpers.
unalias prmine pr-mine prml prreview pr-review prrl gbranches gcleanmerged gclean-merged 2>/dev/null

_git_origin_default_ref() {
  local ref

  ref="$(command git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
  if [[ -n "$ref" ]]; then
    print -r -- "$ref"
    return 0
  fi

  for ref in origin/main origin/master origin/develop main master; do
    if command git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
      print -r -- "$ref"
      return 0
    fi
  done

  return 1
}

_pr_open_from_fzf() {
  local prompt="$1" owner="$2" rows="$3" selected url repo repo_dir owner_l

  if ! command -v fzf >/dev/null 2>&1; then
    echo "pr open: fzf not found"
    return 1
  fi

  if [[ -z "$rows" ]]; then
    echo "pr open: no PRs found"
    return 0
  fi

  selected="$(print -r -- "$rows" | fzf \
    --delimiter=$'\t' \
    --with-nth=2.. \
    --prompt="$prompt" \
    --height=80% \
    --layout=reverse \
    --border \
    --header='Enter: open PR and cd into repo | Esc: cancel' \
  )" || return 1
  [[ -n "$selected" ]] || return 1

  url="${selected%%$'\t'*}"
  repo="${${selected#*$'\t'}%%$'\t'*}"

  open "$url"

  [[ -n "$repo" && "$repo" != \#* ]] || return 0

  owner_l="${owner:l}"
  for repo_dir in "$HOME/repos/$repo" "$HOME/repos/$owner_l/$repo" "$HOME/repos/$owner/$repo"; do
    if [[ -d "$repo_dir" ]]; then
      cd "$repo_dir" || return 1
      return 0
    fi
  done

  echo "pr open: repo opened, but local directory not found for $repo under ~/repos"
  return 0
}

prmine() {
  local org='' limit=100 open_mode=0

  if ! command -v gh >/dev/null 2>&1; then
    echo "prmine: gh not found"
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --open|-o) open_mode=1; shift ;;
      --org)
        if [[ -z "$2" ]]; then
          echo "Usage: prmine [--open] [--org <org>] [--limit <number>]"
          return 1
        fi
        org="$2"
        shift 2
        ;;
      --limit|-L)
        if [[ -z "$2" ]]; then
          echo "Usage: prmine [--open] [--org <org>] [--limit <number>]"
          return 1
        fi
        limit="$2"
        shift 2
        ;;
      *)
        echo "Usage: prmine [--open] [--org <org>] [--limit <number>]"
        return 1
        ;;
    esac
  done

  if [[ -n "$org" ]]; then
    if (( open_mode )); then
      local rows
      rows="$(gh search prs \
        --owner "$org" \
        --author "@me" \
        --state open \
        --limit "$limit" \
        --json number,repository,title,isDraft,url \
        --jq '(.[] | select(.isDraft == false) | [.url, (.repository.name // "-"), ("#" + (.number|tostring)), .title] | @tsv)')" || return $?
      _pr_open_from_fzf "prmine> " "$org" "$rows"
      return $?
    fi

    gh search prs \
      --owner "$org" \
      --author "@me" \
      --state open \
      --limit "$limit" \
      --json number,repository,title,isDraft,url \
      --jq '(["REPO","PR","TITLE"] | @tsv), (.[] | select(.isDraft == false) | [(.repository.name // "-"), ("#" + (.number|tostring)), .title] | @tsv)' \
      | column -t -s $'\t'
    return ${pipestatus[1]}
  fi

  if (( open_mode )); then
    local rows
    rows="$(gh pr list \
      --state open \
      --author "@me" \
      --json number,title,headRefName,baseRefName,isDraft,reviewDecision,mergeStateStatus,url \
      --jq '(.[] | select(.isDraft == false) | [.url, ("#" + (.number|tostring)), (.reviewDecision // "-"), (.mergeStateStatus // "-"), .headRefName, .baseRefName, .title] | @tsv)')" || return $?
    _pr_open_from_fzf "prmine> " "" "$rows"
    return $?
  fi

  gh pr list \
    --state open \
    --author "@me" \
    --json number,title,headRefName,baseRefName,isDraft,reviewDecision,mergeStateStatus,url \
    --jq '(["PR","REVIEW","MERGE","BRANCH","BASE","TITLE","URL"] | @tsv), (.[] | select(.isDraft == false) | [("#" + (.number|tostring)), (.reviewDecision // "-"), (.mergeStateStatus // "-"), .headRefName, .baseRefName, .title, .url] | @tsv)' \
    | column -t -s $'\t'
}
alias pr-mine="prmine"
prml() { prmine --org lerianstudio --open "$@" }

prreview() {
  local org='' limit=100 open_mode=0

  if ! command -v gh >/dev/null 2>&1; then
    echo "prreview: gh not found"
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --open|-o) open_mode=1; shift ;;
      --org)
        if [[ -z "$2" ]]; then
          echo "Usage: prreview [--open] [--org <org>] [--limit <number>]"
          return 1
        fi
        org="$2"
        shift 2
        ;;
      --limit|-L)
        if [[ -z "$2" ]]; then
          echo "Usage: prreview [--open] [--org <org>] [--limit <number>]"
          return 1
        fi
        limit="$2"
        shift 2
        ;;
      *)
        echo "Usage: prreview [--open] [--org <org>] [--limit <number>]"
        return 1
        ;;
    esac
  done

  if [[ -n "$org" ]]; then
    if (( open_mode )); then
      local rows
      rows="$(gh search prs \
        --owner "$org" \
        --review-requested "@me" \
        --state open \
        --limit "$limit" \
        --json number,repository,title,author,isDraft,url \
        --jq '(.[] | [.url, (.repository.name // "-"), ("#" + (.number|tostring)), (if .isDraft then "draft" else "ready" end), (.author.login // "-"), .title] | @tsv)')" || return $?
      _pr_open_from_fzf "prreview> " "$org" "$rows"
      return $?
    fi

    gh search prs \
      --owner "$org" \
      --review-requested "@me" \
      --state open \
      --limit "$limit" \
      --json number,repository,title,author,isDraft,url \
      --jq '(["REPO","PR","DRAFT","AUTHOR","TITLE"] | @tsv), (.[] | [(.repository.name // "-"), ("#" + (.number|tostring)), (if .isDraft then "yes" else "no" end), (.author.login // "-"), .title] | @tsv)' \
      | column -t -s $'\t'
    return ${pipestatus[1]}
  fi

  if (( open_mode )); then
    local rows
    rows="$(gh pr list \
      --state open \
      --search "review-requested:@me" \
      --json number,title,author,headRefName,baseRefName,isDraft,url \
      --jq '(.[] | [.url, ("#" + (.number|tostring)), (if .isDraft then "draft" else "ready" end), (.author.login // "-"), .headRefName, .baseRefName, .title] | @tsv)')" || return $?
    _pr_open_from_fzf "prreview> " "" "$rows"
    return $?
  fi

  gh pr list \
    --state open \
    --search "review-requested:@me" \
    --json number,title,author,headRefName,baseRefName,isDraft,url \
    --jq '(["PR","DRAFT","AUTHOR","BRANCH","BASE","TITLE","URL"] | @tsv), (.[] | [("#" + (.number|tostring)), (if .isDraft then "yes" else "no" end), (.author.login // "-"), .headRefName, .baseRefName, .title, .url] | @tsv)' \
    | column -t -s $'\t'
}
alias pr-review="prreview"
prrl() { prreview --org lerianstudio --open "$@" }

gbranches() {
  command git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "gbranches: not inside a git repository"
    return 1
  }

  if command git remote get-url origin >/dev/null 2>&1; then
    command git fetch --prune --quiet origin || echo "gbranches: warning: git fetch --prune origin failed; using local remote refs" >&2
  fi

  local origin_default current branch upstream origin_ref has_origin compare_ref merged counts ahead behind marker
  origin_default="$(_git_origin_default_ref 2>/dev/null)"
  current="$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)"

  printf '%-2s %-38s %-7s %-30s %-34s %-11s\n' '' 'BRANCH' 'ORIGIN' 'UPSTREAM' 'MERGED_IN' 'AHEAD/BEHIND'
  while IFS= read -r branch; do
    marker=' '
    [[ "$branch" == "$current" ]] && marker='*'

    upstream="$(command git rev-parse --abbrev-ref --symbolic-full-name "${branch}@{upstream}" 2>/dev/null)"
    origin_ref="origin/$branch"
    has_origin='no'
    command git rev-parse --verify --quiet "refs/remotes/${origin_ref}" >/dev/null && has_origin='yes'

    compare_ref="$origin_default"
    [[ -n "$upstream" && "$upstream" != "$origin_ref" ]] && compare_ref="$upstream"

    if [[ -n "$compare_ref" ]] && command git merge-base --is-ancestor "$branch" "$compare_ref" 2>/dev/null; then
      merged="yes -> $compare_ref"
    elif [[ -n "$compare_ref" ]]; then
      merged="no  -> $compare_ref"
    else
      merged='unknown'
    fi

    if [[ -n "$upstream" ]]; then
      counts="$(command git rev-list --left-right --count "${branch}...${upstream}" 2>/dev/null)"
      ahead="${counts%%[[:space:]]*}"
      behind="${counts##*[[:space:]]}"
      [[ -n "$counts" ]] && counts="${ahead}/${behind}" || counts='-'
    else
      counts='-'
    fi

    printf '%-2s %-38s %-7s %-30s %-34s %-11s\n' "$marker" "$branch" "$has_origin" "${upstream:--}" "$merged" "$counts"
  done < <(command git for-each-ref --format='%(refname:short)' refs/heads)
}

gcleanmerged() {
  command git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "gcleanmerged: not inside a git repository"
    return 1
  }

  local yes=0 dry_run=0 base='' current branch protected_base
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run) dry_run=1; shift ;;
      -y|--yes) yes=1; shift ;;
      --base)
        if [[ -z "$2" ]]; then
          echo "Usage: gcleanmerged [-n|--dry-run] [-y|--yes] [--base <ref>]"
          return 1
        fi
        base="$2"
        shift 2
        ;;
      *)
        echo "Usage: gcleanmerged [-n|--dry-run] [-y|--yes] [--base <ref>]"
        return 1
        ;;
    esac
  done

  if command git remote get-url origin >/dev/null 2>&1; then
    command git fetch --prune --quiet origin || {
      echo "gcleanmerged: git fetch --prune origin failed; refusing to delete from stale refs"
      return 1
    }
  fi

  [[ -n "$base" ]] || base="$(_git_origin_default_ref 2>/dev/null)"
  if [[ -z "$base" ]] || ! command git rev-parse --verify --quiet "${base}^{commit}" >/dev/null; then
    echo "gcleanmerged: cannot find origin default branch; pass --base <ref>"
    return 1
  fi

  current="$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)"
  protected_base="${base#origin/}"

  local -a branches
  branches=()
  while IFS= read -r branch; do
    [[ "$branch" == "$current" ]] && continue
    case "$branch" in
      main|master|develop|development|dev|staging|production|prod|trunk|"$protected_base") continue ;;
    esac

    if command git merge-base --is-ancestor "$branch" "$base" 2>/dev/null; then
      branches+=("$branch")
    fi
  done < <(command git for-each-ref --format='%(refname:short)' refs/heads)

  if (( ${#branches[@]} == 0 )); then
    echo "gcleanmerged: no local branches merged into $base"
    return 0
  fi

  echo "Local branches merged into $base:"
  printf '  %s\n' "${branches[@]}"

  (( dry_run )) && return 0

  if (( ! yes )); then
    local reply
    read -r "reply?Delete these local branches? [y/N] "
    [[ "$reply" == [Yy]* ]] || return 1
  fi

  for branch in "${branches[@]}"; do
    command git branch -D "$branch"
  done
}
alias gclean-merged="gcleanmerged"
