-- === Startup Optimization ===
-- Enable the new loader if available and not already enabled.
if vim.loader and not vim.loader.enabled then
  vim.loader.enable()
end

-- Shorthand for option tables
local set   = vim.o   -- global options
local pset  = vim.opt
local wset  = vim.wo  -- window options
local bset  = vim.bo  -- buffer options
local cset  = vim.cmd -- cmd options
local fset  = vim.fn
local aset  = vim.api -- api options
local kset  = vim.keymap
local lset  = vim.opt_local

-- === Performance and Resource Management ===
set.mouse         = ""                -- Disable mouse support; enterprise interfaces may want strict key-based input.
set.updatetime    = 100               -- Faster responsiveness
set.lazyredraw    = true              -- Only redraw when needed
set.ttyfast       = true              -- Optimization for fast terminal redraw
set.synmaxcol     = 200               -- Limit syntax highlighting width for performance
set.redrawtime    = 1000              -- Max time for full redraw
set.maxmempattern = 2000              -- Cap pattern search memory
set.shadafile     = "NONE"            -- Defer persistent state; enterprise setups defer read/write.

-- Tabline highlight groups
aset.nvim_set_hl(0, 'TabLine', { fg = '#808080', bg = '#1e1e1e' })
aset.nvim_set_hl(0, 'TabLineSel', { fg = '#ffffff', bg = '#3a3a3a', bold = true })
aset.nvim_set_hl(0, 'TabLineFill', { fg = 'NONE', bg = '#1e1e1e' })

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

set.timeoutlen    = 300               -- Faster timeout for mapped sequences
set.ttimeoutlen   = 40                -- Faster keycode timeouts
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
local set_nop = kset.set
-- Enterprise loop to disable arrow keys in Normal and Visual modes:
for _, mode in ipairs({"n", "v"}) do
  for _, arrow in ipairs({"<Up>", "<Down>", "<Left>", "<Right>"}) do
    set_nop(mode, arrow, "<Nop>", { desc = "Arrow Disabled" })
  end
end

-- === Whitespace Cleaner (Pre-Save Hook) ===
aset.nvim_create_autocmd("BufWritePre", {
  group = aset.nvim_create_augroup("EnterpriseTrimWhitespace", { clear = true }),
  pattern = { "*.java", "*.js", "*.c", "*.cpp", "*.py", "*.lua" },
  callback = function()
    if bset.modified then
      local view = fset.winsaveview()  -- Save current window state
      cset("silent! keepjumps %s/\\s\\+$//e")  -- Remove trailing whitespace
      fset.winrestview(view)  -- Restore window state
    end
  end,
})

-- === Adaptive Optimization for Large Files ===
aset.nvim_create_autocmd("FileType", {
  group = aset.nvim_create_augroup("EnterpriseLargeFileOpts", { clear = true }),
  pattern = { "json", "yaml", "markdown" },
  callback = function()
    local line_count = fset.line("$")
    if line_count > 1000 then
      lset.foldmethod = "manual"  -- Manual folding for performance
      lset.synmaxcol   = 300         -- Reduce syntax processing overhead
    else
      lset.foldmethod = "indent"   -- Indentation-based folding in normal cases
      lset.synmaxcol   = 500         -- Slightly relaxed for smaller files
    end
  end,
})

-- === Deferred Non-Critical Initialization ===
aset.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      set.shadafile = ""
      set.shada = "!,'100,<50,s10,h"
      local shada_path = fset.stdpath("data") .. "/shada/main.shada"
      if fset.filereadable(shada_path) == 1 then
        pcall(cset, "silent! rshada")
      end
      set.clipboard = "unnamedplus"
    end, 100)
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
  local mode = aset.nvim_get_mode().mode
  return mode_map[mode] or ("MODE(" .. fset.escape(mode, ' ') .. ")")
end

-- Return current search count
_G.search_info = function()
  local ok, s = pcall(fset.searchcount, { maxcount = 0, timeout = 100 })
  if ok and s and s.total and s.total > 0 then
    return string.format(" %d/%d", s.current or 0, s.total)
  end
  return ""
end

