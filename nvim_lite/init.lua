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
local vset  = vim.v
local gset = vim.g

local jumpstate = {
  char = nil,
  dir = nil,
}

-- === Disable matchparen plugin ===
gset.loaded_matchparen = 1

-- === Disable heavy plugins ===
pset.cursorline = false
pset.cursorcolumn = false

-- === Performance and Resource Management ===
set.mouse         = ""                -- Disable mouse support
set.updatetime    = 100               -- Faster responsiveness
set.lazyredraw    = true              -- Only redraw when needed
set.ttyfast       = true              -- Optimization for fast terminal redraw
set.synmaxcol     = 200               -- Limit syntax highlighting width for performance
set.redrawtime    = 1000              -- Max time for full redraw
set.maxmempattern = 2000              -- Cap pattern search memory
set.shadafile     = "NONE"            -- Defer persistent state

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

-- === Syntax Performance Tweaks ===
aset.nvim_create_autocmd("FileType", {
  group = aset.nvim_create_augroup("SyntaxSyncOptimization", { clear = true }),
  pattern = { "c", "cpp", "java", "python", "lua", "javascript", "typescript" },
  callback = function()
    cset("syntax sync minlines=200")
    cset("syntax sync maxlines=500")
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
  if not bset.modified then return end

  local line_count = fset.line("$")
  if line_count >= 1000 then return end -- short-circuit large files

  local bufnr = aset.nvim_get_current_buf()
  local changed = false
  local lines = aset.nvim_buf_get_lines(bufnr, 0, line_count, false)

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
    aset.nvim_buf_set_lines(bufnr, 0, line_count, false, lines)
    fset.winrestview(view)
  end
end

-- === Whitespace Cleaner (Pre-Save Hook) ===
aset.nvim_create_autocmd("BufWritePre", {
  group = aset.nvim_create_augroup("TrimWhitespace", { clear = true }),
  pattern = { "*.lua", "*.c", "*.cpp", "*.py", "*.js", "*.java" },
  callback = trim_trailing_whitespace
})

-- === Adaptive Optimization for Large Files ===
aset.nvim_create_autocmd("FileType", {
  group = aset.nvim_create_augroup("LargeFileOpts", { clear = true }),
  pattern = { "json", "yaml", "markdown", "text", "plaintex" },
  callback = function()
    local line_count = fset.line("$")
    if line_count > 1000 then
      lset.foldmethod   = "manual"
      lset.synmaxcol    = 300
      lset.wrap         = true       -- Enable wrap for readability
      lset.linebreak    = true       -- Break at word boundaries
      lset.breakindent  = true       -- Preserve indentation
    else
      lset.foldmethod   = "indent"
      lset.synmaxcol    = 500
      lset.wrap         = false      -- Maintain coding default
      lset.linebreak    = false
      lset.breakindent  = false
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

-- === Cached State for Statusline ===

local cached_mode   = "NORMAL"
local cached_search = ""

-- === Fast Mode Map Table ===
local mode_map = {
  n  = "NORMAL",      no  = "N·OP",      nov = "N·OP",
  i  = "INSERT",      ic  = "INS·COMP",  ix  = "INS·X",
  v  = "VISUAL",      V   = "V·LINE",    [""] = "V·BLOCK",
  c  = "COMMAND",     cv  = "VIM·EX",    ce  = "EX",
  r  = "REPLACE",     R   = "REPLACE",   Rx  = "REPL·X",
  s  = "SELECT",      S   = "S·LINE",    [""] = "S·BLOCK",
  t  = "TERMINAL"
}

-- === Background Updater: Mode and Search Count ===

local function update_mode()
  local ok, result = pcall(aset.nvim_get_mode)
  if ok and result and result.mode then
    cached_mode = mode_map[result.mode] or "MODE(" .. result.mode .. ")"
  end
end

local function update_search()
  local ok, result = pcall(fset.searchcount, { maxcount = 0, timeout = 30 })
  if ok and result and result.total and result.total > 0 then
    local current = result.current or 0
    cached_search = string.format(" %d/%d", current, result.total)
  else
    cached_search = ""
  end
end

-- === Debounced Update Trigger ===

local function schedule_statusline_update()
  vim.defer_fn(function()
    update_mode()
    update_search()
  end, 0)
end

-- === Auto-trigger on UI-relevant Events ===

aset.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "InsertLeave", "CmdlineLeave" }, {
  group = aset.nvim_create_augroup("StatuslineUpdate", { clear = true }),
  callback = schedule_statusline_update
})

-- === Static Fast Statusline (No `v:lua`) ===

set.statusline = table.concat({
  " %{g:sl_cached_mode} ",
  "%t %y",
  "%h%m%r",
  "%=",
  "Ln %l/%L, Col %c",
  "%{g:sl_cached_search}",
  " %P",
})

-- === Global Vars as Vimscript Bridge ===

gset.sl_cached_mode   = cached_mode
gset.sl_cached_search = cached_search

-- === Background Timer to Sync Cached State into Vim Globals ===

-- Avoid per-event calls to `vim.g` setter, use this to sync periodically
fset.timer_start(100, function()
  gset.sl_cached_mode   = cached_mode
  gset.sl_cached_search = cached_search
end, { ["repeat"] = -1 })

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
  local s           = ''
  local current_tab = fset.tabpagenr()
  local total_tabs  = fset.tabpagenr('$')
  local zen         = _G.zen_mode.active

  for i = 1, total_tabs do
    local label = tostring(i)

    -- Safely fetch window & buffer list
    local ok_w, winnr  = pcall(fset.tabpagewinnr, i)
    local ok_b, buflst = pcall(fset.tabpagebuflist, i)
    if ok_w and ok_b and winnr and buflst then
      local bufnr = buflst[winnr] or 0
      if fset.bufexists(bufnr) == 1 then
        -- modified flag
        local mod = ''
        local ok_m, is_m = pcall(fset.getbufvar, bufnr, '&modified')
        if ok_m and is_m == 1 then mod = '+' end

        if not zen then
          local raw  = fset.bufname(bufnr) or ''
          local name = fset.fnamemodify(raw, ':t')
          if name == '' then name = '[No Name]' end
          label = label .. ':' .. name .. mod
        else
          -- Zen mode: number only (+ if modified)
          label = label .. mod
        end
      end
    end

    -- highlight, then fill
    local hl = (i == current_tab)
             and '%#TabLineSel#'
             or '%#TabLine#'
    s = s .. string.format('%s %s %%#TabLineFill#', hl, label)
  end

  return s
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

  -- Reuse this up to a safe static bound
  local MAX_WIN = 64
  local wins = aset.nvim_list_wins()

  -- Pre-check if either setting is needed
  local apply_number     = settings.number     ~= nil
  local apply_signcolumn = settings.signcolumn ~= nil
  if not apply_number and not apply_signcolumn then return end

  -- Fast-guard and early loop exit
  local win_count = #wins > MAX_WIN and MAX_WIN or #wins
  for i = 1, win_count do
    local win = wins[i]
    -- Set window-local opts directly via API to avoid win_call overhead
    if apply_number then
      pcall(aset.nvim_set_option_value, "number", settings.number, { win = win })
    end
    if apply_signcolumn then
      pcall(aset.nvim_set_option_value, "signcolumn", settings.signcolumn, { win = win })
    end
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
