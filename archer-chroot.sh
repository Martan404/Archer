#!/usr/bin/env bash
# shellcheck disable=SC2002,SC2164

# Import variables from first script
user=${1}
hostname=${2}
snapshot_layout=${3}
cpu_manufacturer=${4}
gpu_manufacturer=${5}
snapshot_subvol=${6}
root_partition=${7}
snap_manager=${8}

package_installer() {
	input_packages=$1
	pkg_manager=$2
	max_tries=3
	try_count=0

	# Check if argument is .txt file and combine each line
    if [[ "$input_packages" == *.txt ]]; then
		packages=$(cat "$input_packages" | tr '\n' ' ')
	else
		packages=$input_packages
	fi

	while [ "$try_count" -lt "$max_tries" ]; do
	    try_count=$((try_count+1))
		
		# shellcheck disable=SC2086
		if [ "$pkg_manager" = "pacman" ]; then
			pacman -S --needed --noconfirm $packages && break
		
		else
			sudo -u "$user" paru -S --needed --noconfirm $packages && break
		fi

    	echo "$(tput setaf 9)Package installation failed. Retrying... ($try_count/$max_tries)$(tput sgr0)"
	done

if [ "$try_count" -eq "$max_tries" ]; then
    echo "$(tput setaf 9)Package installation failed after $try_count attempts$(tput sgr0)"

	echo -e "Should we keep installing or exit?"
	echo -e "1. Continiue"
	echo -e "2. Exit"

	while true; do
		read -r -p "Select: " choice

		case $choice in
		[yY1])
			try_count=0
			choice="continiue"
			break
			;;
		[nN2])
			choice="exit"
			echo "$(tput setaf 9)Exiting...$(tput sgr0)"
			exit
			;;
		esac
	done
fi
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
		echo "127.0.0.1		localhost"
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

        package_installer "git rust cmake" pacman
	
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

	sed -n '/# DRIVERS/{:a;n;/# DRIVERS/b;p;ba}' "/Archer-main/quiver/packages.txt" > "Archer-main/quiver/drivers.txt"
	package_installer "Archer-main/quiver/drivers.txt"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing desktop environment"

	sed -n '/# DESKTOP/{:a;n;/# DESKTOP/b;p;ba}' "/Archer-main/quiver/packages.txt" > "Archer-main/quiver/desktop.txt"
	package_installer "Archer-main/quiver/desktop.txt"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing system packages"

	sed -n '/# SYSTEM #/{:a;n;/# SYSTEM #/b;p;ba}' "/Archer-main/quiver/packages.txt" > "Archer-main/quiver/system.txt"
	package_installer "Archer-main/quiver/system.txt"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing pacman packages"

	sed -n '/# PACMAN/{:a;n;/# PACMAN/b;p;ba}' "/Archer-main/quiver/packages.txt" > "Archer-main/quiver/pacman.txt"
	package_installer "Archer-main/quiver/pacman.txt"

	if [[ $cpu_manufacturer == "intel" ]]; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Installing and enabling thermald service for Intel CPU"

		package_installer "thermald"
		systemctl enable thermald.service
	fi
}

