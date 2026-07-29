# Yixiao's Dotfiles

## Quick setup on a fresh Ubuntu server

`setup_ubuntu.sh` bootstraps the whole CLI environment in one go: it updates apt, installs base packages (zsh, vim, git, tmux, btop, etc.), sets up Oh My Zsh + zsh-autosuggestions, installs uv / kimi-code / Neovim via their official installers, symlinks the dotfiles (`zshrc`, `tmux.conf`, `vimrc`, `nvim/`) into place, runs a headless `:Lazy restore`, and switches the login shell to zsh. It prints a plan and asks for confirmation before making any changes.

```shell
# Clone the repo to ~/dotfiles (the script expects this exact path)
git clone https://github.com/yixiaosz/dotfiles.git ~/dotfiles

# Make the script executable and run it with bash
chmod +x ~/dotfiles/setup_ubuntu.sh
bash ~/dotfiles/setup_ubuntu.sh
```

Log out and back in afterwards for the shell change to take effect. The script is safe to re-run — steps that are already done are skipped.

## Installation

Clone the repository:

```shell
# Clone the repo
git clone https://github.com/yixiaosz/dotfiles.git

# Check what do you need
cd ./dotfiles && ls -a

# Remove the .git folder so you can initialize your own later
rm -rf ./.git
```

## Prerequisites

On a vanilla Ubuntu setup, install zsh and oh-my-zsh before using the `zshrc`.

```shell
# Install zsh
sudo apt update && sudo apt install -y zsh

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

If the installer did not switch your default shell, do it manually, then log out and back in for the change to take effect.

```shell
chsh -s $(which zsh)
```

## Usage

Configuration files in this repository are stored without the leading dot (`.`) to prevent accidental loading. To use a specific configuration, either copy it to your home directory or create a symbolic link.

### Option A: Copy the file

Copy `vimrc` to your home directory as `.vimrc`.
> **Note:** Check for and back up any existing configuration files before overwriting.

```shell
cp -i ~/dotfiles/vimrc ~/.vimrc
```

### Option B: Create a symbolic link

Link `vimrc` to your home directory as `.vimrc`. This allows updates in the repository to be reflected immediately.
> **Note:** Ensure no file currently exists at the destination before linking.

```shell
ln -s ~/dotfiles/vimrc ~/.vimrc
```

## Set the global gitignore file

Use the `git config` command to point to the `git_global` file.

```shell
git config --global core.excludesfile ~/.gitignore_global
```

You can also add it manually by editing the `.gitconfig` file.

```shell
[core]
    excludesfile = ~/.gitignore_global
``` 

### Verify the git configuration

If you see the path to the `.gitignore_global` file, such as `Users/[username]/.gitignore_global`, it's successfully configured. 

```shell
git config core.excludesfile
```

## Oh-my-zsh 

My zsh uses oh-my-zsh to manage my plugins. Make sure you check out the `plugins=()` section in the `zshrc` and install the included plugins. 

Built-in plugins such as `ssh-agent` and `colored-man-pages` ship with oh-my-zsh, but custom plugins must be cloned manually since there is no plugin manager. Currently the only custom plugin is `zsh-autosuggestions`:

```shell
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

## Alacritty

The config lives in `alacritty/alacritty.toml` and imports a theme from the `alacritty/themes/` directory, so both need to be in place.

```shell
mkdir -p ~/.config/alacritty
ln -s ~/dotfiles/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
ln -s ~/dotfiles/alacritty/themes ~/.config/alacritty/themes
```

To switch themes, edit the `import` line at the top of `alacritty.toml`. Changes apply immediately thanks to `live_config_reload`.

> **Note:** The font is set to `TX-02` and the shell to `/usr/bin/zsh` — adjust these if your setup differs.

## Ghostty

Link `ghostty/config` to Ghostty's config location.

```shell
mkdir -p ~/.config/ghostty
ln -s ~/dotfiles/ghostty/config ~/.config/ghostty/config
```

> **Note:** The custom macOS icon is referenced by absolute path (`~/dotfiles/ghostty/ghostty-pink.icns`), so this assumes the repo is cloned to `~/dotfiles`.

## Neovim

The Neovim setup is a LazyVim config with custom functions migrated from `vimrc`. Link the whole `nvim` directory.

```shell
ln -s ~/dotfiles/nvim ~/.config/nvim
```

On first launch, lazy.nvim will install all plugins pinned in `lazy-lock.json`.

### Syncing Neovim plugins across machines

Plugin versions are pinned in `nvim/lazy-lock.json`, which is tracked in this repo. To keep machines in sync:

- Run `:Lazy update` on your **primary machine only**, then commit and push the updated lockfile.
- On all other machines, pull and run `:Lazy restore` to check out the exact pinned commits.

Avoid running `:Lazy update` on more than one machine, or the lockfile will ping-pong between commits.
