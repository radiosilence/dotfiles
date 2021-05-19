# init_ssh_agent() {
#   eval $(ssh-agent -s)
#   ssh-add ~/.ssh/id_jc
#   ssh-add ~/.ssh/id_mw
# }
# if [ -z "$SSH_AUTH_SOCK" ]; then
#   init_ssh_agent
# fi
