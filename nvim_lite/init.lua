-- === Startup Optimization ===
-- Enable the new loader if available and not already enabled.
if vim.loader and not vim.loader.enabled then
  vim.loader.enable()
end

-- Shorthand for option tables
local set   = vim.o   -- global options
local pset  = vim.opt
local wset  = vim.wo  -- window options
local cset  = vim.cmd -- cmd options
local fset  = vim.fn
local aset  = vim.api -- api options
local kset  = vim.keymap
local lset  = vim.opt_local
local vset  = vim.v
local bset  = vim.bo

-- === Disable matchparen plugin ===
vim.g.loaded_matchparen = 1

-- === Disable heavy plugins ===
pset.cursorline = false
pset.cursorcolumn = false

-- === Performance and Resource Management ===
set.mouse         = ""                -- Disable mouse support
set.updatetime    = 100               -- Faster responsiveness
set.lazyredraw    = true              -- Only redraw when needed
set.synmaxcol     = 200               -- Limit syntax highlighting width for performance
set.redrawtime    = 1000              -- Max time for full redraw
set.maxmempattern = 2000              -- Cap pattern search memory

-- === Disable LSP Logging ===
vim.defer_fn(function()
  vim.env.NVIM_LSP_LOG_FILE = vim.loop.os_uname().sysname == "Windows_NT" and "NUL" or "/dev/null"
  pcall(vim.lsp.set_log_level, "OFF")
end, 100)

-- Tabline highlight groups
aset.nvim_set_hl(0, 'TabLine', { fg = '#808080', bg = '#1e1e1e' })
aset.nvim_set_hl(0, 'TabLineSel', { fg = '#ffffff', bg = '#3a3a3a', bold = true })
aset.nvim_set_hl(0, 'TabLineFill', { fg = 'NONE', bg = '#1e1e1e' })

-- === UI and Editing Experience ===
set.number        = true              -- Show absolute line numbers
wset.relativenumber = false           -- Disabled relative line numbers
set.scrolloff     = 10                -- Keep a buffer of lines when scrolling
set.sidescrolloff = 8                 -- Horizontal padding
wset.wrap         = false             -- Disable wrapping (preferred in coding environments)
wset.linebreak    = false             -- No automatic line breaks
wset.breakindent  = false             -- No break indent
pset.termguicolors = true             -- enabling richer themes

set.showmode      = false
set.undofile      = true              -- Enable persistent undo for large datasets
set.swapfile      = false             -- Avoid swap files in streamlined setups
set.backup        = false
set.writebackup   = false             -- Disable redundant writes

set.timeoutlen    = 300               -- Faster timeout for mapped sequences
set.ttimeoutlen   = 40                -- Faster keycode timeouts
set.keymodel      = ""                -- Avoid legacy keymodel semantics

-- ============================================
-- SYNTAX AND LARGE FILE OPTIMIZATION
-- ============================================

aset.nvim_create_autocmd("FileType", {
  group = aset.nvim_create_augroup("PerfFileTypeHandler", { clear = true }),
  pattern = { "*" },
  callback = function(args)
    local ft = args.match
    local line_count = fset.line("$")

    if vim.tbl_contains({ "c", "cpp", "java", "python", "lua", "javascript", "typescript" }, ft) then
      cset("syntax sync minlines=200")
      cset("syntax sync maxlines=500")
    end

    if vim.tbl_contains({ "json", "yaml", "markdown", "text", "plaintex" }, ft) then
      if line_count > 1000 then
        lset.foldmethod   = "manual"
        lset.synmaxcol    = 300
        lset.wrap         = true
        lset.linebreak    = true
        lset.breakindent  = true
      else
        lset.foldmethod   = "indent"
        lset.synmaxcol    = 500
        lset.wrap         = false
        lset.linebreak    = false
        lset.breakindent  = false
      end
    end
  end
})

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
-- Loop to disable arrow keys in Normal and Visual modes:
for _, mode in ipairs({"n", "v"}) do
  for _, arrow in ipairs({"<Up>", "<Down>", "<Left>", "<Right>"}) do
    set_nop(mode, arrow, "<Nop>", { desc = "Arrow Disabled" })
  end