-- Set statusline
set.statusline = table.concat({
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
    cset("nohlsearch")
  end
  return "<Esc>"
end

-- Registering the keymap for normal mode
kset.set("n", "<Esc>", clear_search_highlight, {
  expr = true,
  silent = true,
  noremap = true,
  desc = "Clear search highlight on Esc"
})


-- Enforce Unix-only line endings
pset.fileformats = { "unix" }
pset.fileformat = "unix"

-- Define dedicated group
local crlf_group = aset.nvim_create_augroup("crlf_guard", { clear = true })

-- Pure function to strip carriage returns efficiently
local function strip_cr()
  -- Early exits for non-editable or untyped buffers
  if bset.buftype ~= "" or bset.modifiable == false then return end

  -- Efficient regex match using fast scanning
  if fset.search('\r', 'nw') ~= 0 then
    -- Use native Lua API to edit buffer lines
    local lines = aset.nvim_buf_get_lines(0, 0, -1, false)
    for i, line in ipairs(lines) do
      if line:find('\r') then
        lines[i] = line:gsub('\r', '')
      end
    end
    aset.nvim_buf_set_lines(0, 0, -1, false, lines)

    -- Enforce Unix format
    bset.fileformat = "unix"
  end
end

-- Generic event wrapper with view preservation
local function with_preserved_view(callback)
  return function()
    local ok, view = pcall(fset.winsaveview)
    pcall(callback)
    if ok then pcall(fset.winrestview, view) end
  end
end

-- Register post-read and file-change hook
aset.nvim_create_autocmd({ "BufReadPost", "FileChangedShellPost" }, {
  group = crlf_group,
  pattern = "*",
  callback = with_preserved_view(strip_cr),
})

-- Strip CR before write
aset.nvim_create_autocmd("BufWritePre", {
  group = crlf_group,
  pattern = "*",
  callback = strip_cr,
})

-- === Zen Mode Configuration ===

local function set_numeric_tabline()
  set.tabline = '%!v:lua.tabline_numbers()'
end

function _G.tabline_numbers()
  local s = ''
  local current_tab = fset.tabpagenr()

  for i = 1, fset.tabpagenr('$') do
    local winnr = fset.tabpagewinnr(i)
    local buflist = fset.tabpagebuflist(i)
    local bufnr = buflist[winnr]
    local bufname = fset.bufname(bufnr)
    local modified = fset.getbufvar(bufnr, '&modified') == 1 and '+' or ''

    -- Highlight current tab with different colors
    if i == current_tab then
      s = s .. '%#TabLineSel# ' .. i .. modified .. ' %#TabLineFill#'
    else
      s = s .. '%#TabLine# ' .. i .. modified .. ' %#TabLineFill#'
    end
  end

  return s
end

local zen_mode = {
  active = false,
  saved = {},
  config = {
    syntax       = false,
    number       = false,
    relativenumber = false,
    cursorline   = false,
    showcmd      = false,
    showmatch    = false,
    laststatus   = 0,
    cmdheight    = 0,
    signcolumn   = "no",
  }
}

local syntax_cmd = { on = "syntax on", off = "syntax off" }

-- Utility: Apply settings from table
local setters = {
  syntax       = function(v) cset(syntax_cmd[v and "on" or "off"]) end,
  number       = function(v) wset.number = v end,
  relativenumber = function(v) wset.relativenumber = v end,
  cursorline   = function(v) set.cursorline = v end,
  showcmd      = function(v) set.showcmd = v end,
  showmatch    = function(v) set.showmatch = v end,
  laststatus   = function(v) set.laststatus = v end,
  cmdheight    = function(v) set.cmdheight = v end,
  signcolumn   = function(v) wset.signcolumn = v end,
}

-- Apply settings to the current window
local function apply_settings(tbl)
  for k,v in pairs(tbl) do
    setters[k](v)
  end
end

-- Apply zen mode settings to all windows
local function apply_to_all_windows(settings)
  -- First apply global options
  for k, v in pairs(settings) do
    if k ~= "number" and k ~= "relativenumber" and k ~= "signcolumn" then
      if setters[k] then setters[k](v) end
    end
  end

  -- Then apply window-local options to each window
  for _, win in ipairs(aset.nvim_list_wins()) do
    aset.nvim_win_call(win, function()
      if settings.number ~= nil then wset.number = settings.number end
      if settings.relativenumber ~= nil then wset.relativenumber = settings.relativenumber end
      if settings.signcolumn ~= nil then wset.signcolumn = settings.signcolumn end
    end)
  end
end

-- Zen toggle handler
local function toggle_zen_mode()
  if zen_mode._busy then return end
  zen_mode._busy = true
  vim.schedule(function()
    zen_mode._busy = false
  end)

  zen_mode.active = not zen_mode.active

  if zen_mode.active then
    -- Save current state for full reversibility
    zen_mode.saved = {
      syntax       = set.syntax ~= "off",
      number       = wset.number,
      relativenumber = wset.relativenumber,
      cursorline   = set.cursorline,
      showcmd      = set.showcmd,
      showmatch    = set.showmatch,
      laststatus   = set.laststatus,
      cmdheight    = set.cmdheight,
      signcolumn   = wset.signcolumn,
      tabline = set.tabline,
      statusline_hl = aset.nvim_get_hl(0, { name = "StatusLine", link = false }),
    }
    apply_to_all_windows(zen_mode.config)
    set_numeric_tabline()
    aset.nvim_set_hl(0, "StatusLine", {
      bg = "NONE",  -- transparent background
      fg = zen_mode.saved.statusline_hl.fg or "#ffffff",
      bold = zen_mode.saved.statusline_hl.bold or false,
    })
  else
    apply_to_all_windows(zen_mode.saved)
    set.tabline = zen_mode.saved.tabline
    if zen_mode.saved.statusline_hl then
      aset.nvim_set_hl(0, "StatusLine", zen_mode.saved.statusline_hl)
    end
  end
end

-- Keymap: Double space to toggle Zen
kset.set("n", "<Space><Space>", toggle_zen_mode, {
  desc = "Toggle Zen Mode",
  noremap = true,
  silent = true,
})

-- Create autocommands to maintain zen mode settings for new windows/buffers
local zen_group = aset.nvim_create_augroup("ZenModeAuto", { clear = true })

-- Apply zen settings when creating new windows
aset.nvim_create_autocmd({"WinNew", "WinEnter"}, {
  group = zen_group,
  callback = function()
    if zen_mode.active then
      -- Apply zen settings to the current window
      wset.number = zen_mode.config.number
      wset.relativenumber = zen_mode.config.relativenumber
      wset.signcolumn = zen_mode.config.signcolumn
    end
  end
})
