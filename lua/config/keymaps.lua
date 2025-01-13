-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Disable Arrow Keys
vim.keymap.set("", "<Up>", "<Nop>", { desc = "Disable Up Arrow" })
vim.keymap.set("", "<Down>", "<Nop>", { desc = "Disable Down Arrow" })
vim.keymap.set("", "<Left>", "<Nop>", { desc = "Disable Left Arrow" })
vim.keymap.set("", "<Right>", "<Nop>", { desc = "Disable Right Arrow" })

-- Disable Home and End
vim.keymap.set("", "<Home>", "<Nop>", { desc = "Disable Home Key" })
vim.keymap.set("", "<End>", "<Nop>", { desc = "Disable End Key" })

-- Disable Numpad keys if you're not using them
vim.keymap.set("", "<Numpad1>", "<Nop>", { desc = "Disable Numpad1" })
vim.keymap.set("", "<Numpad2>", "<Nop>", { desc = "Disable Numpad2" })
vim.keymap.set("", "<Numpad3>", "<Nop>", { desc = "Disable Numpad3" })
vim.keymap.set("", "<Numpad4>", "<Nop>", { desc = "Disable Numpad4" })
vim.keymap.set("", "<Numpad5>", "<Nop>", { desc = "Disable Numpad5" })
vim.keymap.set("", "<Numpad6>", "<Nop>", { desc = "Disable Numpad6" })
vim.keymap.set("", "<Numpad7>", "<Nop>", { desc = "Disable Numpad7" })
vim.keymap.set("", "<Numpad8>", "<Nop>", { desc = "Disable Numpad8" })
vim.keymap.set("", "<Numpad9>", "<Nop>", { desc = "Disable Numpad9" })

-- Disable other random keys that might interfere (you can tweak based on preference)
vim.keymap.set("", "<C-s>", "<Nop>", { desc = "Disable Ctrl+S" }) -- Disable save (use :w instead)
vim.keymap.set("", "<C-w>", "<Nop>", { desc = "Disable Ctrl+W" }) -- Disable window switching (use :q for quitting)

-- Disable Copy , Paste and Cut
vim.keymap.set("", "<C-c>", "<Nop>", { desc = "Disable Ctrl+C" })
vim.keymap.set("", "<C-v>", "<Nop>", { desc = "Disable Ctrl+V" })
vim.keymap.set("", "<C-x>", "<Nop>", { desc = "Disable Ctrl+X" })

-- Disable undo and redo
vim.keymap.set("", "<C-z>", "<Nop>", { desc = "Disable Ctrl+Z" })
vim.keymap.set("", "<C-y>", "<Nop>", { desc = "Disable Ctrl+Y" })

-- Disable Function Keys (F1-F12)
vim.keymap.set("", "<F1>", "<Nop>", { desc = "Disable F1" })
vim.keymap.set("", "<F2>", "<Nop>", { desc = "Disable F2" })
vim.keymap.set("", "<F3>", "<Nop>", { desc = "Disable F3" })
vim.keymap.set("", "<F4>", "<Nop>", { desc = "Disable F4" })
vim.keymap.set("", "<F5>", "<Nop>", { desc = "Disable F5" })
vim.keymap.set("", "<F6>", "<Nop>", { desc = "Disable F6" })
vim.keymap.set("", "<F7>", "<Nop>", { desc = "Disable F7" })
vim.keymap.set("", "<F8>", "<Nop>", { desc = "Disable F8" })
vim.keymap.set("", "<F9>", "<Nop>", { desc = "Disable F9" })
vim.keymap.set("", "<F10>", "<Nop>", { desc = "Disable F10" })
vim.keymap.set("", "<F11>", "<Nop>", { desc = "Disable F11" })
vim.keymap.set("", "<F12>", "<Nop>", { desc = "Disable F12" })

-- Disable Mouse Usage in Normal and Insert Mode (forces keyboard navigation)
vim.keymap.set("", "<MiddleMouse>", "<Nop>", { desc = "Disable Middle Mouse Button" })
vim.keymap.set("", "<LeftMouse>", "<Nop>", { desc = "Disable Left Mouse Button" })
vim.keymap.set("", "<RightMouse>", "<Nop>", { desc = "Disable Right Mouse Button" })

-- Disable Other Keys
vim.keymap.set("", "<Insert>", "<Nop>", { desc = "Disable Insert Key" })
vim.keymap.set("", "<Del>", "<Nop>", { desc = "Disable Delete Key" })
vim.keymap.set("", "<PageUp>", "<Nop>", { desc = "Disable Page Up Key" })
vim.keymap.set("", "<PageDown>", "<Nop>", { desc = "Disable Page Down Key" })
vim.keymap.set("", "<Print>", "<Nop>", { desc = "Disable Print Key" })
vim.keymap.set("", "<ScrollLock>", "<Nop>", { desc = "Disable Scroll Lock Key" })
vim.keymap.set("", "<Pause>", "<Nop>", { desc = "Disable Pause/Break Key" })
