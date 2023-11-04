#!/usr/bin/env bash
# shellcheck disable=SC2002,SC2164

# Import variables from first script
archer_logo=${1}
user=${2}
hostname=${3}
snapshot_layout=${4}
cpu_manufacturer=${5}
gpu_manufacturer=${6}
snapshot_subvol=${7}
root_partition=${8}
snap_manager=${9}

package_installer() {
	input_packages=$1

	# Check if argument is .txt file and combine each line
    if [[ "$input_packages" == *.txt ]]; then
		packages=$(cat "$input_packages" | tr '\n' ' ')
		rm "$input_packages"
	else
		packages=$input_packages
	fi

    while true; do
        # shellcheck disable=SC2086
        sudo -u $user paru -S --needed --noconfirm $packages && break
    	echo "$(tput setaf 9)Package installation failed. Retrying...$(tput sgr0)"
	done
}

setup_system() {

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling multilib repository"

	sed -i 's/^#\[multilib\]/\[multilib\]/' /etc/pacman.conf
	sed -i '/^\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling parallel downloads"

	sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling pacman hooks"

	sed -i 's/^#HookDir/HookDir/' /etc/pacman.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Adding candy to pacman"

	sed -i '/^ParallelDownloads = .*/a ILoveCandy' /etc/pacman.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Updating pacman databases"

	pacman -Syu --noconfirm
}

config_system() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting time zone"

	ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime

	echo -e "-------------------------------------------------------------------------"
	echo -e "Generating /etc/adjtime"

	hwclock --systohc

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling English and Swedish locale"

	sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
	sed -i 's/^#sv_SE.UTF-8/sv_SE.UTF-8/' /etc/locale.gen
	locale-gen

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting system locale"
	{
		echo "LANG=sv_SE.UTF-8"
		echo "LC_MESSAGES=en_US.UTF-8"
	} >> /etc/locale.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting default keyboard layout to Swedish"

	echo "KEYMAP=sv-latin1" >> /etc/vconsole.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting hostname to $hostname"

	echo "$hostname" >> /etc/hostname

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring /etc/hosts"
	{
		echo "127.0.0.1		localhost		$hostname"
		echo "::1			localhost ip6-localhost ip6-loopback"
		echo "ff02::1       ip6-allnodes"
		echo "ff02::2       ip6-allrouters"
	} >> /etc/hosts

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling btrfs module in mkinitcpio.conf"

	sed -i 's/^MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Rebuilding the initramfs image"

	mkinitcpio -P

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting up sudo permissions for wheel group"

	sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

	echo -e "-------------------------------------------------------------------------"
	echo -e "Temporarily removing password requirement for wheel group"

	sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating $user user account"

	groupadd -f git
	useradd -m -G sys,wheel,rfkill,git -s /bin/bash "$user"
}

setup_paru_pipx() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing Paru AUR helper"

	while true; do
        # shellcheck disable=SC2086
        pacman -S --needed --noconfirm git rust cmake && break
    	echo "$(tput setaf 9)Package installation failed. Retrying...$(tput sgr0)"
	done
	
	cd /home/"$user"/
	sudo -u "$user" git clone https://aur.archlinux.org/paru-bin.git
	cd paru-bin

	while true; do
		sudo -u "$user" makepkg -si --needed --noconfirm && break

    	echo "$(tput setaf 9)Paru installation failed. Retrying...$(tput sgr0)"
	done
	
	paru -Syu
	cd .. && rm -rf paru-bin/ && cd /
	
	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing Python pipx"

	package_installer "python-pipx"
}

install_packages() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing driver packages"

	package_installer "/drivers.txt"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing KDE Plasma desktop environment"

	package_installer "/kde.txt"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing system packages"

	package_installer "/system.txt"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing pacman packages"

	package_installer "/pacman.txt"

	if [[ $cpu_manufacturer == "intel" ]]; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Installing and enabling thermald service for Intel CPU"

		package_installer "thermald"
		systemctl enable thermald.service
	fi
}

