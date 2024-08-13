#!/bin/bash
# Main script 3/3
# shellcheck disable=SC2086
echo -e "
-------------------------------------------------------------------------
$(tput setaf 4)
             █████╗ ██████╗  ██████╗██╗  ██╗███████╗██████╗
            ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗
            ███████║██████╔╝██║     ███████║█████╗  ██████╔╝
            ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██╗
            ██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║  ██║
            ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
$(tput sgr0)
-------------------------------------------------------------------------
                           Arch install script"

echo -e "-------------------------------------------------------------------------"
echo -e "Setting up keymap using localectl"

current_keymap=$(localectl status | grep 'VC Keymap' | awk '{print $3}')
localectl set-keymap "$current_keymap"

[[ "$current_keymap" = "sv-latin1" ]] && localectl set-locale en_SE.UTF-8

echo -e "-------------------------------------------------------------------------"
echo -e "Setting up Firewalld rules"

# Start the firewall
firewall-cmd
# Interal loopback device
firewall-cmd --permanent --zone=internal --change-interface=lo
# libvirt interface
firewall-cmd --permanent --zone=trusted --change-interface=virbr0
# Waydroid interface
firewall-cmd --permanent --zone=trusted --change-interface=waydroid0
# Avahi ports
firewall-cmd --permanent --zone=home --add-port 5353/udp
firewall-cmd --permanent --zone=trusted --add-port 5353/udp

echo -e "-------------------------------------------------------------------------"
echo -e "Cleaning up script"

systemctl disable --now archer-boot.service
rm -f /etc/systemd/system/archer-boot.service
rm -f ${BASH_SOURCE[0]}