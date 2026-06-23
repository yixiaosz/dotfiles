# Advanced tab-autocompletion (added on 2/1/2026)
autoload -Uz compinit
compinit

# My custom welcome text
print "👋 Welcome back, $USER."
print "🖥️ Terminal size: $(stty size | awk '{print $1"×"$2}')" 2>/dev/null
print "🔧 Custom functions: tlpfix, ssh-host, tmux-init, fzfvim"
fortune -s

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

# Path to Kimi Code
export PATH="$HOME/.kimi-code/bin:$PATH"

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
    zsh-autosuggestions
    ssh-agent
    colored-man-pages
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
fzfvim() {
    local file="$(fzf)"
    if [[ -n "$file" ]]; then
        command vim "$file"
    fi
}

# ssh-host: adjusts mac sleep mode settings (for SSH)
ssh-host() {
    echo "SSH Host Mode Settings"
    echo "1) Enable SSH host mode (prevent sleep on AC power only)"
    echo "2) Disable SSH host mode (restore normal sleep)"
    echo "3) Check current power settings"
    echo "q) Quit"
    echo ""
    printf "Select option: "
    read -r choice

    case "$choice" in
        1)
            echo "Enabling SSH host mode for AC power only..."
            # AC (-c): never idle-sleep, no hibernation, no standby
            sudo pmset -c sleep 0 hibernatemode 0 standby 0 powernap 0
            # Battery (-b): restore normal laptop behavior (safe sleep, standby)
            sudo pmset -b sleep 1 hibernatemode 3 standby 1 powernap 1
            # CRITICAL: make sure the global disablesleep flag is OFF
            sudo pmset -a disablesleep 0
            echo "Done. Sleep is now disabled only while plugged in."
            ;;
        2)
            echo "Disabling SSH host mode..."
            # Restore defaults for both AC and battery
            sudo pmset -c sleep 1 hibernatemode 3 standby 1 powernap 1
            sudo pmset -b sleep 1 hibernatemode 3 standby 1 powernap 1
            sudo pmset -a disablesleep 0
            echo "Done."
            ;;
        3)
            pmset -g custom
            ;;
        q|Q|"")
            return 0
            ;;
        *)
            echo "Invalid option: $choice"
            return 1
            ;;
    esac
}

# tlpfix: fixes or checks TLP running status on Linux
tlpfix() {
    echo "TLP Fix Options - Linux only"
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

# tmux-init: get tmux ready in one line
tmux-init() {
    local session="main"

    # Attach if session already exists
    if tmux has-session -t "$session" 2>/dev/null; then
        tmux attach -t "$session"
        return
    fi

    # Create new session with first window
    tmux new-session -d -s "$session" -n homepage

    # Add remaining windows
    tmux new-window -t "$session" -n extra1
    tmux new-window -t "$session" -n extra2
    tmux new-window -t "$session" -n ssh

    # Switch to homepage window and attach
    tmux select-window -t "$session:0"
    tmux attach -t "$session"
}
