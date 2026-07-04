# tmux popup shells (Alt+Enter): Esc at the prompt closes the popup.
# Scoped by TMUX_POPUP so normal shells keep Esc untouched. Esc inside
# full-screen programs (vim, less) never reaches zle, so they're unaffected.
if [[ -n "$TMUX_POPUP" ]]; then
  KEYTIMEOUT=20  # 0.2s to disambiguate bare Esc from escape sequences (arrows etc.)
  _popup_close() { BUFFER="exit"; zle accept-line }
  zle -N _popup_close
  bindkey '\e' _popup_close
fi
