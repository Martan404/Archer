#
# ~/.bash_aliases
#

archer-help() {
    grep '^[[:alnum:]-]*()' ~/.bash_aliases | awk -F'[(]' '{print $1}'
    grep "^alias" ~/.bash_aliases | awk -F= '{sub("^alias[ \t]*", ""); print $1}'
}

alias update='paru -Syu && pipx --global upgrade-all'
alias package-cache-cleanup='paru -Scd'
alias sudo-password-unlock='faillock --user $USER --reset'
alias pacman-refresh-mirrors='sudo reflector --age 48 --country "$(curl ifconfig.co/country-iso)" --fastest 5 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist'
alias pacman-db-unlock='sudo rm /var/lib/pacman/db.lck'
alias pacman-clean-orphan-packages='sudo pacman -Rns $(pacman -Qtdq)'

alias last-boot-log='journalctl -b -1 -r'
alias last-boot-log-systemd-user='journalctl --user -b -1 -u init.scope --since 00:00 -g Stop --no-pager'
alias last-boot-log-systemd-root='journalctl -b -1 -u init.scope --since 00:00 -g Stop --no-pager'

alias windows-boot='sudo windows-boot'
alias logout="shopt -q login_shell && logout || qdbus org.kde.ksmserver /KSMServer logout 0 0 1"

gitui() {
    key="${1:-$HOME/.ssh/YOUR-SSH-KEY}"
    eval "$(ssh-agent)"
    ssh-add "$key" 
    command gitui "${@:2}" 
    eval "$(ssh-agent -k)"
}

# Fix unmountable ntfs partitions
ntfs-fix-partition() { sudo ntfsfix --clear-dirty --clear-bad-sectors "$1"; }

grub-update() {
    sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}
grub-repair() {
    sudo pacman --noconfirm -S grub efibootmgr
    sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}
alias grub-rescue='grub-repair'

pacman-fix-keys() {
    echo -e "Refresh keys"
    sudo pacman-key --refresh-keys
    echo -e "Updating archlinux-keyring"
    sudo pacman -Sy archlinux-keyring
    echo -e "Initialize pacman keys"
    sudo pacman-key --init
    echo -e "Populating keyring"
    sudo pacman-key --populate
    echo -e "Updating pacman databases"
    sudo pacman -Sy
    echo -e "Refreshing mirror list"
    sudo reflector --age 48 --country "$(curl ifconfig.co/country-iso)" --fastest 5 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
    echo -e "Updating system"
    sudo pacman -Syu
}
export -f pacman-fix-keys

arch-maintain() {
    sudo echo "" >/dev/null
    echo -e "Checking for failed systemd services"
    systemctl --failed
    echo -e "Checking log files"
    sudo timeout 3s journalctl -p 3 -xb -f
    echo -e "Cleaning log files"
    sudo journalctl --vacuum-time=1day
    sudo journalctl --flush --rotate
    echo -e "Refreshing pacman mirrors"
    sudo reflector --age 48 --country "$(curl ifconfig.co/country-iso)" --fastest 5 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
    echo -e "Updating system"
    sudo pacman -Syu
    echo -e "Removing orphaned packages"
    sudo pacman -Rns "$(pacman -Qtdq)"
    echo -e "Removing cached packages"
    paccache -rvuk0
    echo -e "Removing cached AUR packages"
    paru --clean
    echo -e "Cleaning ~/.cache"
    rm -rf "$HOME"/.cache/*
    echo -e "Checking ~/.config/ size"
    du -sh "$HOME"/.config/
}
export -f arch-maintain