config_packages() {
	# If Steam is not installed then install steam-devices package for controller support in Steam flatpak
	if ! pacman -Qs steam > /dev/null; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Installing steam-devices package for Steam Flatpak"
	
		package_installer "steam-devices" 
	fi

	# If Firefox is installed then start it once and add the user.js
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
	# Else prepare user.js for Flatpak version
	else
		mv /Archer-main/quiver/betterfox-user.js /home/"$user"/.user.js
		chown "$user":"$user" /home/"$user"/.user.js
	fi

	# If Discord is installed then apply fixes 
	if pacman -Qs discord > /dev/null; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Setting Discord to use local login credentials"

		sed -i 's/Exec=\/usr\/bin\/discord/Exec=\/usr\/bin\/discord --password-store=basic/' /opt/discord/discord.desktop

		echo -e "-------------------------------------------------------------------------"
		echo -e "Removing Discord internal update check"

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
Exec=/usr/bin/kwalletd6
END

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing konsave"

	export PATH=$PATH:/home/$user/.local/bin

	sudo -u "$user" pipx install konsave

	mv /Archer-main/quiver/archer.knsv /home/"$user"/archer.knsv

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting up Plasma setup script"

	sudo -u "$user" mkdir -p /home/"$user"/.config/plasma-workspace/env
    mv /Archer-main/quiver/plasma-setup /home/"$user"/.config/plasma-workspace/env/plasma-setup
	
	chmod a+x /home/"$user"/.config/plasma-workspace/env/plasma-setup
	chown "$user":"$user" /home/"$user"/.config/plasma-workspace/env/plasma-setup
	
	sed -i "s/UNIX_USER/$user/g" /home/"$user"/.config/plasma-workspace/env/plasma-setup
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

	if pacman -Qs os-prober > /dev/null; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Enabling Grub OS prober"

		sed -i '/^[#]*GRUB_DISABLE_OS_PROBER=/s/true/false/' /etc/default/grub
		sed -i '/^#GRUB_DISABLE_OS_PROBER/s/^#//' /etc/default/grub
	fi

	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing Grub theme"

	mv /Archer-main/quiver/arch-silence /boot/grub/themes/arch-silence
	sed -i '/^[#]*GRUB_THEME=/c\GRUB_THEME="\/boot\/grub\/themes\/arch-silence\/theme.txt"' /etc/default/grub



	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling GRUB-btrfsd snapshot daemon"

	systemctl enable grub-btrfsd

	echo -e "-------------------------------------------------------------------------"
	echo -e "Disabling snapshot listing in pacman for grub-btrfs"

	sed -i '/^[#]*GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND=/s/true/false/' /etc/default/grub-btrfs/config
	sed -i '/^#GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND/s/^#//' /etc/default/grub-btrfs/config
}

tweak_kernel() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Removing 'quiet' kernel parameter"

	sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/s/ quiet//g' /etc/default/grub

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting kernel boot parameters for CPU"

	if [ "$cpu_manufacturer" = "amd" ]; then
		kernel_parameters=""

	elif [ "$gpu_manufacturer" = "intel" ]; then
		kernel_parameters="intel_iommu=on iommu=pt"
	fi
	
	sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 $kernel_parameters\"/" /etc/default/grub
	
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
	fi
	
	sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 $kernel_parameters\"/" /etc/default/grub
}

backup_kernel() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing rsync"

	package_installer "rsync"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating pacman hooks for kernel backup"

	mkdir /etc/pacman.d/hooks
	mkdir -p /.bootbackup/{preupdate,postupdate}

	cat <<-END > /etc/pacman.d/hooks/00-bootbackup-preupdate.hook
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

		package_installer "snapper snap-pac snap-pac-grub snapper-support snapper-rollback"

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
	sed -i 's/^TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="0"/' /etc/snapper/configs/root
	sed -i 's/^TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
	sed -i 's/^TIMELINE_LIMIT_WEEKLY="10"/TIMELINE_LIMIT_WEEKLY="3"/' /etc/snapper/configs/root
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
	echo -e "Enabling uncomplicated firewall"

	systemctl enable ufw.service

	echo -e "-------------------------------------------------------------------------"
	echo -e "Rebuilding GRUB configs"

	grub-mkconfig -o /boot/grub/grub.cfg
}

