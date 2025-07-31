# AWS configuration
command -v aws-vault >/dev/null || return

alias aws-shell='aws-vault exec -d 72h -n'
# Login to AWS console
alias aws-login='aws-vault login -d 72h'
