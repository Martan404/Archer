#
# /etc/bash.bash_aliases
#

# Repair GRUB
grub-update() { grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck; grub-mkconfig -o /boot/grub/grub.cfg; }
grub-repair() { pacman --noconfirm -S grub efibootmgr; grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck; grub-mkconfig -o /boot/grub/grub.cfg; }
alias grub-rescue='grub-repair'

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
