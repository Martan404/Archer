# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Prevent doublesourcing
if [[ -z "${BASHRCSOURCED}" ]] ; then
  BASHRCSOURCED="Y"
  # the check is bash's default value
  [[ "$PS1" = '\s-\v\$ ' ]] && PS1='[\u@\h \W]\$ '
  case ${TERM} in
    Eterm*|alacritty*|aterm*|foot*|gnome*|konsole*|kterm*|putty*|rxvt*|tmux*|xterm*)
      PROMPT_COMMAND+=('printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"')
      ;;
    screen*)
      PROMPT_COMMAND+=('printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"')
      ;;
  esac
fi

# Bash completion
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  . /usr/share/bash-completion/bash_completion
fi

# Get aliases
[ -f /etc/bash.bash_aliases ] && source /etc/bash.bash_aliases

# Prompt style - generated from https://bash-prompt-generator.org/
PS1='[\[\e[38;5;39m\]\u\[\e[38;5;245m\]@\[\e[38;5;33m\]\h\[\e[0m\] \[\e[38;5;64m\]\W\[\e[0m\]]$ '

# Color style - https://github.com/sharkdp/vivid
export LS_COLORS=$(vivid generate solarized-dark)

# Cycle in autocomplete
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

# Partially search in history
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Autojump
[[ -r /etc/profile.d/autojump.sh ]] && source /etc/profile.d/autojump.sh

# Add pipx to PATH
eval "$(register-python-argcomplete pipx)"

# Enter directory by only typing the name
shopt -s autocd

# Automatically do an ls after each cd
cd() { builtin cd "${1:-~}" && ls; }

# Check why a package is installed
why() { pacman -Qi $1; }
