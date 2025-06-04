local wezterm = require 'wezterm'

return {
  default_prog = {"pwsh", "-NoLogo"},
  font_size = 11.0,
  colors = {
    background = "#1e1e2e",
    foreground = "#cdd6f4",
    cursor_bg = "#cdd6f4",
    selection_bg = "#45475a",
    ansi = { "#1e1e2e", "#f38ba8", "#a6e3a1", "#f9e2af",
             "#89b4fa", "#cba6f7", "#94e2d5", "#cdd6f4" },
    brights = { "#585b70", "#f38ba8", "#a6e3a1", "#f9e2af",
                "#89b4fa", "#cba6f7", "#94e2d5", "#bac2de" },
  },
  enable_tab_bar = false,
  audible_bell = "Disabled",
}