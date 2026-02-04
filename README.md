# Yixiao's Dotfiles

## Installation

Clone the repository:

```shell
git clone https://github.com/yixiaosz/dotfiles.git
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

My zsh uses oh-my-zsh to manage my plugins. Make sure you check out the `plugin=()` section in the `zshrc` and install the included plugins. 
