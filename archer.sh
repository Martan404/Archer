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
                           Arch install script 
-------------------------------------------------------------------------"
}


# If the script is run for a second time then we need to make sure everything is unmounted
[[ -e "archer-check" ]] && swapoff /mnt/swap/swapfile > /dev/null 2>&1
[[ -e "archer-check" ]] && umount -l /mnt > /dev/null 2>&1

set_variables() {
	echo -e "Enter hostname for System"

	hostname=""
	while [ -z "$hostname" ]; do
    	read -r -p "Name: " hostname
	done
	echo -e "Setting hostname to $hostname"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Enter name for User"

	user=""
	while [ -z "$user" ]; do
    	read -r -p "Name: " user
	done
	echo "Setting user name to $user"


	echo -e "-------------------------------------------------------------------------"
	echo -e "Do you want to use the Arch standard or Snapper layout BTRFS layout?"
	echo -e "1. Arch"
	echo -e "2. Snapper"

	while true; do
		read -r -p "Select: " snapshot_subvol

		case $snapshot_subvol in
		1)
			snapshot_subvol="@snapshots"
			snapshot_layout="arch"
			break ;;
		2)
			snapshot_subvol=".snapshots"
			snapshot_layout="snapper"
			break ;;
		esac
	done

	if [[ $snapshot_layout == "arch" ]]; then
		echo -e "-------------------------------------------------------------------------"
		echo -e "Do you want to use Snapper or Yabsnap for snapshots?"
		echo -e "1. Snapper"
		echo -e "2. Yabsnap"

		while true; do
			read -r -p "Select: " snap_manager

			case $snap_manager in
			1)
				snap_manager="snapper"
				break ;;
			2)
				snap_manager="yabsnap"
				break ;;
			esac
		done

	else
		snap_manager="none"
	fi
}

set_disk() {
	local status=1
	while [ $status -ne 0 ]; do
		echo -e "-------------------------------------------------------------------------"
		echo -e "Listing available disks to use for installation"

		lsblk
		fdisk -l | awk '$1=="Disk" && $2~"/dev/" {print $2" "$3" "$4}'

		echo -e "Which disk do you want to use for installation?"
		read -r -p "Disk: " disk

		echo "p" | fdisk "$disk"
		status=$?
	done

	while true; do
		read -r -p "Is the disk $disk correct? (Y/n) " yn

		case $yn in
		[yY1]) break ;;
		[nN2])
			set_disk
			break ;;
		esac
	done
}

set_efi() {
		echo -e "-------------------------------------------------------------------------"
		echo -e "Set size for EFI partition"
		echo -e "1. 256MB"
		echo -e "2. 512MB"
		echo -e "3. 1GB"

		while true; do
			read -r -p "Size: " efi_size

			case $efi_size in
			1)
				efi_size="257MiB";
				break
				;;
			2)
				efi_size="513MiB"
				break
				;;
			3)
				efi_size="1025MiB"
				break
				;;
			esac
		done
}

set_kernel() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Which kernel do you want to use?"

	echo -e "1. Linux"
	echo -e "2. Linux Zen"
	echo -e "3. Linux LTS"
	echo -e "4. Linux Hardened"

	while true; do
		read -r -p "Select: " kernel

		case $kernel in
		1)
			kernel="linux"
			break ;;
		2)
			kernel="linux-zen"
			break ;;
		3)
			kernel="linux-lts"
			break ;;
		4)
			kernel="linux-hardened"
			break ;;
		esac
	done
}

set_swap() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Enter size for swap file (GiB)"

	while [ -z "$swapsize" ]; do
		read -r -p "Size: " swapsize
	done

	echo -e "Setting swap size to $swapsize GiB"
}

