# sudo-askpass.fish - Configure sudo to use 1Password for password prompts

# Set up askpass - script auto-calculates item name from hostname/user
# OP_SUDO_ITEM can override the default naming
set -gx SUDO_ASKPASS ~/.dotfiles/bin/sudo-ask-pass
alias sudo='sudo --askpass'