end

-- Fast Lua-native trailing whitespace cleaner
local function trim_trailing_whitespace()
  if not bset.modifiable or not bset.modified then return end

  if fset.line("$") >= 1000 then return end -- short-circuit large files

  local bufnr = aset.nvim_get_current_buf()
  local changed = false
  local lines = aset.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i = 1, #lines do
    local orig = lines[i]
    local trimmed = orig:match("^(.-)%s*$")
    if orig ~= trimmed then
      lines[i] = trimmed
      changed = true
    end
  end

  if changed then
    local view = fset.winsaveview()
    aset.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    fset.winrestview(view)
  end
end

-- === Whitespace Cleaner (Pre-Save Hook) ===
aset.nvim_create_autocmd("BufWritePre", {
  group = aset.nvim_create_augroup("TrimWhitespace", { clear = true }),
  pattern = { "*.lua", "*.c", "*.cpp", "*.py", "*.js", "*.java" },
  callback = trim_trailing_whitespace
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
  "%t %y",                          -- File path
  "%h%m%r",                       -- Help, Modified, Readonly flags
  "%=",                           -- Alignment separator
  "Ln %l/%L, Col %c",                -- Line & column
  "%{v:lua.search_info()}",       -- Inline search result count
  " %P",                          -- Percentage through file
})

-- === Fast Clear Highlight on <Esc> ===
-- Local, reusable function (non-capturing, no closure, no allocs)
local function clear_hlsearch_if_active()
  if vset.hlsearch ~= 1 then return "<Esc>" end
  cset("nohlsearch")  -- no pure API for this yet
  return "<Esc>"
end

-- Insert mode: exit Insert, then clear highlight (deferred)
kset.set("i", "<Esc>", function()
  vim.schedule(function()
    if vset.hlsearch == 1 then
      cset("nohlsearch")
    end
  end)
  return "<Esc>"
end, {
  expr = true,
  silent = true,
  noremap = true,
  desc = "Fast clear hlsearch on <Esc> from Insert"
})

-- Normal mode: inline fast-path with guard
kset.set("n", "<Esc>", clear_hlsearch_if_active, {
  expr = true,
  silent = true,
  noremap = true,
  desc = "Fast clear hlsearch on <Esc> from Normal"
})

-- === Zen Mode Configuration ===

-- === Zen Mode State ===
_G.zen_mode = {
  active = false,
  saved  = {},
  config = {
    syntax     = false,
    number     = false,
    showcmd    = false,
    laststatus = 0,
    cmdheight  = 0,
    signcolumn = "no",
  },
}