set_drivers() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Checking CPU manufacturer"

	lscpu_output=$(lscpu)
	read -r -t 1
	cpu_ucode=""
	cpu_manufacturer="none"

	if [[ $lscpu_output == *"AuthenticAMD"* ]]; then
		echo -e "Found AMD CPU"
		cpu_ucode="amd-ucode"
		export cpu_manufacturer="amd"

	elif [[ $lscpu_output == *"GenuineIntel"* ]]; then
		echo -e "Found Intel CPU"
		cpu_ucode="intel-ucode"
		export cpu_manufacturer="intel"
	fi

	echo -e "-------------------------------------------------------------------------"
	echo -e "Checking GPU manufacturer"

	lspci_output=$(lspci | grep VGA)
	lspci_output_full=$(lspci)
	read -r -t 1
	gpu_driver=""
	gpu_manufacturer="none"

	if [[ $lspci_output == *"Radeon"* ]] || [[ $lspci_output == *"AMD"* ]]; then
		echo -e "Found AMD GPU"
		
		gpu_driver="mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon"
		export gpu_manufacturer="amd"

	elif [[ $lspci_output == *"Integrated Graphics Controller"* ]] || [[ $lspci_output == *"Intel Corporation HD"* ]] || [[ $lspci_output == *"Intel Corporation UHD"* ]]; then
		echo -e "Found Intel GPU"
		
		gpu_driver="mesa lib32-mesa vulkan-intel lib32-vulkan-intel"
		export gpu_manufacturer="intel"

	elif [[ $lspci_output == *"NVIDIA"* ]] || [[ $lspci_output == *"GeForce"* ]]; then
		if [[ $lspci_output == *"RTX"* ]]; then
			echo -e "Found Nvidia RTX GPU"
			nvidia_version="nvidia-open-dkms"

		else
			echo -e "Found Nvidia GPU"
			nvidia_version="nvidia-dkms"
		fi

		echo -e "Installing $nvidia_version package"
		
		gpu_driver="$nvidia_version nvidia-utils lib32-nvidia-utils nvidia-settings"
		export gpu_manufacturer="nvidia"

	elif [[ ${lspci_output} =~ (Virtio|QEMU) ]] || [[ ${lspci_output_full} =~ (Virtio|QEMU) ]]; then
		echo "Found VM GPU"
		gpu_driver="qemu-guest-agent vulkan-virtio lib32-vulkan-virtio"
		export gpu_manufacturer="vm"
	
	else
		echo "GPU could not be detected"
		while true; do
			read -r -p "Do you want to install VirtIO VM drivers? (y/N) " yN

			case $yN in
			[yY1])
				echo "Installing VM drivers"
				gpu_driver="qemu-guest-agent vulkan-virtio lib32-vulkan-virtio"
				export gpu_manufacturer="vm"
				break
				;;
			[nN2])
				echo "Skipping GPU drivers"
				break
				;;
			esac
		done
	fi
}

format_drive() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Wiping drive and setting up GPT partition table"

	parted -s "$disk" mklabel gpt

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating EFI Partition"

	parted -s "$disk" mkpart fat32 0% "$efi_size"
	parted -s "$disk" set 1 esp on

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating root partition"

	parted -s "$disk" mkpart btrfs "$efi_size" 100%

	fdisk "$disk" <<<"p"

	if [[ $disk == *"nvme"* || $disk == *"mmc"* ]]; then
		efi_partition="${disk}p1"
		root_partition="${disk}p2"
	else
		efi_partition="${disk}1"
		root_partition="${disk}2"
	fi
}

