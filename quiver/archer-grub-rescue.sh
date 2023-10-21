#!/usr/bin/env bash
show_logo() {
	clear
	archer_logo="
-------------------------------------------------------------------------
$(tput setaf 4)
             █████╗ ██████╗  ██████╗██╗  ██╗███████╗██████╗
            ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗
            ███████║██████╔╝██║     ███████║█████╗  ██████╔╝
            ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██╗
            ██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║  ██║
            ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
$(tput sgr0)
-------------------------------------------------------------------------"
	echo -ne "$archer_logo"
	echo -e "
                          Archer rescue script
-------------------------------------------------------------------------"
}

set_root() {
	local status=1
	while [ $status -ne 0 ]; do
		echo -e "Listing available disks"

		lsblk
		fdisk -l | awk '$1=="Disk" && $2~"/dev/" {print $2" "$3" "$4}'

		echo -e "Enter root partition"
		read -r -p "Disk: " root_partition

		echo "p" | fdisk "$root_partition"
		status=$?
	done

	while true; do
		read -r -p "Is the disk $root_partition correct? (Y/n) " yn

		case $yn in
		[yY1]) break ;;
		[nN2])
			set_root
			break ;;
		esac
	done
}

set_boot() {
	local status=1
	while [ $status -ne 0 ]; do
		echo -e "-------------------------------------------------------------------------"
		echo -e "Listing available disks"

		lsblk
		fdisk -l | awk '$1=="Disk" && $2~"/dev/" {print $2" "$3" "$4}'

		echo -e "Enter boot partition"
		read -r -p "Disk: " efi_partition

		echo "p" | fdisk "$efi_partition"
		status=$?
	done

	while true; do
		read -r -p "Is the disk $efi_partition correct? (Y/n) " yn

		case $yn in
		[yY1]) break ;;
		[nN2])
			set_boot
			break ;;
		esac
	done
}

mount_system() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Mounting btrfs subvolumes"
	mount -o subvol=@ "$root_partition" /mnt
	#mount -o subvol=@root "$root_partition" /mnt/root
	mount -o subvol=@home "$root_partition" /mnt/home
	mount -o subvol=@log "$root_partition" /mnt/var/log
	mount -o subvol=@pkg "$root_partition" /mnt/var/cache/pacman/pkg
	mount -o subvol=@tmp "$root_partition" /mnt/var/tmp
	mount -o subvol=@cache "$root_partition" /mnt/var/cache
	mount -o subvol=@spool "$root_partition" /mnt/var/spool
	mount -o subvol=@srv "$root_partition" /mnt/srv
	mount -o defaults,noatime "$efi_partition" /mnt/boot
}

archer_chroot() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Entering arch-chroot"

	arch-chroot /mnt

	echo -e "-------------------------------------------------------------------------"
	echo -e "Reinstalling Grub"

	pacman -S --noconfirm grub efibootmgr

	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
	grub-mkconfig -o /boot/grub/grub.cfg
}

set_root
show_logo
mount_system
archer_chroot