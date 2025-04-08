-- Performance Optimization
vim.loader.enable()

-- Reduce updatetime for faster response
vim.opt.updatetime = 100

-- More efficient redrawing
vim.opt.lazyredraw = true

-- Improve startup with better shada handling
vim.opt.shadafile = "NONE"

vim.schedule(function()
  vim.opt.shadafile = ""
  vim.cmd("silent! rshada")
  vim.opt.clipboard = 'unnamed,unnamedplus'
end)

-- Indentation and tab settings
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Search settings
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true

-- Enhanced undo settings
vim.opt.undofile = true
vim.opt.undolevels = 1000

-- File Management
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

-- Editor Settings
vim.opt.number = true
vim.opt.relativenumber = true  -- More efficient navigation
vim.opt.scrolloff = 10
vim.opt.sidescrolloff = 8     -- Horizontal scrolloff
vim.opt.wrap = false
vim.opt.breakindent = true
vim.opt.showcmd = true
vim.opt.showmode = true
vim.opt.showmatch = true
vim.opt.history = 1000        -- Increased history
vim.opt.timeout = true
vim.opt.timeoutlen = 500      -- Faster key sequence completion
vim.opt.ttimeoutlen = 10      -- Faster mode switching
vim.opt.completeopt = "menuone,noselect,noinsert"  -- Better completion experience

-- Improve UI Experience
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.list = true

-- Disable Arrow Keys
vim.keymap.set("", "<Up>", "<Nop>", { desc = "Disable Up Arrow" })
vim.keymap.set("", "<Down>", "<Nop>", { desc = "Disable Down Arrow" })
vim.keymap.set("", "<Left>", "<Nop>", { desc = "Disable Left Arrow" })
vim.keymap.set("", "<Right>", "<Nop>", { desc = "Disable Right Arrow" })

-- Disable mouse
vim.opt.mouse = ""

-- Performance optimization for syntax highlighting
vim.opt.synmaxcol = 200

-- Use faster built-in pattern matching for finding files
vim.opt.path = ".,,"

-- Optimize for large files
vim.opt.maxmempattern = 3000  -- Increase memory available for pattern matching
vim.opt.hidden = true
vim.opt.redrawtime = 1500
vim.opt.ttyfast = true

-- Efficiently remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    -- Store view state
    local view = vim.fn.winsaveview()

    -- Use vim.cmd for better performance with complex regex operations
    vim.cmd([[keeppatterns %s/\s\+$//e]])

    -- Restore view
    vim.fn.winrestview(view)
  end,
  group = vim.api.nvim_create_augroup("CleanupTrailingWhitespace", { clear = true })
})
