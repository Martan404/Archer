
# Get aliases
[ -f /etc/bash.bash_aliases ] && source /etc/bash.bash_aliases

# Prompt style - generated from https://bash-prompt-generator.org/
PS1='[\[\e[38;5;39m\]\u\[\e[38;5;245m\]@\[\e[38;5;33m\]\h\[\e[0m\] \[\e[38;5;64m\]\W\[\e[0m\]]$ '

# Color style - https://github.com/sharkdp/vivid
export LS_COLORS=$(vivid generate solarized-dark)

# Add pipx to PATH
eval "$(register-python-argcomplete pipx)"
