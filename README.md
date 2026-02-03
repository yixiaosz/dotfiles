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