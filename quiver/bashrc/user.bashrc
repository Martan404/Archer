
# Check /etc/bash.bashrc for more configuration

[[ $- == *i* ]] && source /usr/share/blesh/ble.sh --noattach

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Get user aliases
[[ -r ~/.bash_aliases ]] && source ~/.bash_aliases

# Add ~/System/scripts to PATH
[[ -d "$HOME/System/scripts" ]] && export PATH=$PATH:$HOME/System/scripts

# Display system information
fastfetch --config ~/.config/fastfetch/config-small.jsonc

# Atuin
eval "$(atuin init bash)"

# ble.sh
[[ ${BLE_VERSION-} ]] && ble-attach