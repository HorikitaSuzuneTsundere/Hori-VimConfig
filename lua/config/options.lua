-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable mouse
vim.o.mouse = ""

-- Disable backup files
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.shadafile = "NONE" -- Disable shada file completely

-- in lua/config/options.lua
vim.g.autoformat = false -- Disable autoformat

-- Disable diagnostics by default
vim.diagnostic.enable(false)

-- Old terminal cursor
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:hor1,r-cr-o:hor1"

vim.opt.cursorline = false     -- VALID: Disables highlighting the cursor line
vim.opt.cursorcolumn = false   -- Disables vertical line at cursor position
vim.opt.relativenumber = false -- Disables relative line numbering
vim.opt.number = false         -- Disables line numbers completely
vim.opt.wrap = false           -- Disables line wrapping
vim.opt.showcmd = false        -- Disables showing partial commands in bottom right
vim.opt.ruler = false          -- Disables line/column number in status line
vim.opt.hlsearch = false       -- VALID: Disables highlighting of search matches
vim.opt.foldenable = false     -- VALID: Disables code folding
vim.opt.spell = false          -- VALID: Disables spell checking
vim.opt.list = false           -- VALID: Disables displaying special characters (like tabs, trailing spaces)
vim.opt.syntax = "off"         -- VALID: Disables syntax highlighting

-- Configuration for faster file editing
vim.opt.history = 50              -- Reduces number of commands to remember
vim.opt.synmaxcol = 128           -- Only highlight first 128 columns for syntax
vim.opt.redrawtime = 1500         -- Maximum time spent on syntax highlighting

vim.opt.fillchars = { eob = " " } -- Removes ~ from empty lines

-- Turn off loggers
vim.lsp.set_log_level("OFF")      -- Disables LSP logging completely
vim.fn.setenv("NVIM_LOG_FILE", "NUL")  -- Redirect general logs
vim.fn.setenv("NEOTREE_LOG_FILE", "NUL")  -- Disable neo-tree.nvim logs
