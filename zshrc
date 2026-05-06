# Advanced tab-autocompletion (added on 2/1/2026)
autoload -Uz compinit
compinit


# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Path to default terminal emulator
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    export TERMINAL="alacritty"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    export TERMINAL="ghostty"
fi

# Prepend hostname (red) only when connected via SSH
if [[ -n "$SSH_CONNECTION" ]] || [[ -n "$SSH_CLIENT" ]]; then
    PROMPT='%{$fg[red]%}%m%{$reset_color%} '$PROMPT
fi

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ZSH_THEME="ys"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    ZSH_THEME="robbyrussell"
fi


# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="mm/dd/yyyy"

# Command history settings (added on 2/1/2026)
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY # don't overwrite the history file
setopt SHARE_HISTORY # share history between terminals

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

# 3/24/2026: Specify SSH key names
zstyle :omz:plugins:ssh-agent identities id_ed25519

plugins=(
    git
    zsh-autosuggestions
    ssh-agent
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Load local configurations if exists
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# Load the brew-installed python in macOS
if (( $+commands[brew] )); then
    export PATH="$(brew --prefix python@3.14)/libexec/bin:$PATH"
fi

# Vim + fzf shortcut
vim() {
    if [[ "$1" == "fzf" ]]; then
        # run fzf and store the result
        local file="$(fzf)"
        # if a file's select, open it with vim
        if [[ -n "$file" ]]; then
            command vim "$file"
        fi
    else
        # otherwise just run vim in regular way
        command vim "$@"
    fi
}

# Alias for adjusting sleep mode settings (for SSH)
alias sshhost='sudo pmset -a sleep 0 hibernatemode 0 disablesleep 1 standby 0 powernap 0'
alias sshhost-off='sudo pmset -a sleep 1 hibernatemode 3 disablesleep 0 standby 1 powernap 1'

# TLP privilege fix - quick branching menu
tlpfix() {
    echo "TLP Fix Options:"
    echo "  [1] Enable & start TLP services"
    echo "  [2] Check service status & diagnostics"
    echo "  [q] Quit"
    echo ""
    printf "Choose: "
    read choice

    case "$choice" in
        1)
            echo "→ Enabling TLP services..."
            sudo systemctl enable tlp.service
            echo "→ Starting TLP..."
            sudo systemctl start tlp.service
            sudo tlp start
            echo "→ Run 'sudo vim /etc/tlp.conf' to edit charging threshold."
            echo "✓ Done. Run 'tlpfix' then [2] to verify."
            ;;
        2)
            echo "→ TLP service status:"
            sudo systemctl status tlp --no-pager
            echo ""
            echo "→ TLP diagnostics:"
            sudo tlp-stat -s
            echo ""
            echo "→ Config check:"
            sudo tlp-stat -c 2>&1 | head -20
            ;;
        q|Q)
            echo "Cancelled."
            return 0
            ;;
        *)
            echo "Invalid option. Use 1, 2, or q."
            return 1
            ;;
    esac
}

