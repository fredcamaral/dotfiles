#!/bin/bash
#
# Bootstrap script for Fred's dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/fredcamaral/dotfiles/main/scripts/bootstrap.sh | bash
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Header
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}     Fred's Dotfiles Bootstrap Script      ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is designed for macOS only."
fi

# ============================================================================
# Homebrew
# ============================================================================
info "Checking Homebrew..."
if ! command -v brew &> /dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add brew to PATH for Apple Silicon
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    success "Homebrew installed"
else
    success "Homebrew already installed"
fi

# ============================================================================
# 1Password CLI
# ============================================================================
info "Checking 1Password CLI..."
if ! command -v op &> /dev/null; then
    info "Installing 1Password CLI..."
    brew install --cask 1password-cli
    success "1Password CLI installed"
else
    success "1Password CLI already installed"
fi

# Check 1Password sign-in
info "Checking 1Password authentication..."
if ! op account list &> /dev/null; then
    warn "Not signed in to 1Password"
    echo ""
    echo -e "${YELLOW}Please sign in to 1Password:${NC}"
    echo "  1. Open 1Password app"
    echo "  2. Go to Settings → Developer → Enable CLI integration"
    echo "  3. Run: op signin"
    echo ""
    read -p "Press Enter after signing in to 1Password..."
    
    if ! op account list &> /dev/null; then
        error "1Password authentication failed. Please run 'op signin' and try again."
    fi
fi
success "1Password authenticated"

# Verify Dotfiles vault exists
info "Checking 1Password Dotfiles vault..."
if ! op vault get "Dotfiles" &> /dev/null; then
    error "Dotfiles vault not found in 1Password. Please create it first."
fi
success "Dotfiles vault found"

# ============================================================================
# Core Tools
# ============================================================================
info "Installing core tools..."

BREW_PACKAGES=(
    # Shell & Terminal
    zsh
    tmux
    starship
    zellij
    
    # Editors
    neovim
    helix
    
    # Modern CLI replacements
    eza          # ls replacement
    bat          # cat replacement
    fd           # find replacement
    ripgrep      # grep replacement
    fzf          # fuzzy finder
    zoxide       # cd replacement
    
    # Development
    git
    gh
    lazygit
    lazydocker
    
    # File management
    yazi
    
    # Other
    jq
    htop
    ncdu
)

BREW_CASKS=(
    ghostty
    1password-cli  # Already installed, but ensure it's there
)

info "Installing brew packages..."
for pkg in "${BREW_PACKAGES[@]}"; do
    if ! brew list "$pkg" &> /dev/null; then
        brew install "$pkg"
    fi
done
success "Brew packages installed"

info "Installing brew casks..."
for cask in "${BREW_CASKS[@]}"; do
    if ! brew list --cask "$cask" &> /dev/null 2>&1; then
        brew install --cask "$cask" 2>/dev/null || true
    fi
done
success "Brew casks installed"

# ============================================================================
# Chezmoi & Dotfiles
# ============================================================================
info "Installing chezmoi and applying dotfiles..."
if ! command -v chezmoi &> /dev/null; then
    brew install chezmoi
fi

# Initialize and apply dotfiles
chezmoi init --apply fredcamaral

success "Dotfiles applied"

# ============================================================================
# Post-install Configuration
# ============================================================================
info "Running post-install configuration..."

# Set zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
    info "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
fi

# Install tmux plugin manager
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    info "Installing tmux plugin manager..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# Install zsh plugins (zsh-autosuggestions, zsh-syntax-highlighting)
info "Ensuring zsh plugins are installed..."
brew list zsh-autosuggestions &>/dev/null || brew install zsh-autosuggestions
brew list zsh-syntax-highlighting &>/dev/null || brew install zsh-syntax-highlighting

# ============================================================================
# Summary
# ============================================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}           Setup Complete!                  ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Restart your terminal (or run: source ~/.zshrc)"
echo "  2. Open tmux and press ${YELLOW}prefix + I${NC} to install plugins"
echo "  3. Open neovim - plugins will auto-install"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  chezmoi edit ~/.zshrc    # Edit dotfiles"
echo "  chezmoi apply            # Apply changes"
echo "  chezmoi update           # Pull & apply latest"
echo ""
success "All done! Enjoy your new setup."