setup_drive() {
  	echo -e "-------------------------------------------------------------------------"
  	echo -e "Formatting EFI partition"

	mkfs.fat -F32 "$efi_partition"


	echo -e "-------------------------------------------------------------------------"
	echo -e "Formatting root partition"

	mkfs.btrfs -f -L "$hostname" "$root_partition"

	echo -e "-------------------------------------------------------------------------"
	echo -e "Mounting root and creating btrfs subvolumes"

	mount "$root_partition" /mnt
	
	btrfs subvolume create /mnt/@ # Root
	#btrfs subvolume create /mnt/@root # Root home
	btrfs subvolume create /mnt/@home # Home
	btrfs subvolume create /mnt/@log # Log files
	btrfs subvolume create /mnt/@pkg # Package files
	btrfs subvolume create /mnt/@tmp # Temp files
	btrfs subvolume create /mnt/@cache # Cache files
	btrfs subvolume create /mnt/@spool # Spool data
	btrfs subvolume create /mnt/@srv # Web servers
	[[ $snapshot_layout == "arch" ]] && btrfs subvolume create /mnt/"$snapshot_subvol" # Snapshots
	btrfs subvolume create /mnt/@swap # Swapfile

	echo -e "-------------------------------------------------------------------------"
	echo -e "Unmounting root"

	umount -R /mnt

	echo -e "-------------------------------------------------------------------------"
	echo -e "Mounting btrfs subvolumes and EFI partition"

	mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@ "$root_partition" /mnt
	#mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@root "$root_partition" /mnt/root
	mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@home "$root_partition" /mnt/home
	mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@log "$root_partition" /mnt/var/log
	mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@pkg "$root_partition" /mnt/var/cache/pacman/pkg
	mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@tmp "$root_partition" /mnt/var/tmp
	mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@cache "$root_partition" /mnt/var/cache
	mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@spool "$root_partition" /mnt/var/spool
	mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol=@srv "$root_partition" /mnt/srv
	[[ $snapshot_layout == "arch" ]] && mount --mkdir -t btrfs -o ssd,noatime,compress=zstd,space_cache=v2,subvol="$snapshot_subvol" "$root_partition" /mnt/.snapshots
	mount --mkdir -t btrfs -o noatime,subvol=@swap "$root_partition" /mnt/swap
	mount --mkdir -o defaults,noatime "$efi_partition" /mnt/boot

	#chmod 0750 /mnt/root
	chmod 1777 /mnt/var/tmp

	echo -e "-------------------------------------------------------------------------"
	echo -e "Creating swap file"

	btrfs filesystem mkswapfile --size "$swapsize"g --uuid clear /mnt/swap/swapfile

	echo -e "-------------------------------------------------------------------------"
	echo -e "Mounting swap file"

	swapon /mnt/swap/swapfile
}

setup_environment() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Enabling Network Time Sync"

	timedatectl set-ntp true

	echo -e "-------------------------------------------------------------------------"
	echo -e "Setting Pacman configurations"

	sed -i "s/^#Color/Color/" /etc/pacman.conf

	sed -i "s/^#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
	sed -i '/^ParallelDownloads = .*/a ILoveCandy' /etc/pacman.conf
	
	sed -i 's/^#\[multilib\]/\[multilib\]/' /etc/pacman.conf
	sed -i '/^\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf

	pacman -Sy

	touch archer-check # This is used to check if the script is ran a second time
}

install_system() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Installing base and kernel packages"

    while true; do
		# shellcheck disable=SC2086
		pacstrap -K /mnt base base-devel sudo $kernel $kernel-headers linux-firmware $cpu_ucode $gpu_driver btrfs-progs dosfstools e2fsprogs exfatprogs f2fs-tools jfsutils ntfs-3g udftools xfsprogs && break

    	echo "$(tput setaf 9)Package installation failed. Retrying... $(tput sgr0)"
	done

	echo -e "-------------------------------------------------------------------------"
	echo -e "Generating fstab"

	genfstab -U /mnt >> /mnt/etc/fstab

	echo -e "-------------------------------------------------------------------------"
	echo -e "Configuring fstab"

	sed -i 's/\(\/swap\)\(.*\)compress=zstd:3,ssd,discard=async,space_cache=v2\(.*\)/\1\2ssd\3/' /mnt/etc/fstab # Clean up btrfs swap partition
	sed -i 's/,subvolid=...//g' /mnt/etc/fstab # Remove subvolid for better snapshot support
}

arch_chroot() {
	echo -e "-------------------------------------------------------------------------"
	echo -e "Downloading Quiver"

	cd /mnt && curl -L https://github.com/Martan404/Archer/archive/master.tar.gz | tar -xz Archer-main && cd /

	echo -e "-------------------------------------------------------------------------"
	echo -e "Entering archer-chroot"

	arch-chroot /mnt /bin/bash /Archer-main/archer-chroot.sh "$user" "$hostname" "$snapshot_layout" "$cpu_manufacturer" "$gpu_manufacturer" "$snapshot_subvol" "$root_partition" "$snap_manager"
	rm -rf /mnt/Archer-main
}

exit_install() {	
	echo -e "-------------------------------------------------------------------------"
	echo -e "System ready to boot, please remove the installation media before restarting"

	read -r -p "Press any key to shutdown..."
	
	swapoff /mnt/swap/swapfile > /dev/null 2>&1
	umount -l /mnt > /dev/null 2>&1
	shutdown now && exit
}

show_logo

set_variables
set_disk
set_efi
set_kernel
set_swap
set_drivers

format_drive
setup_drive
[[ ! -e "archer-check" ]] && setup_environment
install_system
arch_chroot
exit_install
