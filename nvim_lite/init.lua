-- === Startup Optimization ===
-- Enable the new loader if available and not already enabled.
if vim.loader and not vim.loader.enabled then
  vim.loader.enable()
end

-- Shorthand for option tables
local set   = vim.o   -- global options
local wset  = vim.wo  -- window options
local bset  = vim.bo  -- buffer options

-- === Performance and Resource Management ===
set.mouse         = ""                -- Disable mouse support; enterprise interfaces may want strict key-based input.
set.updatetime    = 100               -- Faster responsiveness
set.lazyredraw    = true              -- Only redraw when needed
set.ttyfast       = true              -- Optimization for fast terminal redraw
set.synmaxcol     = 200               -- Limit syntax highlighting width for performance
set.redrawtime    = 1000              -- Max time for full redraw
set.maxmempattern = 2000              -- Cap pattern search memory
set.shadafile     = "NONE"            -- Defer persistent state; enterprise setups defer read/write.

-- === UI and Editing Experience ===
set.number        = true              -- Show absolute line numbers
wset.relativenumber = true           -- And relative line numbers for context
set.scrolloff     = 10                -- Keep a buffer of lines when scrolling
set.sidescrolloff = 8                 -- Horizontal padding
wset.wrap         = false             -- Disable wrapping (preferred in coding environments)
wset.linebreak    = false             -- No automatic line breaks
wset.breakindent  = false             -- No break indent

set.showmode      = false             -- Status bar for mode can be handled by enterprise statusline solutions
set.undofile      = true              -- Enable persistent undo for large datasets
set.swapfile      = false             -- Avoid swap files in streamlined setups
set.backup        = false             -- Enterprise deployments handle version control separately
set.writebackup   = false             -- Disable redundant writes

set.timeoutlen    = 500               -- Faster timeout for mapped sequences
set.ttimeoutlen   = 10                -- Faster keycode timeouts
set.keymodel      = ""                -- Avoid legacy keymodel semantics

-- === Indentation and Formatting ===
set.expandtab     = true              -- Use spaces over tabs
set.shiftwidth    = 2                 -- Indentation width
set.tabstop       = 2                 -- Visual tab width
set.softtabstop   = 2                 -- Soft tab alignment
set.smartindent   = true              -- Auto-indent new lines intelligently
set.autoindent    = true              -- Continuation indent

-- === Search Enhancements ===
set.ignorecase    = true              -- Case insensitive search by default
set.smartcase     = true              -- Use case sensitivity if capitals are used
set.hlsearch      = true              -- Highlight search results
set.incsearch     = true              -- Incremental search feedback

-- === Interface Customization ===
wset.signcolumn   = "yes:1"           -- Always show sign column to avoid shifting the text
set.cmdheight     = 0                 -- Maximize screen real estate
set.completeopt   = "menuone,noinsert,noselect" -- Better completion experience
set.splitright    = true              -- New vertical splits on the right
set.splitbelow    = true              -- New horizontal splits below

-- === Memory and Undo Persistence ===
set.history       = 10000             -- Long command history
set.undolevels    = 1000              -- Extended undo levels

-- === Arrow Key Blackout (Force Keyboard Discipline) ===
local set_nop = vim.keymap.set
-- Enterprise loop to disable arrow keys in Normal and Visual modes:
for _, mode in ipairs({"n", "v"}) do
  for _, arrow in ipairs({"<Up>", "<Down>", "<Left>", "<Right>"}) do
    set_nop(mode, arrow, "<Nop>", { desc = "Arrow Disabled" })
  end
end

-- === Whitespace Cleaner (Pre-Save Hook) ===
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("EnterpriseTrimWhitespace", { clear = true }),
  pattern = "*",
  callback = function()
    local view = vim.fn.winsaveview()  -- Save current window state
    vim.cmd("silent! keepjumps %s/\\s\\+$//e")  -- Remove trailing whitespace
    vim.fn.winrestview(view)  -- Restore window state
  end,
})

-- === Adaptive Optimization for Large Files ===
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("EnterpriseLargeFileOpts", { clear = true }),
  pattern = { "json", "yaml", "markdown" },
  callback = function()
    local line_count = vim.fn.line("$")
    if line_count > 1000 then
      vim.opt_local.foldmethod = "manual"  -- Manual folding for performance
      vim.opt_local.synmaxcol   = 300         -- Reduce syntax processing overhead
    else
      vim.opt_local.foldmethod = "indent"   -- Indentation-based folding in normal cases
      vim.opt_local.synmaxcol   = 500         -- Slightly relaxed for smaller files
    end
  end,
})

