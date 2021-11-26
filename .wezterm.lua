local wezterm = require 'wezterm';

return {
    font = wezterm.font("Iosevka Nerd Font"),
    font_rules = {
        {
            intensity = "Bold",
            font = wezterm.font("Iosevka Nerd Font", {bold = true})
        }, {
            italic = true,
            intensity = "Bold",
            font = wezterm.font("Iosevka Nerd Font",
                                {bold = true, italic = true})
        },
        {
            italic = true,
            font = wezterm.font("Iosevka Nerd Font", {italic = true})
        }
    },
    default_prog = {
        "sh", "-c", '/opt/homebrew/bin/tmux a || /opt/homebrew/bin/tmux'
    },
    -- default_prog = {"zsh"},
    send_composed_key_when_left_alt_is_pressed = false,
    send_composed_key_when_right_alt_is_pressed = true,
    keys = {
        -- Rebind OPT-Left, OPT-Right as ALT-b, ALT-f respectively to match Terminal.app behavior
        {
            key = "LeftArrow",
            mods = "OPT",
            action = {SendKey = {key = "b", mods = "ALT"}}
        }, {
            key = "RightArrow",
            mods = "OPT",
            action = {SendKey = {key = "f", mods = "ALT"}}
        }
    },
    colors = {
        -- The default text color
        foreground = "#f7f1ff",
        -- The default background color
        background = "#221f22",

        -- Overrides the cell background color when the current cell is occupied by the
        -- cursor and the cursor style is set to Block
        cursor_bg = "#52ad70",
        -- Overrides the text color when the current cell is occupied by the cursor
        cursor_fg = "black",
        -- Specifies the border color of the cursor when the cursor style is set to Block,
        -- of the color of the vertical or horizontal bar when the cursor style is set to
        -- Bar or Underline.
        cursor_border = "#52ad70",

        -- the foreground color of selected text
        selection_fg = "black",
        -- the background color of selected text
        selection_bg = "#fffacd",

        -- The color of the scrollbar "thumb"; the portion that represents the current viewport
        scrollbar_thumb = "#222222",

        -- The color of the split lines between panes
        split = "#444444",

        ansi = {
            "#000000", "#fc618d", "#7bd88f", "#fce566", "#78DCE8", "#948ae3",
            "#5ad4e6", "#f7f1ff"
        },
        brights = {
            "#69676c", "#fc618d", "#7bd88f", "#fce566", "#78DCE8", "#948ae3",
            "#14ffff", "#f7f1ff"
        },

        -- Arbitrary colors of the palette in the range from 16 to 255
        indexed = {[136] = "#af8700"}
    },
    hide_tab_bar_if_only_one_tab = true,
    window_padding = {left = 2, right = 2, top = 2, bottom = 2},
    window_close_confirmation = "NeverPrompt"
}
