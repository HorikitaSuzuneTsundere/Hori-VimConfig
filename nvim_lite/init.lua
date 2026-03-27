-- === Neovim 0.11+ Configuration ===

-- === Localized References ===
-- FIX: Replaced vim.o/vim.wo with vim.opt for correct list/set/map type handling.
--      Kept vim.bo (buffer-local) and vim.wo (per-window inside callbacks) where appropriate.
local opt      = vim.opt
local cmd      = vim.cmd
local fn       = vim.fn
local api      = vim.api
local kset     = vim.keymap
local lset     = vim.opt_local
local vset     = vim.v
local bo       = vim.bo
local g        = vim.g
local defer_fn = vim.defer_fn
local schedule = vim.schedule
local uv       = vim.uv

-- === Static Timer Allocation (prevents GC churn) ===
local Timers = {
  cursor = uv.new_timer(),
  redraw = uv.new_timer(),
  gc     = uv.new_timer(),
}

-- === Batch Plugin & Provider Disabling ===
-- FIX: Added netrw family, matchit, and tutor — common startup-time culprits.
local disabled_plugins = {
  'matchparen', 'matchit',
  'gzip', 'tar', 'tarPlugin', 'zip', 'zipPlugin',
  'getscript', 'getscriptPlugin', 'vimball', 'vimballPlugin',
  'rrhelper', '2html_plugin', 'logiPat',
  'netrw', 'netrwPlugin', 'netrwSettings', 'netrwFileHandlers',
  'tutor',
}
for _, plugin in ipairs(disabled_plugins) do
  g['loaded_' .. plugin] = 1
end

local disabled_providers = { 'python', 'python3', 'node', 'perl', 'ruby' }
for _, provider in ipairs(disabled_providers) do
  g['loaded_' .. provider .. '_provider'] = 0
end

-- === Options ===
-- Performance
opt.mouse         = ""
opt.updatetime    = 250         -- FIX: was 100ms; 250ms avoids excessive CursorHold/swap I/O
opt.synmaxcol     = 200
opt.redrawtime    = 1000        -- FIX: was 200ms — dangerously low; syntax gets terminated
                                --      mid-file leaving uncolored text. 1000ms is a safe floor.
opt.maxmempattern = 2000
opt.cursorline    = false
opt.cursorcolumn  = false

-- UI
opt.number        = true
opt.scrolloff     = 10
opt.sidescrolloff = 8
opt.showmode      = false
opt.modeline      = false
opt.undofile      = true
opt.swapfile      = false
opt.backup        = false
opt.writebackup   = false
-- FIX: vim.opt treats backupskip as a list; appending is cleaner and cross-platform.
opt.backupskip:append({ "/tmp/*", "/private/tmp/*" })

-- Timing
opt.timeoutlen    = 300
opt.ttimeoutlen   = 40
opt.keymodel      = ""

-- Encoding
-- FIX: Removed `encoding = "utf-8"` — it is read-only in Neovim (always UTF-8).
--      Setting it was silently a no-op.
opt.fileencodings = "utf-8"

-- Indentation
opt.expandtab   = true
opt.shiftwidth  = 2
opt.tabstop     = 2
opt.softtabstop = 2
opt.smartindent = true
opt.autoindent  = true

-- Search
opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

-- Interface
opt.cmdheight   = 0
opt.completeopt = { "menuone", "noinsert", "noselect" }  -- FIX: list type via vim.opt
opt.splitright  = true
opt.splitbelow  = true

-- Memory
opt.history    = 2000
opt.undolevels = 200

-- Colors
opt.termguicolors = true

-- === Window-local Defaults ===
-- FIX: Extracted into a function so it can be reapplied to new windows via WinNew.
--      Previously these were set once on vim.wo and silently lost for any new window.
local win_defaults = {
  relativenumber = false,
  wrap           = false,
  linebreak      = false,
  breakindent    = false,
  signcolumn     = "yes:1",
}
local function apply_win_defaults(win)
  local wo = vim.wo[win] or vim.wo
  for k, v in pairs(win_defaults) do wo[k] = v end
end
apply_win_defaults(0)  -- seed the initial window

-- === Disable LSP Logging ===
pcall(vim.lsp.set_log_level, "OFF")

