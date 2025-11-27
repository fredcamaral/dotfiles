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

This repo uses **1Password** for automatic secret injection. Secrets are stored in a dedicated `Dotfiles` vault and fetched automatically during `chezmoi init`.

### Prerequisites

1. Install 1Password CLI: `brew install --cask 1password-cli`
2. Enable CLI integration in 1Password app settings
3. Sign in: `op signin`

### Secrets Stored in 1Password (Dotfiles vault)

| Item | Used By |
|------|---------|
| Firecrawl | Claude MCP integration |
| GitHub MCP Token | GitHub Copilot MCP |
| OpenRouter | OpenCommit |
| Raycast | Raycast launcher |
| Intellimmit OpenAI | AI commit tool |

### How It Works

On `chezmoi init`, secrets are automatically fetched from 1Password:

```toml
# .chezmoi.toml.tmpl
firecrawl_api_key = {{ onepasswordRead "op://Dotfiles/Firecrawl/credential" }}
```

### Updating Secrets

Update the value in 1Password, then re-run:

```bash
chezmoi init
chezmoi apply
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
- 1Password with CLI enabled

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
