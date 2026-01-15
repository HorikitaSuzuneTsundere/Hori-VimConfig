-- === Neovim 0.11.5 Optimized Configuration ===

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
local uv = vim.uv

-- === Static Timer Allocation (Prevents GC churn) ===
-- We allocate these once and reuse them by stopping/restarting
local Timers = {
  cursor = uv.new_timer(),
  redraw = uv.new_timer(),
  gc = uv.new_timer()
}

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
-- 0.11+ API, no need for defer_fn
pcall(vim.lsp.set_log_level, "OFF")

-- === Highlight Groups (batch set) ===
local highlights = {
  TabLine = { fg = '#808080', bg = '#1e1e1e' },
  TabLineSel = { fg = '#ffffff', bg = '#3a3a3a', bold = true },
  TabLineFill = { fg = 'NONE', bg = '#1e1e1e' }
}
for name, opts in pairs(highlights) do
  aset.nvim_set_hl(0, name, opts)
end

-- === Cache System (Optimized) ===
local Cache = {}
Cache.__index = Cache

function Cache:new(max_size, ttl)
  local instance = setmetatable({
    data = {},
    order = {},
    key_index = {},
    max_size = max_size or 100,
    ttl = ttl or 1000,
  }, self)
  return instance
end

function Cache:get(key)
  local entry = self.data[key]
  if not entry then return nil end

  -- Optimization: Use uv.now() directly (cheaper than schedule overhead)
  local now = uv.now()
  if self.ttl and (now - entry.time) > self.ttl then
    self:_remove_key(key)
    return nil
  end
  return entry.value
end

function Cache:_remove_key(key)
  self.data[key] = nil
  local idx = self.key_index[key]
  if idx then
    self.order[idx] = nil
    self.key_index[key] = nil
  end
end

