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

-- Reduces Lua parsing/compilation time
vim.loader.enable()

-- setup python host
vim.g.python3_host_prog = 'C:\\Users\\test\\AppData\\Local\\Programs\\Python\\Python313\\python.exe'

-- UI performance optimizations
vim.opt.cursorline = false     -- VALID: Disables highlighting the cursor line
vim.opt.hlsearch = false       -- VALID: Disables highlighting of search matches
vim.opt.foldenable = false     -- VALID: Disables code folding
vim.opt.spell = false          -- VALID: Disables spell checking
vim.opt.list = false           -- VALID: Disables displaying special characters (like tabs, trailing spaces)

-- Configuration for faster file editing
vim.opt.synmaxcol = 128           -- Only highlight first 128 columns for syntax
vim.opt.redrawtime = 1500         -- Maximum time spent on syntax highlighting

-- Turn off loggers
vim.lsp.set_log_level("OFF")      -- Disables LSP logging completely
