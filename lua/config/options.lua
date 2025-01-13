-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable mouse
vim.o.mouse = ""

-- Disable backup files
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

-- in lua/config/options.lua
vim.g.autoformat = false -- Disable autoformat

-- Disable diagnostics by default
vim.diagnostic.enable(false)
