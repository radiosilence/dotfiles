local wezterm = require 'wezterm';

return {
    initial_rows = 64,
    initial_cols = 160,
    font = wezterm.font('Geist Mono', { weight = "Regular" }),
    font_rules = {
        {
            intensity = "Bold",
            font = wezterm.font('Geist Mono', { bold = true })
        },
        {
            italic = true,
            intensity = "Bold",
            font = wezterm.font('Geist Mono', { bold = true, italic = true })
        },
        {
            italic = true,
            font = wezterm.font('Geist Mono', { italic = true })
        }
    },
    send_composed_key_when_left_alt_is_pressed = true,
    send_composed_key_when_right_alt_is_pressed = true,
    keys = {
        -- {
        --   key = "3",
        --   mods = "ALT",
        --   action = { SendKey = { key = "#" } }
        -- },
        -- {
        --   key = "2",
        --   mods = "ALT",
        --   action = { SendKey = { key = "€" } }
        -- },
        -- {
        --   key = "0",
        --   mods = "ALT",
        --   action = { SendKey = { key = "º" } }
        -- },
        {
            key = "w",
            mods = "CMD",
            action = wezterm.action.CloseCurrentPane { confirm = false }
        },
        {
            key = "d",
            mods = "CMD",
            action = wezterm.action.SplitPane { direction = "Right" }
        },

        {
            key = "d",
            mods = "CMD|SHIFT",
            action = wezterm.action.SplitPane { direction = "Down" }
        },
        {
            key = "LeftArrow",
            mods = "CMD",
            action = wezterm.action.ActivatePaneDirection "Left",
        },
        {
            key = "RightArrow",
            mods = "CMD",
            action = wezterm.action.ActivatePaneDirection "Right",
        },
        {
            key = "UpArrow",
            mods = "CMD",
            action = wezterm.action.ActivatePaneDirection "Up",
        },
        {
            key = "DownArrow",
            mods = "CMD",
            action = wezterm.action.ActivatePaneDirection "Down",
        },
    },
    colors = {
        -- The default text color
        foreground = "#fcfcfa",
        -- The default background color
        background = "#2d2a2e",

        -- Overrides the cell background color when the current cell is occupied by the
        -- cursor and the cursor style is set to Block
        cursor_bg = "#c1c0c0",
        -- Overrides the text color when the current cell is occupied by the cursor
        cursor_fg = "black",
        -- Specifies the border color of the cursor when the cursor style is set to Block,
        -- of the color of the vertical or horizontal bar when the cursor style is set to
        -- Bar or Underline.
        cursor_border = "#c1c0c0",

        -- the foreground color of selected text
        selection_fg = "#fcfcfa",
        -- the background color of selected text
        selection_bg = "#5b595c",

        -- The color of the scrollbar "thumb"; the portion that represents the current viewport
        scrollbar_thumb = "#222222",

        -- The color of the split lines between panes
        split = "#444444",
        ansi = {
            "#4d4a4e",
            "#ff6188",
            "#a9dc76",
            "#ffd866",
            "#fc9867",
            "#ab9df2",
            "#78dce8",
            "#fcfcfa",
        },
        brights = {
            "#727072",
            "#ff6188",
            "#a9dc76",
            "#ffd866",
            "#fc9867",
            "#ab9df2",
            "#78dce8",
            "#fcfcfa",
        },
    },
    hide_tab_bar_if_only_one_tab = true,
    window_padding = { left = 2, right = 2, top = 2, bottom = 2 },
    window_decorations = "RESIZE|TITLE",
    window_close_confirmation = "NeverPrompt",
    use_fancy_tab_bar = false,
    tab_bar_at_bottom = true,
    window_background_opacity = 0.85,
    macos_window_background_blur = 20,
    set_environment_variables = {
        -- PATH = path .. "/opt/homebrew/bin:/usr/local/bin:"
    },
}
