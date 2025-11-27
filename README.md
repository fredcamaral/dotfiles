# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/), with secrets handled via [1Password](https://1password.com/).

## Overview

A macOS-focused development environment configuration featuring:

- Modern terminal setup (zsh + starship + tmux/zellij)
- Neovim with NvChad (15 LSP servers, treesitter)
- AI-powered development tools (Claude, Goose, OpenCommit)
- Centralized secrets management via 1Password
- Catppuccin Mocha theme across all tools

## What's Included

```
~
├── .zshrc                    # Shell config with aliases, functions, history
├── .tmux.conf                # Terminal multiplexer (catppuccin theme)
├── .gitconfig                # Git configuration (templated for portability)
├── .opencommit               # AI commit message generator
├── .claude.json              # Claude Code MCP servers config
├── .claude/CLAUDE.md         # Claude Code instructions
│
└── .config/
    ├── envvars/api_keys.env  # CENTRALIZED API keys (single source of truth)
    ├── starship.toml         # Cross-shell prompt (catppuccin mocha)
    ├── ghostty/config        # Terminal emulator
    ├── zellij/config.kdl     # Modern terminal multiplexer (catppuccin)
    ├── nvim/                 # Neovim (NvChad + LSP + Treesitter)
    ├── helix/config.toml     # Helix editor
    ├── yazi/                 # Terminal file manager (v0.4+ config)
    ├── karabiner/            # Keyboard remapping (caps lock → hyper)
    ├── gh/                   # GitHub CLI
    ├── git/ignore            # Global gitignore
    ├── goose/config.yaml     # Goose AI assistant
    ├── raycast/              # Raycast launcher
    └── intellimmit/          # AI commit tool config
```

## Quick Start

### One Command Setup (for me)

```bash
curl -fsSL https://raw.githubusercontent.com/fredcamaral/dotfiles/main/scripts/bootstrap.sh | bash
```

This script will:
1. Install Homebrew (if needed)
2. Install 1Password CLI and prompt for sign-in
3. Install all required tools (zsh, tmux, neovim, starship, etc.)
4. Install chezmoi and apply dotfiles with secrets from 1Password
5. Configure zsh as default shell
6. Install tmux plugin manager

### Manual Setup

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
export OPENAI_API_KEY="{{ onepasswordRead "op://Dotfiles/OpenAI/credential" }}"

# To prompted input:
export OPENAI_API_KEY="{{ promptStringOnce . "secrets.openai" "OpenAI API Key" }}"
```

## Secrets Management

All secrets are **centralized** in `~/.config/envvars/api_keys.env`, sourced by `.zshrc`.

Secrets are stored in a dedicated 1Password vault called `Dotfiles`:

| Secret | Environment Variable | Purpose |
|--------|---------------------|---------|
| OpenAI | `OPENAI_API_KEY` | OpenAI API |
| OpenRouter-Env | `OPENROUTER_API_KEY` | OpenRouter API |
| OpenRouter-OpenCommit | `OCO_API_KEY` | OpenCommit tool |
| Firecrawl | `FIRECRAWL_API_KEY` | Web scraping |
| GitHub MCP Token | `GITHUB_MCP_TOKEN` | GitHub Copilot MCP |
| Contentful | `CONTENTFUL_SPACE_ID`, `CONTENTFUL_ACCESS_TOKEN`, `CONTENTFUL_PREVIEW_TOKEN` | Contentful CMS |
| PostHog Public | `NEXT_PUBLIC_POSTHOG_KEY`, `NEXT_PUBLIC_POSTHOG_HOST` | Analytics |
| PostHog Personal | `POSTHOG_PERSONAL_KEY` | PostHog admin |
| Raycast | *(config file)* | Raycast launcher |

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

### Neovim

- Based on [NvChad](https://nvchad.com/) v2.5
- **LSP servers**: gopls, ts_ls, lua_ls, pyright, rust_analyzer, yamlls, jsonls, bashls, dockerls, html, cssls, tailwindcss + more
- **Treesitter**: 20+ languages (go, typescript, lua, markdown, yaml, dockerfile, etc.)
- **Format on save**: Enabled via conform.nvim
- Theme: ayu_dark
- Leader: `Space`

### Tmux

- **Prefix**: `Ctrl+a` (easier than default `Ctrl+b`)
- **Splits**: `|` vertical, `-` horizontal (same directory)
- **Navigation**: `Alt+arrows` between panes (no prefix needed)
- **Persistence**: Auto-save/restore sessions with continuum

### Zellij

- **Theme**: Catppuccin Mocha
- **Default mode**: Locked (press `Ctrl+g` to unlock)
- **Session persistence**: Auto-attach to existing session

### Yazi (File Manager)

- v0.4+ compatible configuration
- Git integration keybindings (`g+s` status, `g+a` add, `g+c` commit)
- Catppuccin Mocha theme

### Keyboard (Karabiner)

- Caps Lock → Hyper key (Cmd+Ctrl+Option+Shift)

## Requirements

- macOS (tested on Sonoma/Sequoia)
- [Homebrew](https://brew.sh/)
- [1Password](https://1password.com/) with CLI (for my setup)

### Recommended Tools

```bash
brew install \
  zsh tmux neovim helix \
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

## Adding New Secrets

```bash
# Add to 1Password
op item create --category=login --title="Service Name" --vault="Dotfiles" 'credential=your-api-key'

# Add to api_keys.env.tmpl
export SERVICE_API_KEY="{{ onepasswordRead "op://Dotfiles/Service Name/credential" }}"

# Re-apply
chezmoi apply
source ~/.zshrc
```

## License

MIT - Feel free to use and adapt.

## Credits

- [chezmoi](https://www.chezmoi.io/) - Dotfiles manager
- [NvChad](https://nvchad.com/) - Neovim configuration
- [Catppuccin](https://github.com/catppuccin) - Color scheme
- [Starship](https://starship.rs/) - Shell prompt