pacman_hooks() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Moving pacman hooks"

	mv -v /Archer-main/quiver/hooks/* /etc/pacman.d/hooks/
	chown -R :wheel /etc/pacman.d/hooks/*
}

system_config() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Adding ~/.local/bin PATH in /etc/profile.d/custom-path.sh"

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
	echo -e "Creating windows-boot script"
	cat <<-END >> /usr/local/bin/windows-boot
#!/bin/bash
# Set Windows Boot Manager as NextBoot and reboots
efibootmgr -n \$(efibootmgr | awk '/Windows Boot Manager/ {gsub(/^Boot/, "", \$1); gsub(/\*/, "", \$1); print \$1}') && reboot
END
	chmod +x /usr/local/bin/windows-boot

	echo -e "-------------------------------------------------------------------------"
	echo -e "Adding sudo password exception to windows-boot script"

	echo "%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/windows-boot" >> /etc/sudoers

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting up XDG user directories"

	xdg-user-dirs-update

	#sed -i '/TEMPLATES/s/^/#/' /etc/xdg/user-dirs.defaults
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

	sed -i '/PS1/,+1d' /etc/bash.bashrc
	sed -i '/bash_completion/d' /etc/bash.bashrc && sed -i '/fi/d' /etc/bash.bashrc

	cat /Archer-main/quiver/bash.bashrc >> /etc/bash.bashrc

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring /etc/bash.bash_aliases"

	cat /Archer-main/quiver/bash.bash_aliases >> /etc/bash.bash_aliases

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring /home/$user/.bashrc"

	sed -i '/PS1/d' /home/"$user"/.bashrc
	sed -i '/alias/d' /home/"$user"/.bashrc
	
	cat /Archer-main/quiver/user.bashrc >> /home/"$user"/.bashrc
	chown "$user":"$user" /home/"$user"/.bashrc
	
	echo -e "-------------------------------------------------------------------------"
	echo -e "Symlinking /home/$user/.bashrc to /root/.bashrc"
	
	ln -s /home/"$user"/.bashrc /root/.bashrc

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring /home/$user/.bash_aliases"

	cat /Archer-main/quiver/user.bash_aliases >> /home/"$user"/.bash_aliases
	chown "$user":"$user" /home/"$user"/.bash_aliases

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring fastfetch config"

	cat /Archer-main/quiver/fastfetch-config.jsonc > /home/"$user"/.config/fastfetch/archer.jsonc
	chown "$user":"$user" /home/"$user"/.config/fastfetch/archer.jsonc
}

setup_flatpak() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling Flatpak theming"

	if pacman -Qs flatpak > /dev/null; then

		flatpak override --filesystem=xdg-config/{Kvantum,gtkrc,gtkrc-2.0,gtk-3.0,gtk-4.0}
		flatpak override --filesystem={~/.themes,~/.icons,~/.fonts,~/.local/share/themes}
		flatpak override --env=GTK_THEME=Breeze
	fi

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting Lutris Flatpak theming"
		
	flatpak override net.lutris.Lutris --env=GTK_THEME=Breeze

	echo -e "-------------------------------------------------------------------------"
	echo -e "Writing flatpak-setup desktop entry"

	sudo -u "$user" mkdir -p /home/"$user"/.config/autostart/
	sudo -u "$user" touch /home/"$user"/.config/autostart/flatpak-setup.desktop
	
	cat <<EOF >> /home/"$user"/.config/autostart/flatpak-setup.desktop
[Desktop Entry]
Exec=konsole -e /home/$user/System/scripts/flatpak-setup
Icon=/usr/share/pixmaps/archlinux-logo.png
StartupNotify=true
Type=Application
EOF

	echo -e "-------------------------------------------------------------------------"
	echo -e "Writing Flatpak install script"

	sed -n '/# FLATPAK/{:a;n;/# FLATPAK/b;p;ba}' "/Archer-main/quiver/packages.txt" > "/Archer-main/quiver/flatpak.txt"
	# shellcheck disable=SC2002
	packages=$(cat "/Archer-main/quiver/flatpak.txt" | tr '\n' ' ')
	
	cat /Archer-main/quiver/flatpak-setup >> /home/"$user"/System/scripts/flatpak-setup
	chmod a+x /home/"$user"/System/scripts/flatpak-setup

	sed -i "s/UNIX_USER/$user/g; s/PACKAGE_LIST/$packages/g" /home/"$user"/System/scripts/flatpak-setup
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

	cat /Archer-main/quiver/rollback > /usr/local/bin/rollback
	chmod a+x /usr/local/bin/rollback
	
	sed -i "s/SNAPSHOT_LAYOUT/$snapshot_layout/g" /usr/local/bin/rollback
	sed -i "s/SNAP_MANAGER/$snap_manager/g" /usr/local/bin/rollback
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
tweak_kernel
backup_kernel
[[ $snapshot_layout == "arch" ]] && [[ $snap_manager == "snapper" ]] && snapper_setup
[[ $snapshot_layout == "arch" ]] && [[ $snap_manager == "yabsnap" ]] && yabsnap_setup
[[ $snapshot_layout == "snapper" ]] && snapper_setup
enable_services
pacman_hooks

system_config
user_config
bash_config

pacman -Q flatpak &>/dev/null && setup_flatpak
snapshot_rollback

set_password
exit
