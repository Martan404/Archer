
# Check /etc/bash.bashrc for more configuration

[[ $- == *i* ]] && source /usr/share/blesh/ble.sh --noattach

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Get user aliases
[[ -r $HOME/.bash_aliases ]] && source $HOME/.bash_aliases

# Get completions
for file in ~/.bash_completions/*; do [[ -e "$file" ]] && source "$file"; done

# Add ~/System/scripts to PATH
[[ -d "$HOME/System/scripts" ]] && export PATH=$PATH:$HOME/System/scripts

# Display system information
fastfetch --config "$HOME/.config/fastfetch/config-small.jsonc"

# Atuin
eval "$(atuin init bash)"

# ble.sh
[[ ${BLE_VERSION-} ]] && ble-attach
