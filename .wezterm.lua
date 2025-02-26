local wezterm = require("wezterm")

return {
  -- Start WezTerm with PowerShell without the default logo
  default_prog = { "pwsh", "-NoLogo" },

  -- Force WezTerm to use the most powerful GPU
  webgpu_power_preference = "HighPerformance",

  -- Use the fastest font rendering possible
  harfbuzz_features = { "zero", "kern", "liga", "clig" }, -- Optimize text shaping
  font = wezterm.font_with_fallback({ "JetBrains Mono", "Cascadia Code" }),
  font_size = 13,

  -- Ensure consistent high FPS performance
  max_fps = 144, -- Adjust based on your monitor’s refresh rate

  -- Enable unlimited scrollback (so performance isn’t bottlenecked)
  scrollback_lines = 100000, -- High value to allow long logs

  -- Performance tuning for text rendering
  use_ime = false, -- Disable IME if not needed
  adjust_window_size_when_changing_font_size = false, -- Avoid unnecessary resizing

  -- Disable tab bar when using only one tab for better performance
  hide_tab_bar_if_only_one_tab = true,

  -- Set a high-performance cursor
  default_cursor_style = "SteadyBlock",

  -- Disable background opacity for max rendering speed
  window_background_opacity = 1.0,
}