function _G.tabline_numbers()
  local result = {}
  local current = fset.tabpagenr()
  local total = fset.tabpagenr('$')
  local zen = _G.zen_mode.active

  for i = 1, total do
    local hl = (i == current) and '%#TabLineSel#' or '%#TabLine#'
    local label = tostring(i)
    local buflist = fset.tabpagebuflist(i)
    local winnr = fset.tabpagewinnr(i)
    local bufnr = buflist[winnr] or 0

    if fset.bufexists(bufnr) == 1 then
      local mod = (fset.getbufvar(bufnr, '&modified') == 1) and '+' or ''
      if not zen then
        local name = fset.fnamemodify(fset.bufname(bufnr), ':t')
        name = (name ~= "") and name or '[No Name]'
        label = label .. ':' .. name .. mod
      else
        label = label .. mod
      end
    end

    result[#result+1] = hl .. ' ' .. label .. ' '
  end

  return table.concat(result) .. '%#TabLineFill#'
end

-- Always use our Lua tabline renderer:
set.tabline = '%!v:lua.tabline_numbers()'

local syntax_cmd = { on = "syntax on", off = "syntax off" }

-- Utility: Apply settings from table
local setters = {
  syntax       = function(v) cset(syntax_cmd[v and "on" or "off"]) end,
  number       = function(v) wset.number = v end,
  showcmd      = function(v) set.showcmd = v end,
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
    if k ~= "number" and k ~= "signcolumn" then
      if setters[k] then setters[k](v) end
    end
  end

  -- Then apply window-local options to each window
  for _, win in ipairs(aset.nvim_list_wins()) do
    aset.nvim_win_call(win, function()
      if settings.number ~= nil then wset.number = settings.number end
      if settings.signcolumn ~= nil then wset.signcolumn = settings.signcolumn end
    end)
  end
end

-- Zen toggle handler
local function toggle_zen_mode()
  if _G.zen_mode._busy then return end
  _G.zen_mode._busy = true
  vim.schedule(function() _G.zen_mode._busy = false end)

  -- flip state
  _G.zen_mode.active = not _G.zen_mode.active

  -- apply ui settings
  if _G.zen_mode.active then
    -- save only the things you actually want to revert...
    _G.zen_mode.saved = {
      syntax     = set.syntax ~= "off",
      number     = wset.number,
      showcmd    = set.showcmd,
      laststatus = set.laststatus,
      cmdheight  = set.cmdheight,
      signcolumn = wset.signcolumn,
      status_hl  = aset.nvim_get_hl(0, { name = "StatusLine", link = false }),
    }
    apply_to_all_windows(_G.zen_mode.config)
    -- no tabline touch here
    aset.nvim_set_hl(0, "StatusLine", {
      bg   = "NONE",
      fg   = _G.zen_mode.saved.status_hl.fg or "#ffffff",
      bold = _G.zen_mode.saved.status_hl.bold or false,
    })
  else
    -- restore exactly what you saved
    apply_to_all_windows(_G.zen_mode.saved)
    if _G.zen_mode.saved.status_hl then
      aset.nvim_set_hl(0, "StatusLine", _G.zen_mode.saved.status_hl)
    end
    -- again, no tabline touch
  end

  -- finally: force a redraw so tabline will re-evaluate
  cset('redrawtabline')
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
      wset.signcolumn = zen_mode.config.signcolumn
    end
  end
})

-- ================================
-- TAB-TO-SPACES CONVERTER
-- ================================
local convert_tabs_to_spaces = function()
  if not bset.modifiable then return end -- skip uneditable buffers

  local buf = aset.nvim_get_current_buf()
  local tabstop = bset.tabstop
  local lines = aset.nvim_buf_get_lines(buf, 0, -1, false)

  local any_changed = false
  local update_lines = {}

  for i = 1, #lines do
    local line = lines[i]
    if not line:find("\t", 1, true) then
      update_lines[i] = false -- no tab, skip
    else
      local col = 0
      local new_line = {}
      local changed = false

      for j = 1, #line do
        local c = line:sub(j, j)
        if c == "\t" then
          local spaces = tabstop - (col % tabstop)
          new_line[#new_line+1] = string.rep(" ", spaces) -- insert spaces
          col = col + spaces
          changed = true
        else
          new_line[#new_line+1] = c -- keep char
          col = col + 1 -- assume ASCII
        end
      end

      if changed then
        update_lines[i] = table.concat(new_line) -- save updated
        any_changed = true
      else
        update_lines[i] = false -- no actual change
      end
    end
  end

  if not any_changed then return end -- nothing to do

  local view = fset.winsaveview() -- save cursor

  for i, updated in pairs(update_lines) do
    if updated then
      aset.nvim_buf_set_lines(buf, i-1, i, false, { updated }) -- write changed
    end
  end

  fset.winrestview(view) -- restore cursor
end

aset.nvim_create_autocmd("BufWritePre", {
  group = aset.nvim_create_augroup("ConvertTabsToSpaces", { clear = true }), -- setup group
  pattern = "*", -- all files
  callback = convert_tabs_to_spaces, -- hook on save
})
