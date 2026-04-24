local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Unix domain multiplexer for session persistence
config.unix_domains = {
  { name = 'unix' },
}
config.default_gui_startup_args = { 'connect', 'unix' }

-- New tab: zellij picker (zp) → attach/create; ESC falls through to a plain shell.
config.default_prog = { '/bin/zsh', '-ic', 'zps' }

-- Window
config.initial_rows = 64
config.initial_cols = 160
config.window_padding = { left = 2, right = 2, top = 2, bottom = 2 }
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.window_background_opacity = 0.85
config.macos_window_background_blur = 20

-- Tabs
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false

-- Always reflect the active pane's OSC-set title (zellij session/tab).
wezterm.on('format-tab-title', function(tab)
  local title = tab.active_pane.title or ''
  if title == '' then title = 'wezterm' end
  return ' ' .. title .. ' '
end)

-- Font: Geist Mono 11 (shared across all three terminals)
config.font = wezterm.font('Geist Mono', { weight = "Regular" })
config.font_size = 11

-- macOS option-as-alt: send raw Alt modifier instead of letting macOS compose.
-- UK-keyboard composes (#, €, º, ^W) are remapped explicitly in `keys` below.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- Keybindings
config.keys = {
  -- UK keyboard alt compose
  { key = "3", mods = "ALT", action = wezterm.action.SendString("#") },
  { key = "2", mods = "ALT", action = wezterm.action.SendString("€") },
  { key = "0", mods = "ALT", action = wezterm.action.SendString("º") },
  -- Alt+Backspace word delete
  { key = "Backspace", mods = "ALT", action = wezterm.action.SendString("\x17") },
  -- Shift+Enter literal newline
  { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\n") },
  -- Clear scrollback
  { key = "k", mods = "CMD", action = wezterm.action.ClearScrollback "ScrollbackAndViewport" },
  -- Pane management
  { key = "w", mods = "CMD", action = wezterm.action.CloseCurrentPane { confirm = false } },
  { key = "d", mods = "CMD", action = wezterm.action.SplitPane { direction = "Right" } },
  { key = "d", mods = "CMD|SHIFT", action = wezterm.action.SplitPane { direction = "Down" } },
  -- Pane navigation
  { key = "LeftArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection "Left" },
  { key = "RightArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection "Right" },
  { key = "UpArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection "Up" },
  { key = "DownArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection "Down" },
}

-- Colors: Monokai Pro
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
    "#3d3a3e",
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
