local wezterm = require 'wezterm';
-- local font = 'Hack JBM Ligatured CCG';

local font = 'Geist Mono';
local path = os.getenv('PATH')
return {
  initial_rows = 64,
  initial_cols = 160,
  font = wezterm.font(font),
  font_rules = {
    {
      intensity = "Bold",
      font = wezterm.font(font, { bold = true })
    }, {
    italic = true,
    intensity = "Bold",
    font = wezterm.font(font,
      { bold = true, italic = true })
  },
    {
      italic = true,
      font = wezterm.font(font, { italic = true })
    }
  },
  send_composed_key_when_left_alt_is_pressed = false,
  send_composed_key_when_right_alt_is_pressed = true,
  keys = {
    {
      key = "3",
      mods = "ALT",
      action = { SendKey = { key = "#" } }
    },
    {
      key = "2",
      mods = "ALT",
      action = { SendKey = { key = "€" } }
    },
    {
      key = "0",
      mods = "ALT",
      action = { SendKey = { key = "º" } }
    },
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
    selection_fg = "white",
    -- the background color of selected text
    selection_bg = "#314f78",

    -- The color of the scrollbar "thumb"; the portion that represents the current viewport
    scrollbar_thumb = "#222222",

    -- The color of the split lines between panes
    split = "#444444",
    brights = {
      "#b195b1",
      "#ff5c8a",
      "#55fc79",
      "#ffe342",
      "#61efff",
      "#8e80ff",
      "#4dffff",
      "#ffffff",
    },
    ansi = {
      "#221f22",
      "#fc618d",
      "#7bd88f",
      "#fce566",
      "#78DCE8",
      "#948ae3",
      "#5ad4e6",
      "#f7f1ff",
    },
  },
  hide_tab_bar_if_only_one_tab = true,
  window_padding = { left = 2, right = 2, top = 2, bottom = 2 },
  window_close_confirmation = "NeverPrompt",
  use_fancy_tab_bar = false,
  tab_bar_at_bottom = true,
  set_environment_variables = {
    PATH = path .. "/opt/homebrew/bin:/usr/local/bin:"
  },
}
