fish_add_path -p ~/.dotfiles/bin
fish_add_path /usr/local/sbin

if type -q code
    set -fx EDITOR "code --wait"
else if type -q hx
    set -gx EDITOR hx
else if type -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end
