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

-- Optimize shada config
vim.o.shada = "'50,<10,s10,h,r/tmp"

-- Optimize startup time by disabling some built-in plugins
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1
