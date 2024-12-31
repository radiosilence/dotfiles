if type -q hx
    set -gx EDITOR hx
else if type -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end
