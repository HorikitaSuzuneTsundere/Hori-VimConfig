-- === Startup Optimization ===
-- Enable the new loader if available and not already enabled.
if vim.loader and not vim.loader.enabled then
  vim.loader.enable()
end

-- === Localized References (reduce table lookups) ===
local set   = vim.o
local pset  = vim.opt
local wset  = vim.wo
local cset  = vim.cmd
local fset  = vim.fn
local aset  = vim.api
local kset  = vim.keymap
local lset  = vim.opt_local
local vset  = vim.v
local bset  = vim.bo
local gset  = vim.g
local tbl_contains = vim.tbl_contains
local defer_fn = vim.defer_fn
local schedule = vim.schedule

-- === Batch Plugin & Provider Disabling ===
local disabled_plugins = {
  'matchparen', 'gzip', 'tar', 'tarPlugin', 'zip', 'zipPlugin',
  'getscript', 'getscriptPlugin', 'vimball', 'vimballPlugin',
  'rrhelper', '2html_plugin', 'logiPat'
}
for _, plugin in ipairs(disabled_plugins) do
  gset['loaded_' .. plugin] = 1
end

local disabled_providers = { 'python', 'python3', 'node', 'perl', 'ruby' }
for _, provider in ipairs(disabled_providers) do
  gset['loaded_' .. provider .. '_provider'] = 0
end

-- === Batch Option Setting ===
local options = {
  -- Performance
  mouse = "",
  updatetime = 100,
  lazyredraw = true,
  synmaxcol = 200,
  redrawtime = 200,
  maxmempattern = 2000,
  cursorline = false,
  cursorcolumn = false,
  
  -- UI
  number = true,
  scrolloff = 10,
  sidescrolloff = 8,
  showmode = false,
  modeline = false,
  undofile = true,
  swapfile = false,
  backup = false,
  writebackup = false,
  backupskip = "/tmp/*,/private/tmp/*",
  
  -- Timing
  timeoutlen = 300,
  ttimeoutlen = 40,
  keymodel = "",
  
  -- Encoding
  encoding = "utf-8",
  fileencodings = "utf-8",
  
  -- Indentation
  expandtab = true,
  shiftwidth = 2,
  tabstop = 2,
  softtabstop = 2,
  smartindent = true,
  autoindent = true,
  
  -- Search
  ignorecase = true,
  smartcase = true,
  hlsearch = true,
  incsearch = true,
  
  -- Interface
  cmdheight = 0,
  completeopt = "menuone,noinsert,noselect",
  splitright = true,
  splitbelow = true,
  
  -- Memory
  history = 2000,
  undolevels = 200,
}

for k, v in pairs(options) do
  set[k] = v
end

local window_options = {
  relativenumber = false,
  wrap = false,
  linebreak = false,
  breakindent = false,
  signcolumn = "yes:1",
}

for k, v in pairs(window_options) do
  wset[k] = v
end

pset.termguicolors = true

-- === Disable LSP Logging ===
defer_fn(function()
  local is_windows = vim.loop.os_uname().sysname == "Windows_NT"
  vim.env.NVIM_LSP_LOG_FILE = is_windows and "NUL" or "/dev/null"
  pcall(vim.lsp.log.set_level, "OFF")
end, 100)

-- === Highlight Groups (batch set) ===
local highlights = {
  TabLine = { fg = '#808080', bg = '#1e1e1e' },
  TabLineSel = { fg = '#ffffff', bg = '#3a3a3a', bold = true },
  TabLineFill = { fg = 'NONE', bg = '#1e1e1e' }
}
for name, opts in pairs(highlights) do
  aset.nvim_set_hl(0, name, opts)
end

-- === Cache System ===
local Cache = {}
Cache.__index = Cache

function Cache:new(max_size, ttl)
  return setmetatable({
    data = {},
    order = {},
    max_size = max_size or 100,
    ttl = ttl or 1000,
  }, self)
end

