# Archer

Archer is an Arch install script. It follows the steps outlined in the ArchWiki [installation guide](https://wiki.archlinux.org/title/Installation_guide) with some liberty to make the script work reliably. This is just a way for me to quickly reinstall Arch according to my preferences. Feel free to fork the project, customize it and make it your own.

## Create Arch ISO

Download the  Arch ISO from [https://archlinux.org/download/](https://archlinux.org/download/) and put it on a USB drive with [Etcher](https://www.balena.io/etcher/), [Ventoy](https://www.ventoy.net/en/index.html), or [Rufus](https://rufus.ie/en/)

## SSH Install

From initial prompt run `ip a` to get the ip adress then `passwd` to set password

Enter new system with `ssh root@ip_adress` then run:
```
bash <(curl -L tinyurl.com/archersh)
```
*To fix broken keys run `ssh-keygen -R ip_adress`*

## Regular Install

From initial prompt run these commands: 
```
loadkeys sv-latin1
bash <(curl -L tinyurl.com/archersh)
```
*Replace sv-latin1 with whatever keymap you want*

## Wifi

You can check if the WiFi is blocked by running `rfkill list`.
If it says **Soft blocked: yes**, then run `rfkill unblock wifi`


From initial prompt run `iwctl` then:
```
device list
station [device name] scan
station [device name] get-networks
```
Find your network, and run `station [device name] connect [network name]`, enter your password and run `exit`. You can test if you have internet connection by running `ping archlinux.org`, and then Press Ctrl and C to stop the ping test.