config_packages() {
	if ! pacman -Qs steam > /dev/null; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Installing steam-devices package for Steam Flatpak"
	
		package_installer "steam-devices" 
	fi

	if pacman -Qs firefox > /dev/null; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Generating Firefox profiles"

		sudo -u "$user" firefox -headless &
		read -r -t 1

		# shellcheck disable=SC2009
		for pid in $(ps -ef | grep "firefox -headless" | awk '{print $2}'); do kill -9 "$pid"; done

		echo -e "-------------------------------------------------------------------------"
		echo -e "Importing Betterfox user.js"

		cd /home/"$user"/.mozilla/firefox/*default-release/
		mv /Archer-main/quiver/betterfox-user.js ./user.js
		chown "$user":"$user" ./user.js
		cd /
	fi

	if pacman -Qs discord > /dev/null; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Set Discord to use local credentials"

		sed -i 's/Exec=\/usr\/bin\/discord/Exec=\/usr\/bin\/discord --password-store=basic/' /opt/discord/discord.desktop

		echo -e "-------------------------------------------------------------------------"
		echo -e "Removing Discord update check"

		sudo -u "$user" mkdir -p /home/"$user"/.config/discord
		sudo -u "$user" touch /home/"$user"/.config/discord/settings.json

		cat <<-END > /home/"$user"/.config/discord/settings.json
{
  "IS_MAXIMIZED": false,
  "IS_MINIMIZED": false,
  "SKIP_HOST_UPDATE": true,
  "WINDOW_BOUNDS": {
    "x": 40,
    "y": 40,
    "width": 940,
    "height": 570
  }
}
END
	fi
}

setup_plasma() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling automatic D-Bus activation for KWallet"

	cat <<-END >> /usr/share/dbus-1/services/org.freedesktop.secrets.service
[D-BUS Service]
Name=org.freedesktop.secrets
Exec=/usr/bin/kwalletd5
END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing konsave"

	export PATH=$PATH:/home/$user/.local/bin

	sudo -u "$user" pipx install konsave

	mv /Archer-main/quiver/archer.knsv /home/"$user"/archer.knsv

	echo -e "-------------------------------------------------------------------------"
	echo -e "Writing Plasma setup script"

	sudo -u "$user" mkdir -p /home/"$user"/.config/plasma-workspace/env
	sudo -u "$user" touch /home/"$user"/.config/plasma-workspace/env/setup_plasma.sh

	cat <<-END >> /home/"$user"/.config/plasma-workspace/env/setup_plasma.sh
#!/usr/bin/env bash
echo -ne "$archer_logo"
echo -e "
		                   Plasma setup script
-------------------------------------------------------------------------"
echo -e "Importing and applying konsave settings"

export PATH=\$PATH:/home/$user/.local/bin

sudo -u $user konsave -i /home/$user/archer.knsv
sleep 1
sudo -u $user konsave -a archer


echo -e "-------------------------------------------------------------------------"
echo -e "Setting Dolphin state"

sudo -u $user mkdir -p /home/$user/.local/share/dolphin
sudo -u $user touch /home/$user/.local/share/dolphin/dolphinstaterc

cat <<-EOF > /home/$user/.local/share/dolphin/dolphinstaterc
[State]
State=AAAA/wAAAAD9AAAAAwAAAAAAAACmAAAB0/wCAAAAAvsAAAAWAGYAbwBsAGQAZQByAHMARABvAGMAawAAAAAuAAAA7AAAAAoBAAAD+wAAABQAcABsAGEAYwBlAHMARABvAGMAawEAAAAuAAAB0wAAAF0BAAADAAAAAQAAALgAAAHn/AIAAAAB+wAAABAAaQBuAGYAbwBEAG8AYwBrAAAAAC4AAAHnAAAACgEAAAMAAAADAAAC+AAAAL78AQAAAAH7AAAAGAB0AGUAcgBtAGkAbgBhAGwARABvAGMAawAAAAAAAAAC+AAAAAoBAAADAAACkwAAAdMAAAAEAAAABAAAAAgAAAAI/AAAAAEAAAACAAAAAQAAABYAbQBhAGkAbgBUAG8AbwBsAEIAYQByAQAAAAD/////AAAAAAAAAAA=
EOF

rm -f /home/$user/archer.knsv
rm -f /home/$user/.config/plasma-workspace/env/setup_plasma.sh
END
	chmod a+x /home/"$user"/.config/plasma-workspace/env/setup_plasma.sh
}

setup_laptop() {
echo -e "-------------------------------------------------------------------------"
	echo -e "Installing laptop-detect package"

	package_installer "laptop-detect"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Checking if device is laptop"

	laptop-detect
	laptop_status=$?

	if [ $laptop_status -eq 0 ]; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Installing laptop packages"

		package_installer "auto-cpufreq wireless-regdb"

		systemctl mask power-profiles-daemon.service
		systemctl enable auto-cpufreq.service

	elif [ $laptop_status -eq 1 ]; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Device not recognized as laptop"

	elif [ $laptop_status -eq 2 ]; then
		laptop-detect -v
	fi

	echo -e "-------------------------------------------------------------------------"
	echo -e "Uninstalling laptop-detect package"
	pacman -Rs --noconfirm laptop-detect
}

remove_orphans() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Removing orphaned packages"

	# shellcheck disable=SC2046
	pacman -Rns --noconfirm $(pacman -Qtdq)
}

setup_grub() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing Grub packages"

	package_installer "grub-btrfs efibootmgr inotify-tools os-prober"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating efibootmgr wrapper script to prevent fail"

	cat <<-END > /usr/local/bin/efibootmgr
#!/bin/sh
exec /usr/bin/efibootmgr -e 3 "\$@"
END
	chmod +x /usr/local/bin/efibootmgr

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring Grub"

	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
	grub-mkconfig -o /boot/grub/grub.cfg


	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling Grub OS prober"

	sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

	echo -e "-------------------------------------------------------------------------"
	echo -e "Removing 'quiet' kernel parameter"

	sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"/' /etc/default/grub

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting kernel boot parameters for CPU"

	if [ "$cpu_manufacturer" = "amd" ]; then
		kernel_parameters=""

	elif [ "$gpu_manufacturer" = "intel" ]; then
		kernel_parameters="intel_iommu=on iommu=pt"
	
	fi; sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\)\(.*\)\"/\1 $kernel_parameters\2\"/" /etc/default/grub
	
	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting kernel boot parameters for GPU"

	if [ "$gpu_manufacturer" = "amd" ]; then
		kernel_parameters=""

	elif [ "$gpu_manufacturer" = "intel" ]; then
		kernel_parameters=""

	elif [ "$gpu_manufacturer" = "nvidia" ]; then
		kernel_parameters="nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"

		echo -e "-------------------------------------------------------------------------"
		echo -e "Enabling support for suspend/wakeup"

		systemctl enable nvidia-suspend.service
		systemctl enable nvidia-hibernate.service
		systemctl enable nvidia-resume.service

	elif [ "$gpu_manufacturer" = "vm" ]; then
		kernel_parameters=""

	fi; sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\)\(.*\)\"/\1 $kernel_parameters\2\"/" /etc/default/grub

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing Grub theme"

	mv /Archer-main/quiver/arch-silence /boot/grub/themes/arch-silence
	sed -i 's/#GRUB_THEME="\/path\/to\/gfxtheme"/GRUB_THEME="\/boot\/grub\/themes\/arch-silence\/theme.txt"/' /etc/default/grub

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling GRUB-btrfsd snapshot daemon"

	systemctl enable grub-btrfsd

	echo -e "-------------------------------------------------------------------------"
	echo -e "Disabling snapshot listing in grub-btrfs"

	sed -i '/^#GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND="false"/s/^#//' /etc/default/grub-btrfs/config

}

backup_kernel() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing rsync"

	package_installer "rsync"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Adding pacman hooks to rsync for kernel backup"

	mkdir /etc/pacman.d/hooks
	mkdir -p /.bootbackup/{preupdate,postupdate}

	cat <<-END > /etc/pacman.d/hooks/95-bootbackup-preupdate.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot before updating...
When = PreTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup/preupdate
END

	cat <<-END > /etc/pacman.d/hooks/95-bootbackup-postupdate.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot after updating...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup/postupdate
END
}

snapper_setup() {
	if [[ $snapshot_layout == "snapper" ]]; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Installing Snapper packages"

		package_installer "snapper snap-pac snap-pac-grub snapper-tools snapper-support"

		echo -e "-------------------------------------------------------------------------"
		echo -e "Creating Snapper root config"

		snapper --no-dbus -c root create-config /

	elif [[ $snapshot_layout == "arch" ]]; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Installing Snapper packages"

		package_installer "snapper snap-pac snap-pac-grub snapper-rollback"

		echo -e "-------------------------------------------------------------------------"
		echo -e "Removing /.snapshots"

		umount /.snapshots
		rm -r /.snapshots

		echo -e "-------------------------------------------------------------------------"
		echo -e "Creating Snapper root config"

		snapper --no-dbus -c root create-config /

		echo -e "-------------------------------------------------------------------------"
		echo -e "Removing snapper /.snapshots subvolume"

		btrfs subvolume delete /.snapshots

		echo -e "-------------------------------------------------------------------------"
		echo -e "Remounting $snapshot_subvol subvolume"

		mount --mkdir -o subvol="$snapshot_subvol" "$root_partition" /.snapshots
		mount -a

		echo -e "-------------------------------------------------------------------------"
		echo -e "Setting new ./snapshots permissions"

		chmod 750 /.snapshots
		chown -R :wheel /.snapshots/
	fi

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring timeline cleanup"

	sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="10"/' /etc/snapper/configs/root
	sed -i 's/^TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
	sed -i 's/^TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
	sed -i 's/^TIMELINE_LIMIT_WEEKLY="10"/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
	sed -i 's/^TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
	sed -i 's/^TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

	echo -e "-------------------------------------------------------------------------"
	echo -e "Adding wheel group to snapper permissions"

	sed -i 's/^ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' /etc/snapper/configs/root

	echo -e "-------------------------------------------------------------------------"
	echo -e "Excluding /.snapshots from updatedb"

	echo "PRUNENAMES = \".snapshots\"" >> /etc/updatedb.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling Snapper Timeline and Cleanup services"

	systemctl enable snapper-timeline.timer
	systemctl enable snapper-cleanup.timer
}

yabsnap_setup() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing Yabsnap"

	package_installer "yabsnap"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating Yabsnap root config"

	yabsnap create-config root

	sed -i 's/source =/source = \//' /etc/yabsnap/configs/root.conf
	sed -i 's/keep_preinstall = 1/keep_preinstall = 6/' /etc/yabsnap/configs/root.conf
	sed -i 's/keep_user = 1/keep_user = 2/' /etc/yabsnap/configs/root.conf
	sed -i 's/keep_preinstall = 1/keep_preinstall = 10/' /etc/yabsnap/configs/root.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Excluding /.snapshots from updatedb"

	echo "PRUNENAMES = \".snapshots\"" >> /etc/updatedb.conf

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling Yabsnap service"

	systemctl enable yabsnap.timer
}

enable_services() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling networkmanager service"

	systemctl enable NetworkManager.service

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling avahi networking"

	systemctl enable avahi-daemon.service

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling fstrim service"

	systemctl enable fstrim.timer

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling pacman cache cleaner service"

	systemctl enable paccache.timer

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling openssh daemon"

	systemctl enable sshd.service

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling sddm display manager"

	systemctl enable sddm.service

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling bluetooth driver"

	systemctl enable bluetooth.service

	echo -e "-------------------------------------------------------------------------"
	echo -e "Rebuilding GRUB configs"

	grub-mkconfig -o /boot/grub/grub.cfg
}

pacman_hooks() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating Grub update hook"

	cat <<-END > /etc/pacman.d/hooks/1-grubupdate.hook
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = grub

[Action]
Description = Grub has been updated
Depends = grub
When = PostTransaction
Exec = echo -e "\e[1mRun\e[34m grub-update\e[0m\e[1m to complete the installation\e[0m"
END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating Package cache cleaner hook"

	cat <<-END > /etc/pacman.d/hooks/91-paccache.hook
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rvk2
Depends = pacman-contrib
END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating Orphaned package notification hook"

	cat <<-END > /etc/pacman.d/hooks/92-orphans.hook
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Checking for orphaned packages...
Depends = pacman
When = PostTransaction
Exec = /usr/bin/bash -c 'orphans=\$(pacman -Qtdq); if [[ -n "\$orphans" ]]; then echo -e "\\e[1mOrphan packages found:\\e[0m\\n\$orphans\\n\\e[1mPlease check and remove any no longer needed\\e[0m"; fi'
END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating .pacnew and .pacsave notification hook"

	cat <<-END > /etc/pacman.d/hooks/93-pacfiles.hook
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Checking for .pacnew and .pacsave files...
When = PostTransaction
Exec = /usr/bin/bash -c 'pacfiles=\$(pacdiff -o); if [[ -n "\$pacfiles" ]]; then echo -e "\\e[1m.pac* files found:\\e[0m\\n\$pacfiles\\n\\e[1mPlease check and merge\\e[0m"; fi'
Depends = pacman-contrib
END
}

system_config() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Adding custom PATH to /etc/profile.d/custom-path.sh"

	echo "export PATH=\$PATH:\$HOME/.local/bin" >> /etc/profile.d/custom-path.sh

	echo -e "-------------------------------------------------------------------------"
	echo -e "Adding sudo password exception to udisk2/mount"

	cat <<-END > /etc/polkit-1/rules.d/10-udisks2.rules
// Allow udisks2 to mount devices without authentication
// for users in the "wheel" group.
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling en_SE locale"	

	mv /Archer-main/quiver/en_SE /usr/share/i18n/locales/en_SE &&
	sed -i '/en_US\.UTF-8/i\en_SE\.UTF-8 UTF-8' /etc/locale.gen &&
	echo "LANG=en_SE.UTF-8" > /etc/locale.conf

	locale-gen

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting X11 keyboard layout"

	cat <<-END > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
			Identifier "system-keyboard"
			MatchIsKeyboard "on"
			Option "XkbLayout" "se"
ENDSection
END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting SDDM theme"

	mkdir -p /etc/sddm.conf.d/
	cat <<-END > /etc/sddm.conf.d/kde_settings.conf
[Theme]
Current=breeze
END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating Windows boot script"
	cat <<-END >> /usr/local/bin/windows-boot
#! /bin/bash
# Set Windows Boot Manager as NextBoot and reboots
efibootmgr -n \$(efibootmgr | awk '/Windows Boot Manager/ {gsub(/^Boot/, "", \$1); gsub(/\*/, "", \$1); print \$1}') && reboot
END
	chmod +x /usr/local/bin/windows-boot

	echo -e "-------------------------------------------------------------------------"
	echo -e "Adding sudo password exception to Windows boot script"

	echo "%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/windows-boot" >> /etc/sudoers

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting up XDG user directories"

	xdg-user-dirs-update

	sed -i '/TEMPLATES/s/^/#/' /etc/xdg/user-dirs.defaults
	sed -i '/PUBLICSHARE/s/^/#/' /etc/xdg/user-dirs.defaults

	cat <<-END >> /etc/xdg/user-dirs.defaults
