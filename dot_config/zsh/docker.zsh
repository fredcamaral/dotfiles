# ================================================================
# DOCKER OPERATIONS
# ================================================================

dockerpurge() {
  local yes=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes) yes=1; shift ;;
      *) shift ;;
    esac
  done

  echo "This will run: docker system prune -f --volumes && docker volume prune -f && docker builder prune -f" >&2
  if [[ $yes -eq 1 ]] || _confirm "Proceed?"; then
    docker system prune -f --volumes && docker volume prune -f && docker builder prune -f
  fi
}

dockerpurgeall() {
  local yes=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes) yes=1; shift ;;
      *) shift ;;
    esac
  done

  echo "This will run: docker system prune -af --volumes && docker volume prune -af && docker builder prune -af" >&2
  if [[ $yes -eq 1 ]] || _confirm "Proceed?"; then
    docker system prune -af --volumes && docker volume prune -af && docker builder prune -af
  fi
}
