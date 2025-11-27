# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/), with secrets handled via [1Password](https://1password.com/).

## Overview

A macOS-focused development environment configuration featuring:

- Modern terminal setup (zsh + starship + tmux/zellij)
- Neovim with NvChad
- AI-powered development tools (Claude, Goose, OpenCommit)
- Sensible defaults and keybindings

## What's Included

```
~
├── .zshrc                    # Shell config with aliases, functions, history
├── .tmux.conf                # Terminal multiplexer (catppuccin theme)
├── .gitconfig                # Git configuration
├── .opencommit               # AI commit message generator
├── .claude.json              # Claude Code MCP servers config
├── .claude/CLAUDE.md         # Claude Code instructions
│
└── .config/
    ├── starship.toml         # Cross-shell prompt
    ├── ghostty/config        # Terminal emulator
    ├── zellij/config.kdl     # Modern terminal multiplexer
    ├── nvim/                 # Neovim (NvChad-based)
    ├── helix/config.toml     # Helix editor
    ├── yazi/                 # Terminal file manager
    ├── karabiner/            # Keyboard remapping (caps lock → hyper)
    ├── gh/                   # GitHub CLI
    ├── git/ignore            # Global gitignore
    ├── goose/config.yaml     # Goose AI assistant
    ├── envvars/api_keys.env  # Environment variables (API keys)
    ├── raycast/              # Raycast launcher
    └── intellimmit/          # AI commit tool config
```

## Quick Start

### For Me (on a new machine)

```bash
# Prerequisites: 1Password CLI installed and signed in
brew install --cask 1password-cli
op signin

# Install dotfiles - secrets auto-injected from 1Password
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply fredcamaral
```

### For Others

Feel free to fork and adapt! You'll need to:

1. Remove/modify the 1Password integration in `.chezmoi.toml.tmpl`
2. Either use your own password manager or switch to manual prompts:

```toml
# Change from:
firecrawl_api_key = {{ onepasswordRead "op://Dotfiles/Firecrawl/credential" | quote }}

# To prompted input:
firecrawl_api_key = {{ promptStringOnce . "secrets.firecrawl_api_key" "Firecrawl API Key" | quote }}
```

## Secrets Management

Secrets are stored in a dedicated 1Password vault called `Dotfiles` and injected automatically during `chezmoi init`.

| Secret | Purpose |
|--------|---------|
| Firecrawl | Web scraping for Claude MCP |
| GitHub MCP Token | GitHub Copilot MCP integration |
| OpenAI | OpenAI API (env vars) |
| OpenRouter-Env | OpenRouter API (env vars) |
| OpenRouter-OpenCommit | OpenRouter API (OpenCommit) |
| Raycast | Raycast launcher token |
| Intellimmit OpenAI | AI commit tool (encrypted key) |

**No secrets are stored in this repository.**

## Post-Install Steps

```bash
# Install tmux plugins
# Open tmux, then press: prefix + I

# Install neovim plugins
nvim  # Lazy.nvim will auto-install on first launch

# Reload shell
source ~/.zshrc
```

## Key Features

### Shell (zsh)

- **Smart history**: Shared across terminals, no duplicates
- **Directory navigation**: `z` (zoxide), `..`, `...`, bookmarks (`~repos`, `~config`)
- **Git shortcuts**: `gs`, `gp`, `gl`, `glog`, `fbr` (fuzzy branch checkout)
- **Modern replacements**: `eza` for ls, `bat` for cat, `rg` for grep

### Tmux

- **Prefix**: `Ctrl+a` (easier than default `Ctrl+b`)
- **Splits**: `|` vertical, `-` horizontal (same directory)
- **Navigation**: `Alt+arrows` between panes (no prefix needed)
- **Persistence**: Auto-save/restore sessions with continuum

### Neovim

- Based on [NvChad](https://nvchad.com/) v2.5
- Theme: ayu_dark
- Leader: `Space`

### Keyboard (Karabiner)

- Caps Lock → Hyper key (Cmd+Ctrl+Option+Shift)

## Requirements

- macOS (tested on Sonoma/Sequoia)
- [Homebrew](https://brew.sh/)
- [1Password](https://1password.com/) with CLI (for my setup)

### Recommended Tools

```bash
brew install \
  zsh tmux neovim \
  starship zellij ghostty \
  yazi eza bat fd ripgrep fzf \
  zoxide lazygit gh
```

## Updating

```bash
# Pull latest changes
chezmoi update

# Or manually
chezmoi git pull
chezmoi apply
```

## Adding New Dotfiles

```bash
chezmoi add ~/.some-config      # Add file
chezmoi edit ~/.some-config     # Edit managed file
chezmoi diff                    # Preview changes
chezmoi apply                   # Apply changes
chezmoi cd                      # Go to source directory
git add -A && git commit && git push
```

## License

MIT - Feel free to use and adapt.

## Credits

- [chezmoi](https://www.chezmoi.io/) - Dotfiles manager
- [NvChad](https://nvchad.com/) - Neovim configuration
- [Catppuccin](https://github.com/catppuccin) - Color scheme
- [Starship](https://starship.rs/) - Shell prompt
