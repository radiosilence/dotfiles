# sudo-askpass - Configure sudo to use 1Password for password prompts

# Set up askpass - script auto-calculates item name from hostname/user
# OP_SUDO_ITEM can override the default naming
export SUDO_ASKPASS=~/.dotfiles/bin/sudo-ask-pass

# The sudo wrapper script in bin/sudo handles all sudo calls
# No alias needed since bin/ is in PATH before /usr/bin
