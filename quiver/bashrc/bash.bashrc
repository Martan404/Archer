
[ -f /etc/bash.bash_aliases ] && source /etc/bash.bash_aliases

# Prompt style - generated from https://bash-prompt-generator.org/
PS1='[\[\e[38;5;39m\]\u\[\e[38;5;245m\]@\[\e[38;5;33m\]\h\[\e[0m\] \[\e[38;5;64m\]\W\[\e[0m\]]$ '

# Color style - https://github.com/sharkdp/vivid
export LS_COLORS=$(vivid generate solarized-dark)

# Bash completion
[[ -r /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion

# Cycle in autocomplete
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

# Partially search in history
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Add pipx to PATH
eval "$(register-python-argcomplete pipx)"

# Autojump
[[ -r /etc/profile.d/autojump.sh ]] && source /etc/profile.d/autojump.sh

# Enter directory by only typing the name
shopt -s autocd

# Automatically do an ls after each cd
cd() { builtin cd "${1:-~}" && ls; }

# Check why a package is installed
why() { pacman -Qi $1; }
