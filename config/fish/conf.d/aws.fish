using aws-vault || exit
alias aws-shell='aws-vault exec -d 72h -n'

# login to AWS console
alias aws-login='aws-vault login -d 72h'
