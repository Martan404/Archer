#
# ~/.bash_aliases
#

archer-help() {
    {
        grep '^[[:alnum:]-]*()' /etc/bash.bash_aliases | awk -F'[(]' '{print $1}'
        grep "^alias" /etc/bash.bash_aliases | awk -F= '{sub("^alias[ \t]*", ""); print $1}'
    } | sort
}

# Automatically do an ls after each cd
cd() { builtin cd "${1:-~}" && ls -a; }

# Shortcuts
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Color
alias ls='ls --color=auto'
alias ll='ls -ahlF --color=auto'
alias la='ls -A --color=auto'
alias dir='dir --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'
alias grep='grep --color=auto'
alias vdir='vdir --color=auto'
alias wget='wget -c'
