#!/usr/bin/env bash
#
# setup_ubuntu.sh — bootstrap a fresh Ubuntu server with yixiaosz CLI environment.
#
# Run with:  bash setup_ubuntu.sh
#
# What it does:
#   1. apt update && apt upgrade
#   2. apt install a base set of packages (extend APT_PACKAGES below)
#   3. Install Oh My Zsh + zsh-autosuggestions plugin
#   4. Install uv, kimi-code, and Neovim
#   5. Symlink dotfiles from ~/dotfiles into $HOME / ~/.config
#   6. Install vim-plug and run headless `PlugInstall` for vimrc plugins
#   7. Headless `Lazy restore` to install Neovim plugins from lazy-lock.json
#   8. Change login shell to zsh
#
# Assumes this repo is cloned at ~/dotfiles.

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

# --- Add more apt packages here -------------------------------------------
APT_PACKAGES=(
    zsh
    vim
    curl
    wget
    git
    tmux
    btop
    build-essential
    fzf
    fortune-mod
    fortunes-min
    ripgrep
    fd-find
    unzip
    # add more packages below this line
)
# --------------------------------------------------------------------------

log()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[skip]\033[0m %s\n' "$*"; }

# Symlink $1 -> $2, backing up an existing non-symlink target to <target>.bak
link_dotfile() {
    local src="$1" dst="$2"
    if [ ! -e "$src" ]; then
        warn "source $src not found, skipping"
        return
    fi
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        warn "$dst already linked"
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mv "$dst" "$dst.bak"
        echo "  backed up existing $dst -> $dst.bak"
    fi
    ln -s "$src" "$dst"
    echo "  linked $dst -> $src"
}

# --- Plan summary + confirmation -------------------------------------------
cat <<EOF
This script will set up a fresh Ubuntu server with your CLI environment:

  1. apt update && apt upgrade -y
  2. apt install: ${APT_PACKAGES[*]}
  3. Install Oh My Zsh + zsh-autosuggestions plugin
  4. Install uv
  5. Install kimi-code
  6. Install Neovim
  7. Symlink dotfiles from $DOTFILES_DIR:
       zshrc     -> ~/.zshrc
       tmux.conf -> ~/.tmux.conf
       vimrc     -> ~/.vimrc
       nvim/     -> ~/.config/nvim
     (existing files are backed up to *.bak)
  8. Install vim-plug
  9. Resotre lazyvim plugins from lazy-lock.json
  10. chsh: change login shell to zsh

Requires: sudo privileges and internet access.
EOF

printf '\nProceed? [y/N] '
read -r answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 0 ;;
esac

if [ ! -d "$DOTFILES_DIR" ]; then
    echo "ERROR: $DOTFILES_DIR not found. Clone the dotfiles repo there first." >&2
    exit 1
fi

# --- 1+2. apt --------------------------------------------------------------
log "Updating apt and upgrading packages"
sudo apt update
sudo apt upgrade -y

log "Installing apt packages"
sudo apt install -y "${APT_PACKAGES[@]}"

mkdir -p "$HOME/.local/bin"
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# --- 3. Oh My Zsh + autosuggestions ----------------------------------------
if [ -d "$HOME/.oh-my-zsh" ]; then
    warn "Oh My Zsh already installed"
else
    log "Installing Oh My Zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
    warn "zsh-autosuggestions already installed"
else
    log "Installing zsh-autosuggestions plugin"
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
fi

# --- 4. uv -----------------------------------------------------------------
if command -v uv >/dev/null 2>&1 || [ -x "$HOME/.local/bin/uv" ]; then
    warn "uv already installed"
else
    log "Installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# --- 5. kimi-code -----------------------------------------------------------
if command -v kimi >/dev/null 2>&1 || [ -x "$HOME/.kimi-code/bin/kimi" ]; then
    warn "kimi-code already installed"
else
    log "Installing kimi-code"
    curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash
fi

# --- 6. Neovim
mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
if [ -x "$HOME/.local/bin/nvim" ]; then
    warn "Neovim already installed at ~/.local/bin/nvim"
else
    log "Installing Neovim (latest stable release)"
    tmpdir="$(mktemp -d)"
    downloaded=""
    for url in \
        "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
        "https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz"; do
        if curl -fsSL "$url" -o "$tmpdir/nvim.tar.gz"; then
            downloaded="$url"
            break
        fi
    done
    if [ -z "$downloaded" ]; then
        echo "ERROR: failed to download Neovim release tarball" >&2
        rm -rf "$tmpdir"
        exit 1
    fi
    tar -xzf "$tmpdir/nvim.tar.gz" -C "$tmpdir"
    nvim_dir="$(find "$tmpdir" -maxdepth 1 -type d -name 'nvim-*' | head -1)"
    rm -rf "$HOME/.local/opt/nvim"
    mv "$nvim_dir" "$HOME/.local/opt/nvim"
    ln -sf "$HOME/.local/opt/nvim/bin/nvim" "$HOME/.local/bin/nvim"
    rm -rf "$tmpdir"
    echo "  installed $("$HOME/.local/bin/nvim" --version | head -1)"
fi

# --- 7. Symlink dotfiles ----------------------------------------------------
log "Symlinking dotfiles from $DOTFILES_DIR"
link_dotfile "$DOTFILES_DIR/zshrc"     "$HOME/.zshrc"
link_dotfile "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf"
link_dotfile "$DOTFILES_DIR/vimrc"     "$HOME/.vimrc"
mkdir -p "$HOME/.config"
link_dotfile "$DOTFILES_DIR/nvim"      "$HOME/.config/nvim"

# --- 8. vim-plug + PlugInstall --------------------------------------
if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    warn "vim-plug already installed"
else
    log "Installing vim-plug"
    curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

log "Installing vim plugins"
vim -es -u "$HOME/.vimrc" -c "PlugInstall --sync" -c "qa!" </dev/null

# --- 9. Headless Lazy restore ------------------------------------------------
log "Installing Neovim plugins"
"$HOME/.local/bin/nvim" --headless "+Lazy! restore" +qa

# --- 10. Default shell --------------------------------------------------------
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ]; then
    warn "login shell is already zsh"
else
    log "Changing login shell to zsh"
    sudo chsh -s "$(command -v zsh)" "$USER"
fi

log "Done! Log out and back in (or run 'exec zsh') to start using your new environment."
echo "Note: '$HOME/.local/bin' and '$HOME/.kimi-code/bin' are on PATH via your zshrc."
