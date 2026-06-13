# Archer, an Arch install script

Archer is an Arch install script. It follows the steps outlined in the ArchWiki [installation guide](https://wiki.archlinux.org/title/Installation_guide) with some liberty to make the script work reliably. This is just a way for me to quickly reinstall Arch according to my preferences. Feel free to fork the project, customize it and make it your own.

## SSH install

From initial prompt run `ip a` to get the ip address then do `passwd` to set a password

On another device enter the new system with `ssh root@ip_address` then run:
```
bash <(curl -L https://raw.githubusercontent.com/Martan404/Archer/main/archer)
```
*To fix old/broken keys run `ssh-keygen -R ip_address`*

## Regular install

From initial prompt run these commands
```
localectl list-keymaps
localectl set-keymap chosen_keymap
bash <(curl -L https://raw.githubusercontent.com/Martan404/Archer/main/archer)
```

## Wifi

From initial prompt run `iwctl` then:
```
device list
station [device name] scan
station [device name] get-networks
station [device name] connect [network name]
```
Enter your password and run `exit`. You can test if you have internet connection by running `ping archlinux.org`, press Ctrl + C to stop the ping test

*You can check if the WiFi is blocked by running `rfkill list`. If it says **Soft blocked: yes**, then run `rfkill unblock wifi`*