-- === Highlight Groups ===
-- FIX: Highlights were set at module load only. Any :colorscheme call would wipe them.
--      Now wrapped in a function and re-applied on ColorScheme.
local function apply_highlights()
  local hl_defs = {
    TabLine     = { fg = '#808080', bg = '#1e1e1e' },
    TabLineSel  = { fg = '#ffffff', bg = '#3a3a3a', bold = true },
    TabLineFill = { fg = 'NONE',    bg = '#1e1e1e' },
  }
  for name, opts in pairs(hl_defs) do
    api.nvim_set_hl(0, name, opts)
  end
end
apply_highlights()

local augroup = api.nvim_create_augroup
local autocmd = api.nvim_create_autocmd

autocmd("ColorScheme", {
  group    = augroup("HighlightOverrides", { clear = true }),
  pattern  = "*",
  callback = apply_highlights,
})

-- === Cache System ===
-- Uses an O(1) _size counter instead of an O(n) pairs-count on every set().
-- Holes from _remove_key are avoided: the order list is only compacted
-- in bulk via _compact(), never by nil-ing individual slots.
local Cache = {}
Cache.__index = Cache

function Cache:new(max_size, ttl)
  return setmetatable({
    data      = {},
    order     = {},
    key_index = {},
    _size     = 0,
    max_size  = max_size or 100,
    ttl       = ttl or 1000,
  }, self)
end

function Cache:get(key)
  local entry = self.data[key]
  if not entry then return nil end
  if (uv.now() - entry.time) > self.ttl then
    self:_remove_key(key)
    return nil
  end
  return entry.value
end

-- Internal: removes from data + key_index but leaves a nil slot in order.
-- The order array is compacted in bulk by _compact() to avoid O(n) per removal.
function Cache:_remove_key(key)
  if not self.data[key] then return end
  self.data[key] = nil
  self._size = self._size - 1
  local idx = self.key_index[key]
  if idx then
    self.order[idx] = nil   -- sparse hole; _compact() cleans these up
    self.key_index[key] = nil
  end
end

function Cache:set(key, value)
  local now = uv.now()

  if self.data[key] then
    -- Update in place; position in order is unchanged.
    self.data[key] = { value = value, time = now }
    return
  end

  -- Evict oldest live entry when at capacity (O(n) scan only on overflow).
  if self._size >= self.max_size then
    for i = 1, #self.order do
      local old_key = self.order[i]
      if old_key then
        self:_remove_key(old_key)
        break
      end
    end
  end

  -- Compact the order array if it has grown too sparse.
  if #self.order > self.max_size * 2 then
    self:_compact()
  end

  self.data[key]      = { value = value, time = now }
  self._size          = self._size + 1
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
  self.order     = new_order
  self.key_index = new_index
end

function Cache:clear()
  self.data      = {}
  self.order     = {}
  self.key_index = {}
  self._size     = 0
end

function Cache:gc()
  local now     = uv.now()
  local expired = {}
  for key, entry in pairs(self.data) do
    if (now - entry.time) > self.ttl then
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

-- === Redraw Scheduler (timer reuse) ===
local RedrawScheduler = {
  pending = {},
  delay   = 16,
}

function RedrawScheduler:schedule(redraw_type)
  self.pending[redraw_type] = true
  if Timers.redraw:is_active() then return end

  Timers.redraw:start(self.delay, 0, function()
    schedule(function()
      -- Snapshot and clear pending before issuing redraws.
      local needs_tabline = self.pending.tabline
      local needs_status  = self.pending.status
      local needs_full    = self.pending.full
      -- Clear in-place: avoids allocating a new table every 16ms dispatch cycle.
      self.pending.tabline = nil
      self.pending.status  = nil
      self.pending.full    = nil

      if needs_full then
        cmd("redraw")
      elseif needs_tabline and needs_status then
        cmd("redrawtabline")
        cmd("redrawstatus")
      elseif needs_tabline then
        cmd("redrawtabline")
      elseif needs_status then
        cmd("redrawstatus")
      end
    end)
  end)
end

-- === Syntax Settings ===
-- Hash sets give O(1) lookup vs O(n) tbl_contains on every FileType event.
local syntax_fast  = { c=true, cpp=true, java=true, python=true, lua=true, javascript=true, typescript=true }
local syntax_heavy = { json=true, yaml=true, markdown=true, text=true, plaintex=true }

autocmd("FileType", {
  group    = augroup("PerfFileTypeHandler", { clear = true }),
  pattern  = "*",
  callback = function(args)
    local ft        = args.match
    local cache_key = ft .. "_" .. args.buf
    if syntax_cache:get(cache_key) then return end

    if syntax_fast[ft] then
      cmd("syntax sync minlines=200 maxlines=500")
    elseif syntax_heavy[ft] and fn.line("$") > 1000 then
      lset.foldmethod = "manual"
      lset.synmaxcol  = 300
      lset.wrap       = true
      lset.linebreak  = true
      lset.breakindent = true
    end

    syntax_cache:set(cache_key, true)
  end,
})

