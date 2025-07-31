# Terraform configuration
command -v terraform >/dev/null || return

# Enable bash completion support for terraform
autoload -U +X bashcompinit && bashcompinit

# Load terraform completions
if command -v terraform >/dev/null; then
  complete -o nospace -C terraform terraform
fi
