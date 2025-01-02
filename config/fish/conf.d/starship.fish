using starship || exit

set -gx STARSHIP_CONFIG ~/.config/starship.toml
starship init fish | source
