set -gx STARSHIP_CONFIG ~/.config/starship.toml
if type -q starship
    starship init fish | source
end
