# Fred's Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Quick Install

```bash
# Install chezmoi and apply dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply fredcamaral

# Or if you already have chezmoi:
chezmoi init --apply fredcamaral
```

## What's Included

### Shell & Terminal
- **zsh** - Shell configuration with aliases, functions, and completions
- **tmux** - Terminal multiplexer with catppuccin theme
- **starship** - Cross-shell prompt
- **zellij** - Modern terminal multiplexer
- **ghostty** - Terminal emulator config

### Editors
- **neovim** - NvChad-based configuration
- **helix** - Modal editor config

### Developer Tools
- **git** - Global gitconfig and ignore patterns
- **gh** - GitHub CLI configuration
- **goose** - AI assistant config
- **yazi** - Terminal file manager

### Other
- **karabiner** - Keyboard remapping (caps lock -> hyper key)

## Secrets Management

This repo uses chezmoi templates to handle secrets. On first run, you'll be prompted for:

- Firecrawl API Key (for Claude MCP)
- GitHub MCP Token
- OpenRouter API Key (for OpenCommit)
- Raycast Token
- Intellimmit OpenAI Key

Secrets are stored locally in `~/.config/chezmoi/chezmoi.toml` and never committed.

### Updating Secrets

```bash
# Re-run init to update secrets
chezmoi init

# Or edit directly
chezmoi edit-config
```

## Manual Steps After Install

1. **tmux plugins**: Press `prefix + I` to install tmux plugins
2. **neovim plugins**: Open neovim and run `:Lazy sync`
3. **zsh completions**: Restart shell or run `compinit`

## Customization

Edit files locally then add to chezmoi:

```bash
# Edit a managed file
chezmoi edit ~/.zshrc

# See what would change
chezmoi diff

# Apply changes
chezmoi apply

# Add changes back to source
chezmoi add ~/.zshrc
```

## Requirements

- macOS (tested on Sonoma/Sequoia)
- Homebrew
- Git

### Recommended Tools (install via brew)

```bash
brew install \
  zsh \
  tmux \
  neovim \
  starship \
  zellij \
  yazi \
  eza \
  fzf \
  zoxide \
  ripgrep \
  fd \
  bat \
  lazygit \
  gh
```

## License

MIT
