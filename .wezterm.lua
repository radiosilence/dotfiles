local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Unix domain multiplexer for session persistence (replaces tmux locally)
config.unix_domains = {
  { name = 'unix' },
}
config.default_gui_startup_args = { 'connect', 'unix' }

-- Window
config.initial_rows = 64
config.initial_cols = 160
config.window_padding = { left = 2, right = 2, top = 2, bottom = 2 }
config.window_decorations = "RESIZE|TITLE"
config.window_close_confirmation = "NeverPrompt"
config.window_background_opacity = 0.85
config.macos_window_background_blur = 20

-- Tabs
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true

-- Font (matching ghostty: Geist Mono, size 11)
config.font = wezterm.font('Geist Mono', { weight = "Regular" })
config.font_size = 11
config.font_rules = {
  {
    intensity = "Bold",
    font = wezterm.font('Geist Mono', { bold = true }),
  },
  {
    italic = true,
    intensity = "Bold",
    font = wezterm.font('Geist Mono', { bold = true, italic = true }),
  },
  {
    italic = true,
    font = wezterm.font('Geist Mono', { italic = true }),
  },
}

-- Alt key behavior (macOS option-as-alt, matching ghostty macos-option-as-alt)
config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

-- Keybindings
config.keys = {
  -- Alt compose keys (matching ghostty alt keybinds)
  { key = "3", mods = "ALT", action = wezterm.action.SendString("#") },
  { key = "2", mods = "ALT", action = wezterm.action.SendString("€") },
  { key = "0", mods = "ALT", action = wezterm.action.SendString("º") },
  -- Shift+Enter sends newline (matching ghostty shift+enter=text:\n)
  { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\n") },
  -- Pane management
  { key = "w", mods = "CMD", action = wezterm.action.CloseCurrentPane { confirm = false } },
  { key = "d", mods = "CMD", action = wezterm.action.SplitPane { direction = "Right" } },
  { key = "d", mods = "CMD|SHIFT", action = wezterm.action.SplitPane { direction = "Down" } },
  -- Pane navigation (matching ghostty cmd+arrow=goto_split)
  { key = "LeftArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection "Left" },
  { key = "RightArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection "Right" },
  { key = "UpArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection "Up" },
  { key = "DownArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection "Down" },
}

-- Colors: Monokai Pro (matching ghostty theme exactly)
config.colors = {
  foreground = "#fcfcfa",
  background = "#2d2a2e",
  cursor_bg = "#c1c0c0",
  cursor_fg = "black",
  cursor_border = "#c1c0c0",
  selection_fg = "#fcfcfa",
  selection_bg = "#5b595c",
  scrollbar_thumb = "#222222",
  split = "#444444",
  ansi = {
    "#3d3a3e", -- black (was #4d4a4e, now matches ghostty palette 0)
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
}

return config
