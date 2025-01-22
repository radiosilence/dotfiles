if status is-interactive
    # cleanup
    set -g fish_greeting
    set -g fish_color_command green
    # binds
    bind alt-backspace backward-kill-word
    bind alt-delete kill-word

end

# path
fish_add_path -p ~/.dotfiles/bin