APPLICATIONS=Applications
GAMES=Games
PROJECTS=Projects
SYNC=Sync
END
}

user_config() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating home sub-directories for $user"

	sudo -u "$user" xdg-user-dirs-update --force

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating System sub-directory for $user"

	sudo -u "$user" mkdir -p /home/"$user"/System/{icons,scripts}

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting sub-directory icons"

	sudo -u "$user" touch /home/"$user"/{Applications,Games,Projects,Sync,System}/.directory
	{
	echo "[Desktop Entry]"
	echo "Icon=folder-flatpak"
	} >> /home/"$user"/Applications/.directory
	{
	echo "[Desktop Entry]"
	echo "Icon=folder-games"
	} >> /home/"$user"/Games/.directory
	{
	echo "[Desktop Entry]"
	echo "Icon=folder-script"
	} >> /home/"$user"/Projects/.directory
	{
	echo "[Desktop Entry]"
	echo "Icon=folder-cloud"
	} >> /home/"$user"/Sync/.directory
	{
	echo "[Desktop Entry]"
	echo "Icon=folder-build" 
	} >> /home/"$user"/System/.directory
}

bash_config() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring /etc/bash.bashrc"

	sed -i '/PS1/d' /etc/bash.bashrc

	cat <<-END >> /etc/bash.bashrc
