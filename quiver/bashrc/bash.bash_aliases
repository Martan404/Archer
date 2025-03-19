#
# /etc/bash.bash_aliases
#

# Repair GRUB
grub-update() { grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck; grub-mkconfig -o /boot/grub/grub.cfg; }
grub-repair() { pacman --noconfirm -S grub efibootmgr; grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck; grub-mkconfig -o /boot/grub/grub.cfg; }
alias grub-rescue='grub-repair'

flatpak-clean-nvidia() {
    LATEST_NVIDIA=$(flatpak list | grep "GL.nvidia" | cut -f2 | cut -d '.' -f5)

    flatpak list | grep org.freedesktop.Platform.GL32.nvidia- | cut -f2 | grep -v "$LATEST_NVIDIA" | xargs -o flatpak uninstall

    flatpak repair
    flatpak update

    flatpak uninstall --unused --delete-data
    flatpak remove --unused --delete-data
}

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
