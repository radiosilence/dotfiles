using starship || exit

set -gx STARSHIP_CONFIG ~/.config/starship/config.toml
starship init fish | source
