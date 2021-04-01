local wezterm = require 'wezterm';

return {
   font = wezterm.font("Iosevka Nerd Font"),
   font_rules = {
      {
         intensity = "Bold",
         font = wezterm.font("Iosevka", {bold=true}),
      },
      {
         italic = true,
         intensity = "Bold",
         font = wezterm.font("Iosevka", {bold=true, italic=true}),
      },
      {
         italic = true,
         font = wezterm.font("Iosevka", {italic=true}),
      }
   }
}