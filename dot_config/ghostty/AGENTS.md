# Ghostty Configuration

## Hyper Key Workaround

Ghostty has a bug (introduced in PR #7320) where it doesn't properly recognize Karabiner's Hyper key (Caps Lock → ⌘⌥⌃⇧). Instead of receiving the modifier combo, Ghostty prints raw hex keycodes like `6D` and `6C`.

### How the workaround works

1. **Karabiner** ([`../karabiner/karabiner.json`](../karabiner/karabiner.json)):
   - Caps Lock is mapped to Hyper (⌘⌥⌃⇧) globally for all apps
   - When Ghostty is the frontmost app, Karabiner intercepts Hyper+arrow keys and sends function keys instead:
     - Hyper + ← → Shift+F14
     - Hyper + → → Shift+F15
     - Hyper + ↑ → Shift+F16
     - Hyper + ↓ → Shift+F17

2. **Ghostty** (`config`):
   - Binds the function keys to pane navigation actions:
     - Shift+F14 → `goto_split:left`
     - Shift+F15 → `goto_split:right`
     - Shift+F16 → `goto_split:top`
     - Shift+F17 → `goto_split:bottom`

### Disabled mappings

Additional Hyper+letter mappings are commented out in both configs but preserved for future use:
- `a` (previous_tab), `i/y/q` (font size), `u/n/g/b/p/o` (scrolling/prompts), `r` (reload), `c/v` (copy/paste)

These can be re-enabled when the Ghostty bug is fixed.

### Tracking

- GitHub Discussion: https://github.com/ghostty-org/ghostty/discussions/7385
- Related: https://github.com/ghostty-org/ghostty/discussions/8909

## Other notes

- `macos-option-as-alt = true` is set for vim/emacs compatibility
- Many keybindings are disabled because Zellij handles splits/tabs internally
- Right Option is mapped to Ctrl+A (tmux prefix) via Karabiner
