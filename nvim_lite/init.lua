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

-- Use vim.uv (modern API, available in Neovim 0.10+) with fallback
local uv = vim.uv or vim.loop

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
  local is_windows = uv.os_uname().sysname == "Windows_NT"
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
  local instance = setmetatable({
    data = {},
    order = {},
    key_index = {},  -- Track position of keys in order array
    max_size = max_size or 100,
    ttl = ttl or 1000,
    _now_cache = 0,  -- Cached timestamp to reduce uv.now() calls
    _now_valid = false,
  }, self)
  return instance
end

-- Get current time with caching (valid for ~1ms batches)
function Cache:_now()
  if not self._now_valid then
    self._now_cache = uv.now()
    -- Invalidate on next event loop iteration
    schedule(function() self._now_valid = false end)
    self._now_valid = true
  end
  return self._now_cache
end

function Cache:get(key)
  local entry = self.data[key]
  if not entry then return nil end

  local now = self:_now()
  if self.ttl and (now - entry.time) > self.ttl then
    self:_remove_key(key)
    return nil
  end
  return entry.value
end

-- Internal: remove a key from both data and order tracking
function Cache:_remove_key(key)
  self.data[key] = nil
  local idx = self.key_index[key]
  if idx then
    -- Mark as nil instead of table.remove
    self.order[idx] = nil
    self.key_index[key] = nil
  end
end