function Cache:set(key, value)
  local now = uv.now()

  if self.data[key] then
    self.data[key] = { value = value, time = now }
    return
  end

  local count = 0
  for _ in pairs(self.data) do count = count + 1 end

  if count >= self.max_size then
    for i = 1, #self.order do
      local old_key = self.order[i]
      if old_key then
        self:_remove_key(old_key)
        break
      end
    end
  end

  if #self.order > self.max_size * 2 then
    self:_compact()
  end

  self.data[key] = { value = value, time = now }
  self.order[#self.order + 1] = key
  self.key_index[key] = #self.order
end

function Cache:_compact()
  local new_order = {}
  local new_index = {}
  for i = 1, #self.order do
    local key = self.order[i]
    if key and self.data[key] then
      new_order[#new_order + 1] = key
      new_index[key] = #new_order
    end
  end
  self.order = new_order
  self.key_index = new_index
end

function Cache:clear()
  self.data = {}
  self.order = {}
  self.key_index = {}
end

function Cache:gc()
  local now = uv.now()
  local expired = {}

  for key, entry in pairs(self.data) do
    if self.ttl and (now - entry.time) > self.ttl then
      expired[#expired + 1] = key
    end
  end

  for _, key in ipairs(expired) do
    self:_remove_key(key)
  end

  if #expired > 0 then
    self:_compact()
  end
end

-- === Global Caches ===
local search_cache = Cache:new(10, 500)
local syntax_cache = Cache:new(20, 2000)

-- === Redraw Scheduler (Timer Reuse) ===
local RedrawScheduler = {
  pending = {},
  delay = 16,
}

function RedrawScheduler:schedule(redraw_type)
  self.pending[redraw_type] = true

  if Timers.redraw:is_active() then return end

  Timers.redraw:start(self.delay, 0, function()
    schedule(function()
      Timers.redraw:stop()

      local needs_tabline = self.pending.tabline
      local needs_status = self.pending.status
      local needs_full = self.pending.full

      self.pending = {}

      if needs_full then
        cset("redraw")
      elseif needs_tabline and needs_status then
        cset("redrawtabline")
        cset("redrawstatus")
      elseif needs_tabline then
        cset("redrawtabline")
      elseif needs_status then
        cset("redrawstatus")
      end
    end)
  end)
end

_G.redraw_scheduler = RedrawScheduler

-- === Syntax Settings ===
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

-- === Arrow Key Disable ===
local arrows = {"<Up>", "<Down>", "<Left>", "<Right>"}
local nop_opts = { desc = "Arrow Disabled" }
for _, mode in ipairs({"n", "v"}) do
  for _, arrow in ipairs(arrows) do
    kset.set(mode, arrow, "<Nop>", nop_opts)
  end
end

-- === Whitespace/Tab Trimmer (Targeted Updates) ===
local trim_pattern = "^(.-)%s*$"
local tab_replacement = "  "

local function trim_trailing_whitespace()
  if not bset.modifiable or not bset.modified then return end
  local bufnr = aset.nvim_get_current_buf()
  local lines = aset.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Optimization: Only write back lines that actually changed
  for i, l in ipairs(lines) do
    local trimmed = l:match(trim_pattern)
    if trimmed ~= l then
      aset.nvim_buf_set_lines(bufnr, i - 1, i, false, { trimmed })
    end
  end
end

local function convert_tabs_to_spaces()
  if not bset.modifiable then return end
  local bufnr = aset.nvim_get_current_buf()
  local lines = aset.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Optimization: Only write back lines that actually changed
  for i, l in ipairs(lines) do
    if l:find("\t", 1, true) then
      local converted = l:gsub("\t", tab_replacement)
      aset.nvim_buf_set_lines(bufnr, i - 1, i, false, { converted })
    end
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

-- === Search Counter ===
_G.search_info = function()
  -- Optimization: If hlsearch is off, don't even check registers
  if vset.hlsearch == 0 then return "" end

  local key = fset.getreg("/")
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
    RedrawScheduler:schedule("status")
  end
})
autocmd("RecordingLeave", {
  group = macro_group,
  callback = function()
    macro_reg = ""
    RedrawScheduler:schedule("status")
  end
})

-- === Statusline ===
local statusline_template = "%t %y%h%m%r%=%{v:lua.macro_info()}Ln %l/%L, Col %c%{v:lua.search_info()} %P"
set.statusline = statusline_template

-- === Clear Highlight ===
local function clear_hlsearch()
  if vset.hlsearch == 1 then
    cset("nohlsearch")
    search_cache:clear()
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

-- === Zen Mode with State Machine ===
local zen_state_file = vim.fn.stdpath("data") .. "/zen_mode_state"
local zen_state_cache = nil

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

-- === Async File I/O for Zen State ===
local function save_zen_state_async()
  zen_state_cache = ZenMode.active

  uv.fs_open(zen_state_file, "w", 438, function(err, fd)
    if err or not fd then return end
    local data = ZenMode.active and "1" or "0"
    uv.fs_write(fd, data, 0, function(_)
      uv.fs_close(fd, function() end)
    end)
  end)
end

local function load_zen_state_sync()
  if zen_state_cache ~= nil then
    return zen_state_cache
  end

  local fd = uv.fs_open(zen_state_file, "r", 438)
  if not fd then
    zen_state_cache = false
    return false
  end

  local stat = uv.fs_fstat(fd)
  if not stat or stat.size == 0 then
    uv.fs_close(fd)
    zen_state_cache = false
    return false
  end

  local data = uv.fs_read(fd, 1, 0)
  uv.fs_close(fd)

  zen_state_cache = (data == "1")
  return zen_state_cache
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

-- === Tabline (Optimized String Building) ===
local tab_cache = Cache:new(5, 200)

function _G.tabline_numbers()
  local current = fset.tabpagenr()
  local total = fset.tabpagenr('$')
  local cache_key = current .. "_" .. total .. "_" .. (ZenMode.active and "z" or "n")

  local cached = tab_cache:get(cache_key)
  if cached then return cached end

  local parts = {}
  for i = 1, total do
    table.insert(parts, (i == current) and '%#TabLineSel#' or '%#TabLine#')
    table.insert(parts, ' ' .. tostring(i) .. ' ')

    if not ZenMode.active then
      local buflist = fset.tabpagebuflist(i)
      local winnr = fset.tabpagewinnr(i)
      local bufnr = buflist[winnr] or 0

      if fset.bufexists(bufnr) == 1 then
        local mod = (fset.getbufvar(bufnr, '&modified') == 1) and '+' or ''
        local name = fset.fnamemodify(fset.bufname(bufnr), ':t')
        name = (name ~= "") and name or '[No Name]'
        table.insert(parts, ':' .. name .. mod)
      end
    end
    table.insert(parts, ' ')
  end
  
  table.insert(parts, '%#TabLineFill#')
  local result = table.concat(parts)
  tab_cache:set(cache_key, result)
  return result
end

set.tabline = '%!v:lua.tabline_numbers()'

-- === Zen Mode Statusline ===
function _G.zen_statusline()
  return "~"
end

-- === Toggle Zen Mode ===
local function toggle_zen_mode()
  if ZenMode._busy then return end
  ZenMode._busy = true

  ZenMode.active = not ZenMode.active

  if ZenMode.active then
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
      statusline = set.statusline,
    }

    batch_apply_settings(ZenMode.config, true)
    aset.nvim_set_hl(0, "StatusLine", { bg = "NONE", fg = "#4F5258", bold = false })
    set.statusline = "%!v:lua.zen_statusline()"
  else
    batch_apply_settings(ZenMode.saved, true)
    if ZenMode.saved.status_hl then
      aset.nvim_set_hl(0, "StatusLine", ZenMode.saved.status_hl)
    end
    if ZenMode.saved.statusline then
      set.statusline = ZenMode.saved.statusline
    end
    ZenMode.saved = {}
  end

  save_zen_state_async()
  tab_cache:clear()

  schedule(function()
    ZenMode._busy = false
    RedrawScheduler:schedule("tabline")
  end)
