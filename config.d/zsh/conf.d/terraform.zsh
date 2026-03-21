# Terraform configuration
command -v terraform >/dev/null || return

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C terraform terraform
