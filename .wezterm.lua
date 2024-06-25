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
  default_prog = {
    "sh", "-c",
    "(tmux a || tmux) || zsh"
  },
  -- default_prog = { "zsh" },
  send_composed_key_when_left_alt_is_pressed = false,
  send_composed_key_when_right_alt_is_pressed = true,
  keys = {
    -- Rebind OPT-Left, OPT-Right as ALT-b, ALT-f respectively to match Terminal.app behavior
    {
      key = "LeftArrow",
      mods = "OPT",
      action = { SendKey = { key = "b", mods = "ALT" } }
    },
    {
      key = "RightArrow",
      mods = "OPT",
      action = { SendKey = { key = "f", mods = "ALT" } }
    },
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
  set_environment_variables = {
    PATH = "/opt/homebrew/bin:" .. path
  },
}
