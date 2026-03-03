# Terraform configuration
command -v terraform >/dev/null || return

# Enable bash completion support for terraform
autoload -U +X bashcompinit && bashcompinit

# Load terraform completions
complete -o nospace -C terraform terraform
