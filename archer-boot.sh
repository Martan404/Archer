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
echo -e "Setting up Firewalld rules"
# libvirt interface
firewall-cmd --permanent --zone=trusted --change-interface=virbr0
# Waydroid interface
firewall-cmd --permanent --zone=trusted --change-interface=waydroid0
# Interal loopback device
firewall-cmd --permanent --zone=internal --change-interface=lo
# Avahi ports
firewall-cmd --permanent --zone=home --add-port 5353/udp
firewall-cmd --permanent --zone=trusted --add-port 5353/udp

echo -e "-------------------------------------------------------------------------"
echo -e "Cleaning up script"

systemctl disable --now archer-boot.service
rm -f /etc/systemd/system/archer-boot.service
rm -f ${BASH_SOURCE[0]}