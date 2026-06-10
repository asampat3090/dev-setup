# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes.
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# --- Tool-managed sections below ---
# These will be re-added by installers (conda init, nvm, docker, etc.)
# Do not include machine-specific paths in the repo version.

# NVM (will be added by nvm installer)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# >>> conda initialize >>>
for _conda_prefix in "$HOME/anaconda3" "$HOME/miniconda3" "/opt/homebrew/anaconda3" "/opt/homebrew/Caskroom/miniconda/base" "/usr/local/anaconda3"; do
    if [ -x "$_conda_prefix/bin/conda" ]; then
        __conda_setup="$("$_conda_prefix/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__conda_setup"
        else
            [ -f "$_conda_prefix/etc/profile.d/conda.sh" ] && . "$_conda_prefix/etc/profile.d/conda.sh"
        fi
        unset __conda_setup
        break
    fi
done
unset _conda_prefix
# <<< conda initialize <<<