-- === Deferred Non-Critical Initialization ===
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Restore shada settings after initial startup; enterprise setups might persist session state externally.
    vim.o.shadafile = ""
    vim.o.shada = "!,'100,<50,s10,h"
    local shada_path = vim.fn.stdpath("data") .. "/shada/main.shada"
    if vim.fn.filereadable(shada_path) == 1 then
      pcall(vim.cmd, "silent! rshada")
    end

    -- Set system clipboard integration (critical for enterprise copy-paste)
    vim.o.clipboard = "unnamedplus"

    -- Placeholder: Initialize additional enterprise modules (e.g., LSP, Git integration, custom logging, etc.)
    -- vim.schedule(function() require("enterprise.plugins").init() end)
  end,
})

-- === Integrated Statusline with Inline Search Count ===
-- Mode map to human-readable form
local mode_map = {
  n = "NORMAL",      no = "N·OP",         nov = "N·OP",
  i = "INSERT",      ic = "INS·COMP",     ix = "INS·X",
  v = "VISUAL",      V = "V·LINE",        [""] = "V·BLOCK",
  c = "COMMAND",     cv = "VIM·EX",       ce = "EX",
  r = "REPLACE",     R = "REPLACE",       Rx = "REPL·X",
  s = "SELECT",      S = "S·LINE",        [""] = "S·BLOCK",
  t = "TERMINAL"
}

-- Return current mode (fallback safe)
_G.get_mode = function()
  local mode = vim.api.nvim_get_mode().mode
  return mode_map[mode] or ("MODE(" .. vim.fn.escape(mode, ' ') .. ")")
end

-- Return current search count
_G.search_info = function()
  local ok, s = pcall(vim.fn.searchcount, { maxcount = 0, timeout = 100 })
  if ok and s and s.total and s.total > 0 then
    return string.format(" %d/%d", s.current or 0, s.total)
  end
  return ""
end

-- Set statusline
vim.o.statusline = table.concat({
  " %{v:lua.get_mode()} ",        -- Mode indicator
  "%f ",                          -- File path
  "%h%m%r",                       -- Help, Modified, Readonly flags
  "%=",                           -- Alignment separator
  "Ln %l/%L, Col %c",                -- Line & column
  "%{v:lua.search_info()}",       -- Inline search result count
  " %P",                          -- Percentage through file
})

-- === ESC Behavior Enhancement (No Highlight Search) ===
-- Function to clear search highlight when pressing Esc

local function clear_search_highlight()
  -- Check if hlsearch is active, if so, clear it
  if vim.v.hlsearch == 1 then
    vim.cmd("nohlsearch")
  end
  return "<Esc>"
end

-- Registering the keymap for normal mode
vim.keymap.set("n", "<Esc>", clear_search_highlight, {
  expr = true,
  silent = true,
  noremap = true,
  desc = "Clear search highlight on Esc"
})


-- Enforce Unix-only line endings
vim.opt.fileformats = { "unix" }
vim.opt.fileformat = "unix"

-- Define dedicated group
local crlf_group = vim.api.nvim_create_augroup("crlf_guard", { clear = true })

-- Pure function to strip carriage returns efficiently
local function strip_cr()
  -- Early exits for non-editable or untyped buffers
  if vim.bo.buftype ~= "" or vim.bo.modifiable == false then return end

  -- Efficient regex match using fast scanning
  if vim.fn.search('\r', 'nw') ~= 0 then
    -- Use native Lua API to edit buffer lines
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i, line in ipairs(lines) do
      if line:find('\r') then
        lines[i] = line:gsub('\r', '')
      end
    end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

    -- Enforce Unix format
    vim.bo.fileformat = "unix"
  end
end

-- Generic event wrapper with view preservation
local function with_preserved_view(callback)
  return function()
    local ok, view = pcall(vim.fn.winsaveview)
    pcall(callback)
    if ok then pcall(vim.fn.winrestview, view) end
  end
end

-- Register post-read and file-change hook
vim.api.nvim_create_autocmd({ "BufReadPost", "FileChangedShellPost" }, {
  group = crlf_group,
  pattern = "*",
  callback = with_preserved_view(strip_cr),
})

-- Strip CR before write
vim.api.nvim_create_autocmd("BufWritePre", {
  group = crlf_group,
  pattern = "*",
  callback = strip_cr,
})