-- === Apply Window Defaults to Every New Window ===
-- FIX: New windows created after startup were not getting win_defaults.
autocmd({ "WinNew" }, {
  group    = augroup("WinDefaultsApply", { clear = true }),
  callback = function(args)
    -- args.match is empty for WinNew; apply to the current window.
    schedule(function()
      apply_win_defaults(api.nvim_get_current_win())
    end)
  end,
})

-- === Arrow Key Disable ===
-- FIX: Added noremap=true — without it, arrow mappings can be overridden downstream.
local nop_opts = { desc = "Arrow Disabled", noremap = true, silent = true }
for _, mode in ipairs({ "n", "v" }) do
  for _, arrow in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
    kset.set(mode, arrow, "<Nop>", nop_opts)
  end
end

-- === Whitespace & Tab Trimmer (single buffer pass) ===
-- Both transformations share one nvim_buf_get_lines call and accumulate
-- changed lines into a single batch rather than per-line nvim_buf_set_lines
-- calls (which would create many undo entries).
local trim_pattern = "^(.-)%s*$"
local tab_pattern  = "\t"

local function clean_buffer()
  if not bo.modifiable then return end
  if not bo.modified   then return end

  -- FIX: Skip special buffers (terminal, quickfix, prompt, etc.) to avoid corruption.
  local bt = bo.buftype
  if bt ~= "" and bt ~= "acwrite" then return end

  -- FIX: Respect per-buffer expandtab and tabstop instead of the hardcoded "  ".
  --      Previously every tab was replaced with 2 spaces regardless of buffer settings,
  --      which would corrupt Go files, Makefiles, and 4-space-indent projects.
  if not bo.expandtab then return end  -- don't mangle intentional tabs
  local tab_repl = string.rep(" ", bo.tabstop)

  local bufnr         = api.nvim_get_current_buf()
  local lines         = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local changed_ranges = {}  -- { {start, end, lines} }

  local run_start = nil
  local run_lines = {}

  -- end_excl: 0-indexed exclusive end for nvim_buf_set_lines (passed directly by callers).
  local function flush_run(end_excl)
    if run_start then
      changed_ranges[#changed_ranges + 1] = { run_start, end_excl, run_lines }
      run_start = nil
      run_lines = {}
    end
  end

  for i, l in ipairs(lines) do
    local new_line = l:match(trim_pattern)
    if new_line:find(tab_pattern, 1, true) then
      new_line = new_line:gsub(tab_pattern, tab_repl)
    end
    if new_line ~= l then
      if not run_start then
        run_start = i - 1  -- convert to 0-indexed inclusive start
        run_lines = {}
      end
      run_lines[#run_lines + 1] = new_line
    else
      -- Line i is unchanged; the run (if any) ended at line i-1.
      -- 0-indexed exclusive end = i-1 (the unchanged line's 0-idx position).
      flush_run(i - 1)
    end
  end
  -- Flush any trailing run; 0-indexed exclusive end = #lines (one past last line).
  flush_run(#lines)

  for _, range in ipairs(changed_ranges) do
    api.nvim_buf_set_lines(bufnr, range[1], range[2], false, range[3])
  end
end

local save_group = augroup("SaveHooks", { clear = true })
autocmd("BufWritePre", {
  group    = save_group,
  pattern  = { "*.lua", "*.c", "*.cpp", "*.py", "*.js", "*.java" },
  callback = clean_buffer,
})

-- === Deferred Initialization ===
autocmd("VimEnter", {
  once     = true,
  callback = function()
    defer_fn(function()
      opt.shadafile = ""
      opt.shada     = "!,'100,<50,s10,h"
      local shada_path = fn.stdpath("data") .. "/shada/main.shada"
      if fn.filereadable(shada_path) == 1 then
        pcall(cmd, "silent! rshada")
      end
      opt.clipboard = "unnamedplus"
    end, 100)
  end,
})

-- === Search Counter ===
_G.search_info = function()
  if vset.hlsearch == 0 then return "" end
  local key    = fn.getreg("/")
  local cached = search_cache:get(key)
  if cached then return cached end

  local ok, s  = pcall(fn.searchcount, { maxcount = 0, timeout = 100 })
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
  group    = macro_group,
  callback = function()
    macro_reg = fn.reg_recording()
    RedrawScheduler:schedule("status")
  end,
})
autocmd("RecordingLeave", {
  group    = macro_group,
  callback = function()
    macro_reg = ""
    RedrawScheduler:schedule("status")
  end,
})

-- === Statusline ===
vim.o.statusline = "%t %y%h%m%r%=%{v:lua.macro_info()}Ln %l/%L, Col %c%{v:lua.search_info()} %P"

-- === Clear Highlight ===
local function clear_hlsearch()
  if vset.hlsearch == 1 then
    cmd("nohlsearch")
    -- Invalidate only the active pattern; other cached counts remain valid.
    search_cache:_remove_key(fn.getreg("/"))
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

-- === Zen Mode ===
local zen_state_file  = fn.stdpath("data") .. "/zen_mode_state"
local zen_state_cache = nil

local ZenMode = {
  active  = false,
  saved   = {},
  _busy   = false,
  config  = {
    syntax       = false,
    number       = false,
    showcmd      = false,
    laststatus   = 0,
    cmdheight    = 0,
    signcolumn   = "no",
    cursorline   = false,
    cursorcolumn = false,
    list         = false,
    showmode     = false,
    ruler        = false,
    spell        = false,
  },
  -- Separated into arrays so batch_apply_settings can dispatch correctly.
  window_opts = { "number", "signcolumn", "cursorline", "cursorcolumn", "list", "spell" },
  global_opts = { "showcmd", "laststatus", "cmdheight", "showmode", "ruler" },
}

-- Build an O(1) lookup set for global_opts (fixes the original array-as-map bug).
local _zen_global_opt_set = {}
for _, k in ipairs(ZenMode.global_opts) do _zen_global_opt_set[k] = true end

-- === Async File I/O for Zen State ===
local function save_zen_state_async()
  zen_state_cache = ZenMode.active
  uv.fs_open(zen_state_file, "w", 438, function(err, fd)
    if err or not fd then return end
    local data = ZenMode.active and "1" or "0"
    uv.fs_write(fd, data, 0, function()
      uv.fs_close(fd, function() end)
    end)
  end)
end

-- Synchronous variant for VimLeavePre: async callbacks may never fire
-- if Neovim exits before the event loop gets control back.
local function save_zen_state_sync()
  zen_state_cache = ZenMode.active
  local fd = uv.fs_open(zen_state_file, "w", 438)
  if not fd then return end
  uv.fs_write(fd, ZenMode.active and "1" or "0", 0)
  uv.fs_close(fd)
end

local function load_zen_state_sync()
  if zen_state_cache ~= nil then return zen_state_cache end

  local fd = uv.fs_open(zen_state_file, "r", 438)
  if not fd then zen_state_cache = false; return false end

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
-- Uses _zen_global_opt_set for correct O(1) dispatch.
local function batch_apply_settings(settings, is_global)
  if is_global then
    for k, v in pairs(settings) do
      if k == "syntax" then
        cmd(v and "syntax on" or "syntax off")
      elseif _zen_global_opt_set[k] then
        vim.o[k] = v
      end
    end
  end

  local wins = api.nvim_list_wins()
  for _, win in ipairs(wins) do
    api.nvim_win_call(win, function()
      for _, opt_name in ipairs(ZenMode.window_opts) do
        if settings[opt_name] ~= nil then
          vim.wo[opt_name] = settings[opt_name]
        end
      end
    end)
  end
end

-- === Zen State Snapshot (deduplicated helper) ===
local function capture_zen_snapshot()
  return {
    syntax       = vim.o.syntax ~= "off",
    number       = vim.wo.number,
    showcmd      = vim.o.showcmd,
    laststatus   = vim.o.laststatus,
    cmdheight    = vim.o.cmdheight,
    signcolumn   = vim.wo.signcolumn,
    cursorline   = vim.wo.cursorline,
    cursorcolumn = vim.wo.cursorcolumn,
    list         = vim.wo.list,
    showmode     = vim.o.showmode,
    ruler        = vim.o.ruler,
    spell        = vim.wo.spell,
    status_hl    = api.nvim_get_hl(0, { name = "StatusLine", link = false }),
    statusline   = vim.o.statusline,
  }
end

-- === Tabline ===
local tab_cache = Cache:new(5, 200)

function _G.tabline_numbers()
  local current   = fn.tabpagenr()
  local total     = fn.tabpagenr('$')
  local cache_key = current .. "_" .. total .. "_" .. (ZenMode.active and "z" or "n")

  local cached = tab_cache:get(cache_key)
  if cached then return cached end

  local parts = {}
  for i = 1, total do
    parts[#parts + 1] = (i == current) and '%#TabLineSel#' or '%#TabLine#'
    parts[#parts + 1] = ' ' .. tostring(i) .. ' '

    if not ZenMode.active then
      local buflist = fn.tabpagebuflist(i)
      local winnr   = fn.tabpagewinnr(i)
      local bufnr   = buflist[winnr] or 0
      if fn.bufexists(bufnr) == 1 then
        local mod  = (fn.getbufvar(bufnr, '&modified') == 1) and '+' or ''
        local name = fn.fnamemodify(fn.bufname(bufnr), ':t')
        name = (name ~= "") and name or '[No Name]'
        parts[#parts + 1] = ':' .. name .. mod
      end
    end

    parts[#parts + 1] = ' '
  end

  parts[#parts + 1] = '%#TabLineFill#'
  local result = table.concat(parts)
  tab_cache:set(cache_key, result)
  return result
end

vim.o.tabline = '%!v:lua.tabline_numbers()'

-- === Zen Statusline ===
function _G.zen_statusline() return "~" end

-- === Toggle Zen Mode ===
local function toggle_zen_mode()
  if ZenMode._busy then return end
  ZenMode._busy  = true
  ZenMode.active = not ZenMode.active

  if ZenMode.active then
    ZenMode.saved = capture_zen_snapshot()
    batch_apply_settings(ZenMode.config, true)
    api.nvim_set_hl(0, "StatusLine", { bg = "NONE", fg = "#4F5258", bold = false })
    vim.o.statusline = "%!v:lua.zen_statusline()"
  else
    batch_apply_settings(ZenMode.saved, true)
    if ZenMode.saved.status_hl  then api.nvim_set_hl(0, "StatusLine", ZenMode.saved.status_hl) end
    if ZenMode.saved.statusline then vim.o.statusline = ZenMode.saved.statusline end
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
  desc    = "Toggle Zen Mode",
  noremap = true,
  silent  = true,
})

-- === Auto-apply Zen Settings to New Windows ===
local zen_group         = augroup("ZenModeAuto", { clear = true })
local zen_apply_pending = false

autocmd({ "WinNew", "WinEnter", "BufWinEnter" }, {
  group    = zen_group,
  callback = function()
    if ZenMode.active and not zen_apply_pending then
      zen_apply_pending = true
      schedule(function()
        for _, opt_name in ipairs(ZenMode.window_opts) do
          if ZenMode.config[opt_name] ~= nil then
            vim.wo[opt_name] = ZenMode.config[opt_name]
          end
        end
        zen_apply_pending = false
      end)
    end
  end,
})

-- === Restore Zen Mode on Startup ===
autocmd("VimEnter", {
  once     = true,
  callback = function()
    defer_fn(function()
      if load_zen_state_sync() and not ZenMode.active then
        ZenMode.saved  = capture_zen_snapshot()
        ZenMode.active = true
        batch_apply_settings(ZenMode.config, true)
        api.nvim_set_hl(0, "StatusLine", { bg = "NONE", fg = "#4F5258", bold = false })
        vim.o.statusline = "%!v:lua.zen_statusline()"
        schedule(function() RedrawScheduler:schedule("tabline") end)
      end
    end, 150)
  end,
})

-- === Unified VimLeavePre Cleanup ===
-- Consolidates zen state persistence and timer teardown into one autocmd.
autocmd("VimLeavePre", {
  once     = true,
  callback = function()
    save_zen_state_sync()
    for _, t in pairs(Timers) do
      if t:is_active() then t:stop() end
      t:close()
    end
  end,
})

-- === Memory Management ===
local function run_gc()
  search_cache:gc()
  syntax_cache:gc()
  tab_cache:gc()
end

-- FIX: collectgarbage("collect") on every FocusLost caused a hard GC pause
--      on every Alt-Tab with no cooldown. Added a 10-second minimum interval.
local _gc_cooldown = false
autocmd("FocusLost", {
  callback = function()
    run_gc()
    if not _gc_cooldown then
      _gc_cooldown = true
      defer_fn(function()
        collectgarbage("collect")
        _gc_cooldown = false
      end, 10000)  -- 10s cooldown between forced GC cycles
    end
  end,
})

-- === Periodic Cache GC (static timer, no reallocation) ===
Timers.gc:start(300000, 300000, function()
  schedule(run_gc)
end)

-- === CursorMoved Debounce ===
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
  end,
})

_G.zen_mode = ZenMode