[ -f /etc/bash.bash_aliases ] && source /etc/bash.bash_aliases

# Prompt style - generated from https://bash-prompt-generator.org/
PS1='[\[\e[38;5;39m\]\u\[\e[38;5;245m\]@\[\e[38;5;33m\]\h\[\e[0m\] \[\e[38;5;64m\]\W\[\e[0m\]]$ '

# Color style - https://github.com/sharkdp/vivid
export LS_COLORS=\$(vivid generate solarized-dark)

# ble.sh
[[ -r /usr/share/blesh/ble.sh ]] && [[ \$- == *i* ]] && source /usr/share/blesh/ble.sh

# Bash completion
[[ -r /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion

# Cycle in autocomplete
bind "set completion-ignore-case on"
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

# Partially search in history
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Autojump
[[ -r /etc/profile.d/autojump.sh ]] && source /etc/profile.d/autojump.sh

# Add pipx to PATH
eval "\$(register-python-argcomplete pipx)"

# Enter directory by only typing the name
shopt -s autocd

# Automatically do an ls after each cd
cd() { builtin cd "\${1:-~}" && ls; }

# Check why a package is installed
why() { pacman -Qi \$1; }

END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring /etc/bash.bash_aliases"

	cat <<-END >> /etc/bash.bash_aliases
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

END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring /home/$user/.bashrc"

	cat <<-END >> /home/"$user"/.bashrc
# Check /etc/bash.bashrc for more configuration
[[ -r ~/.bash_aliases ]] && source ~/.bash_aliases
[[ -r ~/.distrobox_bash ]] && source ~/.distrobox_bash # Just source the system bashrc like systemctl info from github

# Add ~/System/scripts to PATH
[[ -d "\$HOME/System/scripts" ]] && export PATH=\$PATH:\$HOME/System/scripts

# Display system information
neofetch --ascii_distro arch_small --colors 4 7 4 4 7 7 --ascii_colors 4 4 --disable title underline distro shell resolution de wm wm_theme theme icons term term_font

END
	chown "$user":"$user" /home/"$user"/.bashrc

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring /home/$user/.bash_aliases"

	cat <<-END >> /home/"$user"/.bash_aliases
alias neofetch='neofetch --colors 4 7 4 4 7 7 --ascii_colors 4 4'

alias last-boot-log='journalctl -b -1 -r'
alias windows-boot='sudo windows-boot'
alias logout="shopt -q login_shell && logout || qdbus org.kde.ksmserver /KSMServer logout 0 0 1"

alias update='paru -Syu'
alias package-cache-cleanup='paru -Scd'
alias sudo-password-unlock='faillock --user \$USER --reset'
alias pacman-refresh-mirrors='sudo reflector --age 48 --country "\$(curl ifconfig.co/country-iso)" --fastest 5 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist'
alias pacman-db-unlock='sudo rm /var/lib/pacman/db.lck'

# Fix unmountable ntfs partitions
ntfs-fix-partition() { sudo ntfsfix -d \$1; }

grub-update() { sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck; sudo grub-mkconfig -o /boot/grub/grub.cfg; }

grub-rebuild() { sudo grub-mkconfig -o /boot/grub/grub.cfg; }

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
sudo reflector --age 48 --country "\$(curl ifconfig.co/country-iso)" --fastest 5 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
echo -e "Updating system"
sudo pacman -Syu
}; export -f pacman-fix-keys

arch-maintain() {
sudo echo "" > /dev/null
echo -e "Checking for failed systemd services"
systemctl --failed
echo -e "Checking log files"
sudo timeout 3s journalctl -p 3 -xb -f
echo -e "Cleaning log files"
sudo journalctl --vacuum-time=1day
sudo journalctl --flush --rotate
echo -e "Refreshing pacman mirrors"
sudo reflector --age 48 --country "\$(curl ifconfig.co/country-iso)" --fastest 5 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
echo -e "Updating system"
sudo pacman -Syu
echo -e "Removing orphaned packages"
sudo pacman -Rns \$(pacman -Qtdq)
echo -e "Removing cached packages"
paccache -rvuk0
echo -e "Removing cached AUR packages"
paru --clean
echo -e "Cleaning user ~/.cache"
rm -rf $HOME/.cache/*
echo -e "Checking ~/.config/ size"
du -sh $HOME/.config/
}; export -f arch-maintain

END
chown "$user":"$user" /home/"$user"/.bash_aliases

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating ble.sh configuration file"

	cat <<-END >> /home/"$user"/.blerc
# https://github.com/akinomyoga/ble.sh/blob/master/blerc.template
bleopt editor=micro
bleopt exec_errexit_mark=

END
	chown "$user":"$user" /home/"$user"/.blerc
}

setup_flatpak() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling Flatpak theming"

	if pacman -Qs flatpak > /dev/null; then

		flatpak override --filesystem=xdg-config/{Kvantum,gtkrc,gtkrc-2.0,gtk-3.0,gtk-4.0}
		flatpak override --filesystem={~/.themes,~/.icons,~/.fonts,~/.local/share/themes}
	fi

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting Lutris Flatpak theming"
		
	flatpak override net.lutris.Lutris --env=GTK_THEME=Breeze

	echo -e "-------------------------------------------------------------------------"
	echo -e "Moving Betterfox user.js"

	chown "$user":"$user" /Archer-main/quiver/betterfox-user.js
	mv /Archer-main/quiver/betterfox-user.js /home/"$user"/.user.js

	echo -e "-------------------------------------------------------------------------"
	echo -e "Writing Flatpak install desktop entry"

	sudo -u "$user" mkdir -p /home/"$user"/.config/autostart/
	sudo -u "$user" touch /home/"$user"/.config/autostart/flatpak-setup.desktop
	
	cat <<EOF >> /home/"$user"/.config/autostart/flatpak-setup.desktop
[Desktop Entry]
Exec=konsole -e /home/martin/System/scripts/flatpak-setup
Icon=/usr/share/pixmaps/archlinux-logo.png
StartupNotify=true
Type=Application
EOF

	echo -e "-------------------------------------------------------------------------"
	echo -e "Writing Flatpak install script"

	# shellcheck disable=SC2002
	packages=$(cat "/flatpak.txt" | tr '\n' ' ') && rm /flatpak.txt
	
	sudo -u "$user" touch /home/"$user"/System/scripts/flatpak-setup
	cat <<EOF >> /home/"$user"/System/scripts/flatpak-setup
#!/bin/bash
show_logo() {
	clear
	echo -ne "$archer_logo"
	echo -e "
                         Flatpak install script
-------------------------------------------------------------------------"
}

install_flatpak() {
	while ! ping -q -c 1 -W 1 archlinux.org > /dev/null 2>&1; do
    	echo "Waiting for internet connection..."
		sleep 10
	done

    while true; do
		flatpak install flathub -y --noninteractive $packages && break
    	echo "\$(tput setaf 9)Package installation failed. Retrying...\$(tput sgr0)"
	done

	if [[ \$(flatpak list) == *"com.github.GradienceTeam.Gradience"* ]]; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Setting Adwaita color to match Breeze Dark"

		mkdir -p "/home/$user/.var/app/com.github.GradienceTeam.Gradience/config/presets/curated"

		flatpak run --command=gradience-cli com.github.GradienceTeam.Gradience download -n "Breeze Dark"
		flatpak run --command=gradience-cli com.github.GradienceTeam.Gradience apply -n "Breeze Dark" --gtk both
	
		flatpak remove -y --noninteractive com.github.GradienceTeam.Gradience
	fi

	if [[ \$(flatpak list) == *"org.mozilla.firefox"* ]]; then
		
		flatpak run org.mozilla.firefox --headless &
		read -r -t 1
		flatpak kill org.mozilla.firefox

		echo -e "-------------------------------------------------------------------------"
		echo -e "Moving Betterfox user.js to Firefox"

		cd /home/$user/.var/app/org.mozilla.firefox/.mozilla/firefox/*default-release/
		mv /home/$user/.user.js ./user.js
		cd /
		
	else
		rm -f /home/$user/.user.js
	fi

	echo -e "-------------------------------------------------------------------------"
	read -r -t 5 -p "Rebooting in 5 seconds..."

	rm -f /home/$user/.config/autostart/flatpak-setup.desktop
	rm -f \${BASH_SOURCE[0]}
	reboot
}

show_logo
install_flatpak
EOF
	chmod a+x /home/"$user"/System/scripts/flatpak-setup
}

snapshot_rollback() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Writing Snapshot rollback script"

	if [[ $snapshot_layout == "snapper" ]]; then
		snapshot_path="\$snaphot_number/snapshot"

	elif [[ $snapshot_layout == "arch" ]] && [[ $snap_manager == "snapper" ]]; then
		snapshot_path="\$snaphot_number/snapshot"

	elif [[ $snapshot_layout == "arch" ]] && [[ $snap_manager == "yabsnap" ]]; then
		snapshot_path="\$snaphot_number"
	fi

	cat <<EOF > /usr/local/bin/rollback
#!/usr/bin/env bash
echo -ne "$archer_logo"
echo -e "
                        Snapshot rollback script
-------------------------------------------------------------------------"

sudo echo "" > /dev/null

root_disk=\$(cat /proc/cmdline | awk '{sub("root=UUID=", "", \$2); print \$2}')
snaphot_number=\$(cat /proc/cmdline | awk -F '/' '{print \$3}')

echo -e "Mounting root on /mnt"

sudo mount "/dev/disk/by-uuid/\$root_disk" /mnt

echo -e "-------------------------------------------------------------------------"
echo -e "Moving broken root"

sudo mv /mnt/@ /mnt/@broken

echo -e "-------------------------------------------------------------------------"
echo -e "Setting snapshot as root"

sudo btrfs subvolume snapshot /mnt/@snapshots/$snapshot_path /mnt/@ && success="yes"

echo -e "-------------------------------------------------------------------------"
echo -e "Removing broken root"

[[ \$success == "yes" ]] && sudo rm -rf /mnt/@broken

if [ -e "/mnt/@/var/lib/pacman/db.lck" ]; then

	echo -e "-------------------------------------------------------------------------"
	echo -e "Removing pacman db.lck"

	sudo rm /mnt/@/var/lib/pacman/db.lck
fi

echo -e "-------------------------------------------------------------------------"
echo -e "Unmounting /mnt"

sudo umount -R /mnt

read -p "Press any key to reboot..."
reboot
EOF
	chmod a+x /usr/local/bin/rollback
}

set_password() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Restoring password requierment for wheel group"

	sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

	echo -e "-------------------------------------------------------------------------"
	echo -e "Set root password"

	status=1
	while [ $status -ne 0 ]; do
		passwd
		status=$?
	done

	echo -e "-------------------------------------------------------------------------"
	echo -e "Set user password"

	status=1
	while [ $status -ne 0 ]; do
		passwd "$user"
		status=$?
	done
}

setup_system
config_system

setup_paru_pipx
install_packages
config_packages
setup_plasma
setup_laptop
remove_orphans

setup_grub
backup_kernel
[[ $snapshot_layout == "arch" ]] && [[ $snap_manager == "snapper" ]] && snapper_setup
[[ $snapshot_layout == "arch" ]] && [[ $snap_manager == "yabsnap" ]] && yabsnap_setup
[[ $snapshot_layout == "snapper" ]] && snapper_setup
enable_services
pacman_hooks

system_config
user_config
bash_config

setup_flatpak
snapshot_rollback

set_password
exit
