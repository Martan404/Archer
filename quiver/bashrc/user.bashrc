
# Check /etc/bash.bashrc for more configuration
[[ -r ~/.bash_aliases ]] && source ~/.bash_aliases

# Add ~/System/scripts to PATH
[[ -d "$HOME/System/scripts" ]] && export PATH=$PATH:$HOME/System/scripts

# Display system information
fastfetch --config ~/.config/fastfetch/config-small.jsonc