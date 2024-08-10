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

firewall-cmd --permanent --zone=internal --change-interface=lo
firewall-cmd --permanent --zone=libvirt --change-interface=virbr0
firewall-cmd --permanent --zone=trusted --change-interface=waydroid0
firewall-cmd --zone=home --add-port 5353/udp
firewall-cmd --zone=trusted --add-port 5353/udp

echo -e "-------------------------------------------------------------------------"
echo -e "Cleaning up script"

systemctl disable --now archer-boot.service
rm -f /etc/systemd/system/archer-boot.service
rm -f ${BASH_SOURCE[0]}