function Cache:set(key, value)
  local now = self:_now()

  -- If key exists, update in place (no order change needed)
  if self.data[key] then
    self.data[key] = { value = value, time = now }
    return
  end

  -- Evict oldest if at capacity (find first non-nil entry)
  local count = 0
  for _ in pairs(self.data) do count = count + 1 end

  if count >= self.max_size then
    -- Find oldest non-nil entry in order
    for i = 1, #self.order do
      local old_key = self.order[i]
      if old_key then
        self:_remove_key(old_key)
        break
      end
    end
  end

  -- Compact order array periodically (every max_size insertions)
  if #self.order > self.max_size * 2 then
    self:_compact()
  end

  -- Add new entry
  self.data[key] = { value = value, time = now }
  self.order[#self.order + 1] = key
  self.key_index[key] = #self.order
end

-- Compact the order array by removing nil entries
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

-- Clear cache without creating new object (prevents orphaned tables)
function Cache:clear()
  self.data = {}
  self.order = {}
  self.key_index = {}
  self._now_valid = false
end

-- Garbage collect expired entries
function Cache:gc()
  local now = self:_now()
  local expired = {}

  for key, entry in pairs(self.data) do
    if self.ttl and (now - entry.time) > self.ttl then
      expired[#expired + 1] = key
    end
  end

  for _, key in ipairs(expired) do
    self:_remove_key(key)
  end

  -- Compact if we removed entries
  if #expired > 0 then
    self:_compact()
  end
end

-- === Global Caches ===
local search_cache = Cache:new(10, 500)
local syntax_cache = Cache:new(20, 2000)

-- === Redraw Scheduler (with proper timer management) ===
local RedrawScheduler = {
  pending = {},
  timer = nil,
  delay = 16, -- ~60fps
}

function RedrawScheduler:_stop_timer()
  if self.timer then
    -- For vim.defer_fn, we can't stop it, but we can use uv.new_timer instead
    self.timer = nil
  end
end

function RedrawScheduler:schedule(redraw_type)
  self.pending[redraw_type] = true

  if self.timer then return end

  -- Use uv timer for proper lifecycle control
  local timer = uv.new_timer()
  self.timer = timer

  timer:start(self.delay, 0, function()
    schedule(function()
      -- Stop and close timer to prevent leaks
      if timer:is_active() then timer:stop() end
      if not timer:is_closing() then timer:close() end

      local needs_tabline = self.pending.tabline
      local needs_status = self.pending.status
      local needs_full = self.pending.full

      self.pending = {}
      self.timer = nil

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

-- === Whitespace Trimmer ===
local trim_pattern = "^(.-)%s*$"
local function trim_trailing_whitespace()
  if not bset.modifiable or not bset.modified then return end
  local bufnr = aset.nvim_get_current_buf()
  local lines = aset.nvim_buf_get_lines(bufnr, 0, -1, false)
  local changed = false

  -- Modify in place instead of creating new table
  for i = 1, #lines do
    local l = lines[i]
    local trimmed = l:match(trim_pattern)
    if trimmed ~= l then
      lines[i] = trimmed
      changed = true
    end
  end

  if not changed then return end

  local cur = aset.nvim_win_get_cursor(0)
  aset.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local row = math.max(1, math.min(cur[1], #lines))
  local col = cur[2]
  local line_len = #lines[row]
  if col > line_len then col = line_len end

  pcall(aset.nvim_win_set_cursor, 0, { row, col })
end

-- === Tab Converter ===
local tab_replacement = "  " -- 2 spaces
local function convert_tabs_to_spaces()
  if not bset.modifiable then return end
  local bufnr = aset.nvim_get_current_buf()
  local lines = aset.nvim_buf_get_lines(bufnr, 0, -1, false)
  local changed = false

  for i = 1, #lines do
    local l = lines[i]
    if l:find("\t", 1, true) then
      lines[i] = l:gsub("\t", tab_replacement)
      changed = true
    end
  end

  if changed then
    local cur = aset.nvim_win_get_cursor(0)
    aset.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    local row = math.max(1, math.min(cur[1], #lines))
    local col = cur[2]
    local line_len = #lines[row]
    if col > line_len then col = line_len end
    pcall(aset.nvim_win_set_cursor, 0, { row, col })
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

-- === Macro Recording Indicator with Batched Redraws ===
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

-- === Statusline (pre-concatenated) ===
local statusline_template = "%t %y%h%m%r%=%{v:lua.macro_info()}Ln %l/%L, Col %c%{v:lua.search_info()} %P"
set.statusline = statusline_template

-- === Clear Highlight ===
local function clear_hlsearch()
  if vset.hlsearch == 1 then
    cset("nohlsearch")
    search_cache:clear()  -- Clear instead of recreate
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

-- Async file I/O for zen state (non-blocking)
local zen_state_cache = nil  -- In-memory cache to avoid repeated reads

local ZenMode = {
  active = false,
  saved = {},
  _busy = false,
  _redraw_pending = false,
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
  zen_state_cache = ZenMode.active  -- Update cache immediately

  -- Non-blocking write using libuv
  uv.fs_open(zen_state_file, "w", 438, function(err, fd)
    if err or not fd then return end
    local data = ZenMode.active and "1" or "0"
    uv.fs_write(fd, data, 0, function(write_err)
      uv.fs_close(fd, function() end)
    end)
  end)
end

local function load_zen_state_sync()
  -- Use cached value if available
  if zen_state_cache ~= nil then
    return zen_state_cache
  end

  -- Sync read only on startup (blocking is acceptable during init)
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

-- === Tabline ===
local tab_cache = Cache:new(5, 200)

function _G.tabline_numbers()
  local current = fset.tabpagenr()
  local total = fset.tabpagenr('$')
  local cache_key = current .. "_" .. total .. "_" .. (ZenMode.active and "z" or "n")

  local cached = tab_cache:get(cache_key)
  if cached then return cached end

  -- Pre-allocate parts array with known size
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

    parts[i] = hl .. ' ' .. label .. ' '
  end

  local result = table.concat(parts) .. '%#TabLineFill#'
  tab_cache:set(cache_key, result)
  return result
end

set.tabline = '%!v:lua.tabline_numbers()'

-- === Zen Mode Statusline (thin outline) ===
function _G.zen_statusline()
  return "~"
end

-- === Toggle Zen Mode with Batched Redraw ===
local function toggle_zen_mode()
  if ZenMode._busy then return end
  ZenMode._busy = true

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
    -- Clear saved state to free memory
    ZenMode.saved = {}
  end

  save_zen_state_async()  -- Non-blocking save
  tab_cache:clear()  -- Clear instead of recreate

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

-- === Auto-apply Zen Settings with Redraw Guard ===
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

-- === Memory Management with Proper Cache Clearing ===
autocmd("FocusLost", {
  callback = function()
    -- Run GC on caches to remove expired entries
    search_cache:gc()
    syntax_cache:gc()
    tab_cache:gc()

    -- Then do Lua garbage collection
    collectgarbage("collect")
  end
})

-- === Periodic Cache GC (every 5 minutes) ===
local gc_timer = uv.new_timer()
if gc_timer then
  gc_timer:start(300000, 300000, function()
    schedule(function()
      search_cache:gc()
      syntax_cache:gc()
      tab_cache:gc()
    end)
  end)
end

-- Cleanup on exit
autocmd("VimLeavePre", {
  callback = function()
    if gc_timer and not gc_timer:is_closing() then
      gc_timer:stop()
      gc_timer:close()
    end
  end
})

-- === CursorMoved with Proper Timer Management ===
local cursor_timer = nil

autocmd("CursorMoved", {
  callback = function()
    if cursor_timer then return end

    cursor_timer = uv.new_timer()
    if not cursor_timer then return end

    cursor_timer:start(100, 0, function()
      schedule(function()
        -- Properly close timer to prevent leaks
        if cursor_timer then
          if cursor_timer:is_active() then cursor_timer:stop() end
          if not cursor_timer:is_closing() then cursor_timer:close() end
          cursor_timer = nil
        end

        if vset.hlsearch == 1 then
          RedrawScheduler:schedule("status")
        end
      end)
    end)
  end
})

_G.zen_mode = ZenMode
