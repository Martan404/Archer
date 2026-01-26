
# Check /etc/bash.bashrc for more configuration

# Get user aliases
[[ -r ~/.bash_aliases ]] && source ~/.bash_aliases

# Add ~/System/scripts to PATH
[[ -d "$HOME/System/scripts" ]] && export PATH=$PATH:$HOME/System/scripts

# Display system information
fastfetch --config ~/.config/fastfetch/config-small.jsonc

# ble.sh
[[ -r /usr/share/blesh/ble.sh ]] && [[ $- == *i* ]] && source /usr/share/blesh/ble.sh

# Atuin
eval "$(atuin init bash)"