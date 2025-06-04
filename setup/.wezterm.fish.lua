local wezterm = require 'wezterm'

local key_mappings = {
    { key = "n", mods = "CTRL", action = "DownArrow" },
    { key = "p", mods = "CTRL", action = "UpArrow" },
    { key = "f", mods = "CTRL", action = "RightArrow" },
    { key = "b", mods = "CTRL", action = "LeftArrow" },
}

local function create_keybinds(mappings)
    local binds = {}
    for _, map in ipairs(mappings) do
        table.insert(binds, {
            key = map.key,
            mods = map.mods,
            action = wezterm.action.SendKey { key = map.action }
        })
    end
    return binds
end

return {
  default_prog = { "C:\\msys64\\usr\\bin\\fish.exe" },
  font_size = 13.0,
  color_scheme = "Catppuccin Mocha",
  enable_tab_bar = false,
  audible_bell = "Disabled",
  keys = create_keybinds(key_mappings),
}