end

kset.set("n", "<Space><Space>", toggle_zen_mode, {
  desc = "Toggle Zen Mode",
  noremap = true,
  silent = true,
})

-- === Auto-apply Zen Settings ===
local zen_group = augroup("ZenModeAuto", { clear = true })
local zen_apply_pending = false

autocmd({"WinNew", "WinEnter", "BufWinEnter"}, {
  group = zen_group,
  callback = function()
    if ZenMode.active and not zen_apply_pending then
      zen_apply_pending = true

      schedule(function()
        for _, opt in ipairs(ZenMode.window_opts) do
          if ZenMode.config[opt] ~= nil then
            wset[opt] = ZenMode.config[opt]
          end
        end
        zen_apply_pending = false
      end)
    end
  end
})

-- === Restore Zen Mode on Startup ===
autocmd("VimEnter", {
  callback = function()
    defer_fn(function()
      if load_zen_state_sync() and not ZenMode.active then
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
          statusline = set.statusline,
        }

        ZenMode.active = true
        batch_apply_settings(ZenMode.config, true)
        aset.nvim_set_hl(0, "StatusLine", { bg = "NONE", fg = "#4F5258", bold = false })
        set.statusline = "%!v:lua.zen_statusline()"

        schedule(function()
          RedrawScheduler:schedule("tabline")
        end)
      end
    end, 150)
  end,
})

autocmd("VimLeavePre", {
  callback = save_zen_state_async
})

-- === Memory Management ===
autocmd("FocusLost", {
  callback = function()
    search_cache:gc()
    syntax_cache:gc()
    tab_cache:gc()
    collectgarbage("collect")
  end
})

-- === Periodic Cache GC (Timer Reuse) ===
-- Use static timer, no reallocation
Timers.gc:start(300000, 300000, function()
  schedule(function()
    search_cache:gc()
    syntax_cache:gc()
    tab_cache:gc()
  end)
end)

autocmd("VimLeavePre", {
  callback = function()
    -- Clean up persistent timers
    if Timers.gc:is_active() then Timers.gc:stop() end
    Timers.gc:close()
  end
})

-- === CursorMoved (Optimized with Static Timer) ===
autocmd("CursorMoved", {
  callback = function()
    Timers.cursor:stop()
    Timers.cursor:start(100, 0, function()
      schedule(function()
        if vset.hlsearch == 1 then
          RedrawScheduler:schedule("status")
        end
      end)
    end)
  end
})

_G.zen_mode = ZenMode
