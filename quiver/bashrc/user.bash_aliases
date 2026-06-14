#
# ~/.bash_aliases
#

archer-help() {
    grep '^[[:alnum:]-]*()' ~/.bash_aliases | awk -F'[(]' '{print $1}'
    grep "^alias" ~/.bash_aliases | awk -F= '{sub("^alias[ \t]*", ""); print $1}'
}

alias update='topgrade -y || (paru -Sy --needed --noconfirm archlinux-keyring; paru -Syu; flatpak update; pipx upgrade-all)'
alias sudo-password-unlock='faillock --user $USER --reset'
alias pacman-refresh-mirrors='sudo reflector --age 48 --country "$(curl ifconfig.co/country-iso)" --fastest 5 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist'
alias pacman-clean-orphan-packages='sudo pacman -Rns $(pacman -Qtdq)'
alias paru-cache-cleanup='paru -Scd'

alias logout="shopt -q login_shell && logout || qdbus org.kde.ksmserver /KSMServer logout 0 0 1"

update-mirror-list() {
    sudo true || return
    country_iso=$(curl ifconfig.co/country-iso)
    case "$1" in
        arch)
            sudo rate-mirrors --allow-root --entry-country="$country_iso" --save=/etc/pacman.d/mirrorlist arch && sudo pacman -Syy
            ;;
        chaotic-aur)
            sudo rate-mirrors --allow-root --entry-country="$country_iso" --save=/etc/pacman.d/chaotic-mirrorlist chaotic-aur && sudo pacman -Syy
            ;;
        cachyos)
            sudo cachyos-rate-mirrors && sudo pacman -Syy
            ;;
        *)
            if pacman -Q cachyos-mirrorlist &>/dev/null; then
                echo "Rating CachyOS and Arch mirrors"
                sudo cachyos-rate-mirrors
                echo "Rating Chaotic-AUR mirrors"
                sudo rate-mirrors --allow-root --entry-country="$country_iso" --save=/etc/pacman.d/chaotic-mirrorlist chaotic-aur
            else
                echo "Rating Arch mirrors"
                sudo rate-mirrors --allow-root --entry-country="$country_iso" --save=/etc/pacman.d/mirrorlist arch
                echo "Rating Chaotic-AUR mirrors"
                sudo rate-mirrors --allow-root --entry-country="$country_iso" --save=/etc/pacman.d/chaotic-mirrorlist chaotic-aur
            fi
            sudo pacman -Syy
            ;;
    esac
}

# Fix unmountable ntfs partitions
ntfs-fix-partition() { sudo ntfsfix --clear-dirty --clear-bad-sectors "$1"; }

grub-update() {
    sudo true || return
    sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}
grub-repair() {
    sudo true || return
    sudo pacman --noconfirm -S grub efibootmgr
    sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}
alias grub-rescue='grub-repair'

paru-repair() {
    git clone https://aur.archlinux.org/paru-git.git
    cd paru-git || return
    makepkg -si
    cd ..
    rm -rf ./paru-git
}

pacman-fix-keys() {
    sudo true || return
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

arch-maintain() {
    sudo true || return
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
    echo -e "Checking ~/.config size"
    du -sh "$HOME"/.config
}
