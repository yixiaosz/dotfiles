# Yixiao's Dotfiles

## Quick setup on a fresh Ubuntu server

I made this `setup_ubuntu.sh` script to bootstrap the whole CLI environment in one go: it updates apt, installs base packages (zsh, vim, git, tmux, btop, etc.), sets up Oh My Zsh + zsh-autosuggestions, installs uv / OpenCode / Neovim via their official installers, symlinks the dotfiles (`zshrc`, `tmux.conf`, `vimrc`, `nvim/`) into place, runs a headless `:Lazy restore`, and switches the login shell to zsh. It prints a plan and asks for confirmation before making any changes.

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

# (optional) Remove the .git folder so you can initialize your own later
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

## More details

<details>
<summary><h3>Global gitignore</h3></summary>

Link `gitignore_global` into your home directory, then configure Git to use it.

```shell
ln -s ~/dotfiles/gitignore_global ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

You can also add it manually by editing the `.gitconfig` file.

```shell
[core]
    excludesfile = ~/.gitignore_global
``` 

#### Verify the git configuration

If you see the path to the `.gitignore_global` file, such as `Users/[username]/.gitignore_global`, it's successfully configured. 

```shell
git config core.excludesfile
```

</details>
<details>
<summary><h3>Oh-my-zsh</h3></summary>

I use oh-my-zsh to manage my zsh plugins. Make sure you check out the `plugins=()` section in the `zshrc` and install the included plugins. 

Built-in plugins such as `ssh-agent` and `colored-man-pages` ship with oh-my-zsh, but custom plugins must be cloned manually since there is no plugin manager. 

I use the following custom plugin(s):
- `zsh-autosuggestions` (highly recommended)

```shell
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

</details>
<details>
<summary><h3>Alacritty</h3></summary>

The config lives in `alacritty/alacritty.toml` and imports a theme from the `alacritty/themes/` directory, so both need to be in place.

```shell
mkdir -p ~/.config/alacritty
ln -s ~/dotfiles/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
ln -s ~/dotfiles/alacritty/themes ~/.config/alacritty/themes
```

To switch themes, edit the `import` line at the top of `alacritty.toml`. Changes apply immediately thanks to `live_config_reload`.

> **Note:** The font is set to `TX-02` and the shell to `/usr/bin/zsh` — adjust these if your setup differs.

</details>
<details>
<summary><h3>Ghostty</h3></summary>

Link the base config and the override for your operating system to Ghostty's config location. Link only one platform-specific override.

```shell
mkdir -p ~/.config/ghostty
ln -s ~/dotfiles/ghostty/config ~/.config/ghostty/config

# Linux override
ln -s ~/dotfiles/ghostty/config.linux ~/.config/ghostty/config.linux

# macOS override
ln -s ~/dotfiles/ghostty/config.macos ~/.config/ghostty/config.macos
```

> **Note:** I made the `config.linux` automatically attaches Ghostty to the `main` tmux session, identical session window setup as the `tmux-init` function in `zshrc` does.

</details>
<details>
<summary><h3>Fontconfig</h3></summary>

I use en_US locale but also need to work with Simplified Chinese characters. This `fontconfig/fonts.conf` keeps the English fonts as the default while prioritizing Simplified Chinese Noto CJK fonts over Japanese variants for CJK fallback.

Add "Chinese(simplfied)" at `Settings/System/Region & Language/Manage Installed Languages/Install / Remove Languages...` or just install Noto CJK via apt.
```shell
sudo apt install fonts-noto-cjk
```

```shell
mkdir -p ~/.config/fontconfig
ln -s ~/dotfiles/fontconfig/fonts.conf ~/.config/fontconfig/fonts.conf
```

Clear font cache
```shell
fc-cache -f
```

</details>
<details>
<summary><h3>Neovim</h3></summary>

The Neovim setup is a LazyVim config with custom functions migrated from `vimrc`. Link the whole `nvim` directory.

```shell
ln -s ~/dotfiles/nvim ~/.config/nvim
```

On first launch, lazy.nvim will install all plugins pinned in `lazy-lock.json`.

#### Syncing Neovim plugins across machines

Plugin versions are pinned in `nvim/lazy-lock.json`, which is tracked in this repo. To keep machines in sync:

- Run `:Lazy update` on your **primary machine only**, then commit and push the updated lockfile.
- On all other machines, pull and run `:Lazy restore` to check out the exact pinned commits.

> **Note:** Avoid running `:Lazy update` on more than one machine, or the lockfile will ping-pong between commits.

</details>
<details>
<summary><h3>Agentic skills</h3></summary>

Skills are stored in `skills/<name>/SKILL.md`. To make them work in, for example, opencode, I like to sym link the whole `skills/` dir to opencode's config, so new skills appear automatically.

```shell
ln -s ~/dotfiles/skills ~/.config/opencode/skills
```

Included skills:

- `system-health-check` — I use this skill to conduct read-only health check and log-spam scan for Ubuntu/Debian systemd machines. It detects available tooling and hardware, ranks findings by severity, and writes a dated report for later reference.

</details>
