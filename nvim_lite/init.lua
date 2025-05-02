-- === Startup Optimization ===
vim.loader.enable()

-- === Fast Option Setting (Direct Access, No Sugar) ===
local set = vim.o
local wset = vim.wo
local bset = vim.bo

set.mouse = ""
set.updatetime = 100
set.lazyredraw = true
set.ttyfast = true
set.synmaxcol = 200
set.redrawtime = 1000
set.maxmempattern = 2000
set.shadafile = "NONE" -- temporary

set.number = true
wset.relativenumber = true
set.scrolloff = 10
set.sidescrolloff = 8
wset.wrap = false

wset.linebreak = false
wset.breakindent = false

set.showmode = false
set.undofile = true
set.swapfile = false
set.backup = false
set.writebackup = false

set.timeoutlen = 500
set.ttimeoutlen = 10
set.keymodel = ""

-- Indentation
set.expandtab = true
set.shiftwidth = 2
set.tabstop = 2
set.softtabstop = 2
set.smartindent = true
set.autoindent = true

-- Search
set.ignorecase = true
set.smartcase = true
set.hlsearch = true
set.incsearch = true

-- UI
wset.signcolumn = "yes:1"
set.cmdheight = 0
set.completeopt = "menuone,noinsert,noselect"
set.splitright = true
set.splitbelow = true

-- Memory & Undo
set.history = 10000
set.undolevels = 1000

-- === Arrow Key Blackout (No Closures) ===
local set_nop = vim.keymap.set
set_nop("n", "<Up>", "<Nop>", { desc = "Arrow Disabled" })
set_nop("n", "<Down>", "<Nop>", { desc = "Arrow Disabled" })
set_nop("n", "<Left>", "<Nop>", { desc = "Arrow Disabled" })
set_nop("n", "<Right>", "<Nop>", { desc = "Arrow Disabled" })
set_nop("v", "<Up>", "<Nop>", { desc = "Arrow Disabled" })
set_nop("v", "<Down>", "<Nop>", { desc = "Arrow Disabled" })
set_nop("v", "<Left>", "<Nop>", { desc = "Arrow Disabled" })
set_nop("v", "<Right>", "<Nop>", { desc = "Arrow Disabled" })

-- === Whitespace Cleaner ===
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("TrimWhitespace", { clear = true }),
  pattern = "*",
  callback = function()
    local view = vim.fn.winsaveview()
    vim.cmd("silent! keepjumps %s/\\s\\+$//e")
    vim.fn.winrestview(view)
  end,
})

-- === Large FileType Optimization (Conditional) ===
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("LargeFileOpts", { clear = true }),
  pattern = { "json", "yaml", "markdown" },
  callback = function()
    local line_count = vim.fn.line("$")
    if line_count > 1000 then
      vim.opt_local.foldmethod = "manual"
      vim.opt_local.synmaxcol = 300
    else
      vim.opt_local.foldmethod = "indent"
      vim.opt_local.synmaxcol = 500
    end
  end,
})

-- === Delayed Non-Critical Initialization ===
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Restore shada (expensive; deferred)
    vim.o.shadafile = ""
    vim.o.shada = "!,'100,<50,s10,h"
    local file = vim.fn.stdpath("data") .. "/shada/main.shada"
    if vim.fn.filereadable(file) == 1 then
      pcall(vim.cmd, "silent! rshada")
    end
    -- Enable clipboard
    vim.o.clipboard = "unnamedplus"
  end,
})