function Cache:get(key)
  local entry = self.data[key]
  if not entry then return nil end
  if self.ttl and (vim.loop.now() - entry.time) > self.ttl then
    self.data[key] = nil
    return nil
  end
  return entry.value
end

function Cache:set(key, value)
  if #self.order >= self.max_size then
    local oldest = table.remove(self.order, 1)
    self.data[oldest] = nil
  end
  self.data[key] = { value = value, time = vim.loop.now() }
  table.insert(self.order, key)
end

-- === Global Caches ===
local search_cache = Cache:new(10, 500)
local syntax_cache = Cache:new(20, 2000)

-- === Optimized Syntax Settings ===
local syntax_settings = {
  fast = { "c", "cpp", "java", "python", "lua", "javascript", "typescript" },
  heavy = { "json", "yaml", "markdown", "text", "plaintex" }
}

local augroup = aset.nvim_create_augroup
local autocmd = aset.nvim_create_autocmd

autocmd("FileType", {
  group = augroup("PerfFileTypeHandler", { clear = true }),
  pattern = "*",
  callback = function(args)
    local ft = args.match
    local cache_key = ft .. "_" .. args.buf
    
    if syntax_cache:get(cache_key) then return end
    
    local line_count = fset.line("$")
    
    if tbl_contains(syntax_settings.fast, ft) then
      cset("syntax sync minlines=200 maxlines=500")
    elseif tbl_contains(syntax_settings.heavy, ft) and line_count > 1000 then
      lset.foldmethod = "manual"
      lset.synmaxcol = 300
      lset.wrap = true
      lset.linebreak = true
      lset.breakindent = true
    end
    
    syntax_cache:set(cache_key, true)
  end
})

-- === Arrow Key Disable (optimized) ===
local arrows = {"<Up>", "<Down>", "<Left>", "<Right>"}
local nop_opts = { desc = "Arrow Disabled" }
for _, mode in ipairs({"n", "v"}) do
  for _, arrow in ipairs(arrows) do
    kset.set(mode, arrow, "<Nop>", nop_opts)
  end
end

