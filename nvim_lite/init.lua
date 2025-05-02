-- Enable Lua module caching for faster startup
vim.loader.enable()

-- Performance Optimizations
vim.opt.updatetime = 100       -- Faster CursorHold events
vim.opt.lazyredraw = true      -- Delay redraw during macro execution
vim.opt.shadafile = "NONE"     -- Disable shada during startup
vim.opt.ttyfast = true         -- Faster terminal rendering
vim.opt.synmaxcol = 200        -- Limit syntax highlighting to 200 columns
vim.opt.mouse = ""             -- Disable mouse support
vim.opt.redrawtime = 1500      -- Allow more time for redrawing
vim.opt.maxmempattern = 3000   -- Allocate more memory for pattern matching

-- Improved startup sequence
vim.schedule(function()
  -- Restore shada after initial load
  vim.opt.shada = "!,'100,<50,s10,h"  -- Limit shada history
  vim.opt.shadafile = ""
  vim.cmd.rshada()

  -- Clipboard integration
  vim.opt.clipboard = 'unnamedplus'  -- Use system clipboard
end)

-- Core Editor Configuration
vim.opt.number = true
vim.opt.relativenumber = true   -- More efficient line navigation
vim.opt.scrolloff = 10          -- Keep context lines visible
vim.opt.sidescrolloff = 8       -- Horizontal scroll context
vim.opt.wrap = false            -- No line wrapping
vim.opt.linebreak = true        -- Break lines at words
vim.opt.breakindent = true      -- Maintain indentation on wrap
vim.opt.showmode = false        -- Disable mode text (use statusline)

-- File Management
vim.opt.undofile = true         -- Persistent undo history
vim.opt.swapfile = false        -- Disable swap files
vim.opt.backup = false          -- Disable backups
vim.opt.writebackup = false     -- Disable write backups

-- Input Configuration
vim.opt.timeoutlen = 500        -- Faster key sequence timeout
vim.opt.ttimeoutlen = 10        -- Faster key code timeout
vim.opt.keymodel = ''           -- Disable key model extensions

-- Disable Arrow Keys in Normal/Visual modes
local disable_arrow_keys = function(map)
  vim.keymap.set({'n', 'v'}, map, '<Nop>', { desc = 'Disabled arrow key' })
end
disable_arrow_keys('<Up>')
disable_arrow_keys('<Down>')
disable_arrow_keys('<Left>')
disable_arrow_keys('<Right>')

-- Efficient Whitespace Management
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  group = vim.api.nvim_create_augroup('TrimWhitespace', { clear = true }),
  callback = function()
    local save_view = vim.fn.winsaveview()
    vim.cmd([[keepjumps %s/\s\+$//e]])
    vim.fn.winrestview(save_view)
  end
})

-- Improved Syntax Highlighting Performance
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'json', 'yaml', 'markdown' },
  group = vim.api.nvim_create_augroup('LargeFileOpts', { clear = true }),
  callback = function()
    vim.opt_local.foldmethod = 'indent'
    vim.opt_local.synmaxcol = 500
  end
})

-- Advanced Indentation Settings
vim.opt.expandtab = true        -- Use spaces for tabs
vim.opt.shiftwidth = 2          -- >> indentation size
vim.opt.tabstop = 2             -- \t display width
vim.opt.softtabstop = 2         -- Tab key indentation
vim.opt.smartindent = true      -- Context-aware indentation
vim.opt.autoindent = true       -- Maintain current indentation

-- Search Optimization
vim.opt.ignorecase = true       -- Case-insensitive search
vim.opt.smartcase = true         -- Case-sensitive when uppercase present
vim.opt.hlsearch = true          -- Highlight matches
vim.opt.incsearch = true         -- Show partial matches

-- UI Enhancements
vim.opt.signcolumn = 'yes:1'    -- Always show sign column
vim.opt.cmdheight = 0           -- Use floating command line (0.9+)
vim.opt.completeopt = 'menuone,noinsert,noselect'  -- Better completion
vim.opt.splitright = true       -- Vertical splits to the right
vim.opt.splitbelow = true       -- Horizontal splits below

-- Memory Optimization
vim.opt.history = 10000         -- Corrected to actually increase history
vim.opt.undolevels = 1000       -- More persistent undo history
