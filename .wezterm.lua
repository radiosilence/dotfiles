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
config.use_resize_increments = true  -- snap window to cell grid, no gap at edges
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

-- Kitty keyboard protocol so Ctrl+Shift+P is distinct from Ctrl+P (zellij needs this).
config.enable_kitty_keyboard = true

-- Keybindings — macOS-native defaults where possible.
-- We use zellij for panes, so WezTerm's own split-pane bindings are omitted.
-- WezTerm tabs = per-project, zellij tabs = per-worktree (Ctrl+N = zellij).
config.keys = {
  -- UK keyboard alt compose
  { key = "3", mods = "ALT", action = wezterm.action.SendString("#") },
  { key = "2", mods = "ALT", action = wezterm.action.SendString("€") },
  { key = "0", mods = "ALT", action = wezterm.action.SendString("º") },

  -- macOS-native text editing inside the shell
  { key = "Backspace", mods = "ALT",  action = wezterm.action.SendString("\x17") },   -- Opt+Del: delete word
  { key = "Backspace", mods = "CMD",  action = wezterm.action.SendString("\x15") },   -- Cmd+Del: delete to BOL
  { key = "LeftArrow", mods = "ALT",  action = wezterm.action.SendString("\x1bb") },  -- Opt+Left: word back
  { key = "RightArrow", mods = "ALT", action = wezterm.action.SendString("\x1bf") },  -- Opt+Right: word fwd
  { key = "LeftArrow", mods = "CMD",  action = wezterm.action.SendString("\x01") },   -- Cmd+Left: BOL
  { key = "RightArrow", mods = "CMD", action = wezterm.action.SendString("\x05") },   -- Cmd+Right: EOL

  -- Shift+Enter literal newline (bypasses shell accept-line)
  { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\n") },

  -- Copy / paste — explicit so nothing shadows them
  { key = "c", mods = "CMD", action = wezterm.action.CopyTo "Clipboard" },
  { key = "v", mods = "CMD", action = wezterm.action.PasteFrom "Clipboard" },

  -- Find in scrollback
  { key = "f", mods = "CMD", action = wezterm.action.Search "CurrentSelectionOrEmptyString" },

  -- Clear scrollback (like ⌘K in Terminal.app)
  { key = "k", mods = "CMD", action = wezterm.action.ClearScrollback "ScrollbackAndViewport" },

  -- Font size
  { key = "=", mods = "CMD", action = wezterm.action.IncreaseFontSize },
  { key = "-", mods = "CMD", action = wezterm.action.DecreaseFontSize },
  { key = "0", mods = "CMD", action = wezterm.action.ResetFontSize },

  -- Tabs (per-project)
  { key = "t",     mods = "CMD",       action = wezterm.action.SpawnTab "CurrentPaneDomain" },
  { key = "w",     mods = "CMD",       action = wezterm.action.CloseCurrentTab { confirm = false } },
  { key = "]",     mods = "CMD|SHIFT", action = wezterm.action.ActivateTabRelative(1) },
  { key = "[",     mods = "CMD|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
  { key = "1",     mods = "CMD",       action = wezterm.action.ActivateTab(0) },
  { key = "2",     mods = "CMD",       action = wezterm.action.ActivateTab(1) },
  { key = "3",     mods = "CMD",       action = wezterm.action.ActivateTab(2) },
  { key = "4",     mods = "CMD",       action = wezterm.action.ActivateTab(3) },
  { key = "5",     mods = "CMD",       action = wezterm.action.ActivateTab(4) },
  { key = "6",     mods = "CMD",       action = wezterm.action.ActivateTab(5) },
  { key = "7",     mods = "CMD",       action = wezterm.action.ActivateTab(6) },
  { key = "8",     mods = "CMD",       action = wezterm.action.ActivateTab(7) },
  { key = "9",     mods = "CMD",       action = wezterm.action.ActivateTab(-1) },

  -- Window
  { key = "n",     mods = "CMD",       action = wezterm.action.SpawnWindow },
  { key = "Enter", mods = "CMD",       action = wezterm.action.ToggleFullScreen },

  -- Command palette: Cmd+Shift+P (free Ctrl+Shift+P for zellij pane mode)
  { key = "p", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
  { key = "p", mods = "CMD|SHIFT",  action = wezterm.action.ActivateCommandPalette },
}

-- Mouse: Cmd+Click opens links (macOS-native, replaces default Shift+Click).
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CMD",
    action = wezterm.action.Nop,  -- suppress text-selection start on Cmd+press
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CMD",
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
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