-- === Optimized Whitespace Trimmer ===
local trim_pattern = "^(.-)%s*$"
local function trim_trailing_whitespace()
  if not bset.modifiable or not bset.modified then return end
  local line_count = fset.line("$")
  if line_count > 2000 then return end
  
  local bufnr = aset.nvim_get_current_buf()
  local lines = aset.nvim_buf_get_lines(bufnr, 0, -1, false)
  local changes = {}
  
  for i, line in ipairs(lines) do
    local trimmed = line:match(trim_pattern)
    if trimmed ~= line then
      changes[#changes + 1] = {i - 1, trimmed}
    end
  end
  
  if #changes > 0 then
    local view = fset.winsaveview()
    for _, change in ipairs(changes) do
      aset.nvim_buf_set_lines(bufnr, change[1], change[1] + 1, false, {change[2]})
    end
    fset.winrestview(view)
  end
end

-- === Tab Converter (optimized with pattern cache) ===
local tab_pattern = "\t"
local tab_replacement = "  "
local function convert_tabs_to_spaces()
  if not bset.modifiable then return end
  local has_tabs = fset.search(tab_pattern) ~= 0
  if has_tabs then
    cset(string.format("%%s/%s/%s/ge", tab_pattern, tab_replacement))
  end
end

-- === Consolidated AutoCmd Group ===
local save_group = augroup("SaveHooks", { clear = true })
autocmd("BufWritePre", {
  group = save_group,
  pattern = { "*.lua", "*.c", "*.cpp", "*.py", "*.js", "*.java" },
  callback = function()
    trim_trailing_whitespace()
    convert_tabs_to_spaces()
  end
})

-- === Deferred Initialization ===
autocmd("VimEnter", {
  callback = function()
    defer_fn(function()
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

-- === Optimized Search Counter ===
_G.search_info = function()
  local key = vset.hlsearch .. "_" .. fset.getreg("/")
  local cached = search_cache:get(key)
  if cached then return cached end
  
  local ok, s = pcall(fset.searchcount, { maxcount = 0, timeout = 100 })
  local result = ""
  if ok and s and s.total and s.total > 0 then
    result = string.format(" %d/%d", s.current or 0, s.total)
  end
  search_cache:set(key, result)
  return result
end

-- === Macro Recording Indicator ===
local macro_reg = ""
_G.macro_info = function()
  return macro_reg ~= "" and (" REC @" .. macro_reg .. " ") or ""
end

local macro_group = augroup("MacroStatusline", { clear = true })
autocmd("RecordingEnter", {
  group = macro_group,
  callback = function() 
    macro_reg = fset.reg_recording()
    cset("redrawstatus") 
  end
})
autocmd("RecordingLeave", {
  group = macro_group,
  callback = function() 
    macro_reg = ""
    cset("redrawstatus") 
  end
})

-- === Optimized Statusline (pre-concatenated) ===
local statusline_template = "%t %y%h%m%r%=%{v:lua.macro_info()}Ln %l/%L, Col %c%{v:lua.search_info()} %P"
set.statusline = statusline_template

-- === Optimized Clear Highlight ===
local function clear_hlsearch()
  if vset.hlsearch == 1 then 
    cset("nohlsearch")
    search_cache = Cache:new(10, 500) -- Clear cache
  end
end

kset.set("i", "<Esc>", function()
  schedule(clear_hlsearch)
  return "<Esc>"
end, { expr = true, silent = true, noremap = true })

kset.set("n", "<Esc>", function()
  clear_hlsearch()
  return "<Esc>"
end, { expr = true, silent = true, noremap = true })

-- === Optimized Zen Mode with State Machine ===
local zen_state_file = vim.fn.stdpath("data") .. "/zen_mode_state"

local ZenMode = {
  active = false,
  saved = {},
  _busy = false,
  config = {
    syntax = false,
    number = false,
    showcmd = false,
    laststatus = 0,
    cmdheight = 0,
    signcolumn = "no",
    cursorline = false,
    cursorcolumn = false,
    list = false,
    showmode = false,
    ruler = false,
    spell = false,
  },
  window_opts = { "number", "signcolumn", "cursorline", "cursorcolumn", "list", "spell" },
  global_opts = { "showcmd", "laststatus", "cmdheight", "showmode", "ruler" }
}

-- === Optimized File I/O ===
local function save_zen_state()
  local f = io.open(zen_state_file, "w")
  if f then
    f:write(ZenMode.active and "1" or "0")
    f:close()
  end
end

local function load_zen_state()
  local f = io.open(zen_state_file, "r")
  if not f then return false end
  local content = f:read(1)
  f:close()
  return content == "1"
end

-- === Batch Window Operations ===
local function batch_apply_settings(settings, is_global)
  if is_global then
    for k, v in pairs(settings) do
      if k == "syntax" then
        cset(v and "syntax on" or "syntax off")
      elseif ZenMode.global_opts[k] then
        set[k] = v
      end
    end
  end
  
  local wins = aset.nvim_list_wins()
  for _, win in ipairs(wins) do
    aset.nvim_win_call(win, function()
      for _, opt in ipairs(ZenMode.window_opts) do
        if settings[opt] ~= nil then
          wset[opt] = settings[opt]
        end
      end
    end)
  end
end

-- === Optimized Tabline ===
local tab_cache = Cache:new(5, 200)
function _G.tabline_numbers()
  local current = fset.tabpagenr()
  local total = fset.tabpagenr('$')
  local cache_key = current .. "_" .. total .. "_" .. (ZenMode.active and "z" or "n")
  
  local cached = tab_cache:get(cache_key)
  if cached then return cached end
  
  local parts = {}
  for i = 1, total do
    local hl = (i == current) and '%#TabLineSel#' or '%#TabLine#'
    local label = tostring(i)
    
    if not ZenMode.active then
      local buflist = fset.tabpagebuflist(i)
      local winnr = fset.tabpagewinnr(i)
      local bufnr = buflist[winnr] or 0
      
      if fset.bufexists(bufnr) == 1 then
        local mod = (fset.getbufvar(bufnr, '&modified') == 1) and '+' or ''
        local name = fset.fnamemodify(fset.bufname(bufnr), ':t')
        name = (name ~= "") and name or '[No Name]'
        label = label .. ':' .. name .. mod
      end
    end
    
    parts[#parts+1] = hl .. ' ' .. label .. ' '
  end
  
  local result = table.concat(parts) .. '%#TabLineFill#'
  tab_cache:set(cache_key, result)
  return result
end

set.tabline = '%!v:lua.tabline_numbers()'

-- === Toggle Zen Mode ===
local function toggle_zen_mode()
  if ZenMode._busy then return end
  ZenMode._busy = true
  schedule(function() ZenMode._busy = false end)
  
  ZenMode.active = not ZenMode.active
  
  if ZenMode.active then
    -- Save current state
    ZenMode.saved = {
      syntax = set.syntax ~= "off",
      number = wset.number,
      showcmd = set.showcmd,
      laststatus = set.laststatus,
      cmdheight = set.cmdheight,
      signcolumn = wset.signcolumn,
      cursorline = wset.cursorline,
      cursorcolumn = wset.cursorcolumn,
      list = wset.list,
      showmode = set.showmode,
      ruler = set.ruler,
      spell = wset.spell,
      status_hl = aset.nvim_get_hl(0, { name = "StatusLine", link = false }),
    }
    
    batch_apply_settings(ZenMode.config, true)
    aset.nvim_set_hl(0, "StatusLine", { bg = "NONE", fg = "#ffffff", bold = false })
  else
    batch_apply_settings(ZenMode.saved, true)
    if ZenMode.saved.status_hl then
      aset.nvim_set_hl(0, "StatusLine", ZenMode.saved.status_hl)
    end
  end
  
  save_zen_state()
  tab_cache = Cache:new(5, 200) -- Clear tab cache
  cset('redrawtabline')
end

kset.set("n", "<Space><Space>", toggle_zen_mode, {
  desc = "Toggle Zen Mode",
  noremap = true,
  silent = true,
})

-- === Auto-apply Zen Settings ===
local zen_group = augroup("ZenModeAuto", { clear = true })
autocmd({"WinNew", "WinEnter", "BufWinEnter"}, {
  group = zen_group,
  callback = function()
    if ZenMode.active then
      for _, opt in ipairs(ZenMode.window_opts) do
        if ZenMode.config[opt] ~= nil then
          wset[opt] = ZenMode.config[opt]
        end
      end
    end
  end
})

-- === Restore Zen Mode on Startup ===
autocmd("VimEnter", {
  callback = function()
    defer_fn(function()
      if load_zen_state() and not ZenMode.active then
        -- Save current state BEFORE enabling
        ZenMode.saved = {
          syntax = set.syntax ~= "off",
          number = wset.number,
          showcmd = set.showcmd,
          laststatus = set.laststatus,
          cmdheight = set.cmdheight,
          signcolumn = wset.signcolumn,
          cursorline = wset.cursorline,
          cursorcolumn = wset.cursorcolumn,
          list = wset.list,
          showmode = set.showmode,
          ruler = set.ruler,
          spell = wset.spell,
          status_hl = aset.nvim_get_hl(0, { name = "StatusLine", link = false }),
        }
        
        ZenMode.active = true
        batch_apply_settings(ZenMode.config, true)
        aset.nvim_set_hl(0, "StatusLine", { bg = "NONE", fg = "#ffffff", bold = false })
        cset('redrawtabline')
      end
    end, 150)
  end,
})

autocmd("VimLeavePre", {
  callback = save_zen_state
})

-- === Memory Management ===
autocmd("FocusLost", {
  callback = function()
    -- Clear caches when vim loses focus
    search_cache = Cache:new(10, 500)
    syntax_cache = Cache:new(20, 2000)
    tab_cache = Cache:new(5, 200)
    collectgarbage("collect")
  end
})

_G.zen_mode = ZenMode
