-- === Neovim 0.12+ Configuration ===

-- === Localized References ===
local opt      = vim.opt
local cmd      = vim.cmd
local fn       = vim.fn
local api      = vim.api
local kset     = vim.keymap
local vset     = vim.v
local bo       = vim.bo
local g        = vim.g
local defer_fn = vim.defer_fn
local schedule = vim.schedule
local uv       = vim.uv
-- Localized to avoid repeated global-chain lookups on hot-path events.
local ts_get_parser = vim.treesitter.get_parser

-- === Shutdown Flag ===
-- Set in VimLeavePre before timers are closed. Every timer start site checks
-- this flag so that in-flight schedule() callbacks cannot restart a closed
-- libuv handle (which would raise a EBADF-class error in the log).
local _shutting_down = false

-- === Static Timer Allocation (prevents GC churn) ===
-- All three timers are localized immediately; Timers table exists only for
-- unified teardown in VimLeavePre.
local cursor_timer = uv.new_timer()
local redraw_timer = uv.new_timer()
local gc_timer     = uv.new_timer()
local Timers = { cursor = cursor_timer, redraw = redraw_timer, gc = gc_timer }

-- === Batch Plugin & Provider Disabling ===
-- Unified data table: string keys are compile-time constants, so there are
-- zero runtime concatenations at startup (vs. 16 in the loop-based approach).
-- Comments mark each group for future maintainers.
local _g_flags = {
  -- Slow / unused built-in plugins (sentinel = 1)
  loaded_matchparen       = 1,
  loaded_matchit          = 1,
  loaded_gzip             = 1,
  loaded_tar              = 1,
  loaded_tarPlugin        = 1,
  loaded_zip              = 1,
  loaded_zipPlugin        = 1,
  loaded_getscript        = 1,
  loaded_getscriptPlugin  = 1,
  loaded_vimball          = 1,
  loaded_vimballPlugin    = 1,
  loaded_rrhelper         = 1,
  loaded_tutor            = 1,
  -- External providers unused; 0 signals "provider absent" to Neovim.
  loaded_python_provider  = 0,
  loaded_python3_provider = 0,
  loaded_node_provider    = 0,
  loaded_perl_provider    = 0,
  loaded_ruby_provider    = 0,
}
for k, v in pairs(_g_flags) do g[k] = v end

-- === Options ===
-- Applied in a single table-driven loop; avoids 34 individual vim.opt
-- metatable dispatches and makes future auditing straightforward.
local _opts = {
  -- Performance
  mouse         = "",
  updatetime    = 250,
  synmaxcol     = 200,
  redrawtime    = 1000,
  maxmempattern = 2000,
  cursorline    = false,
  cursorcolumn  = false,
  -- UI
  number        = true,
  scrolloff     = 10,
  sidescrolloff = 8,
  showmode      = false,
  modeline      = false,
  undofile      = true,
  swapfile      = false,
  backup        = false,
  writebackup   = false,
  pumheight     = 10,       -- cap completion menu height; prevents layout thrash
  splitkeep     = "screen", -- reduce layout shifts on split (0.9+)
  jumpoptions   = "stack",  -- browser-history-style jump list
  -- Timing
  timeoutlen    = 300,
  ttimeoutlen   = 40,
  keymodel      = "",
  -- Encoding (ucs-bom prefix handles BOM detection; no behaviour change for UTF-8)
  fileencodings = "ucs-bom,utf-8,default,latin1",
  fileformats   = "unix,dos,mac",
  -- Indentation
  expandtab     = true,
  shiftwidth    = 2,
  tabstop       = 2,
  softtabstop   = 2,
  smartindent   = true,
  autoindent    = true,
  -- Search
  ignorecase    = true,
  smartcase     = true,
  hlsearch      = true,
  incsearch     = true,
  -- Interface
  cmdheight     = 0,
  splitright    = true,
  splitbelow    = true,
  termguicolors = true,
  -- History / memory
  history       = 2000,
  undolevels    = 1000,
}
for k, v in pairs(_opts) do opt[k] = v end

-- Append / list operations cannot live in the batch table.
opt.backupskip:append({ "/tmp/*", "/private/tmp/*" })
opt.completeopt = { "menuone", "noinsert", "noselect" }
opt.shortmess:append("sI")   -- suppress intro screen and search-wrap messages

-- === Disable LSP Logging ===
-- vim.lsp.set_log_level() was deprecated in 0.12. Replacement: vim.lsp.log.set_level().
pcall(vim.lsp.log.set_level, "OFF")

-- === Highlight Groups ===
-- Branches on vim.o.background so colours remain legible on light themes.
-- The ColorScheme callback is deferred by one schedule() tick to let the theme
-- finish applying before we override specific groups.
local function apply_highlights()
  local is_dark = vim.o.background ~= "light"
  local hl_defs = is_dark and {
    TabLine     = { fg = '#808080', bg = '#1e1e1e' },
    TabLineSel  = { fg = '#ffffff', bg = '#3a3a3a', bold = true },
    TabLineFill = { fg = 'NONE',    bg = '#1e1e1e' },
  } or {
    TabLine     = { fg = '#555555', bg = '#d4d4d4' },
    TabLineSel  = { fg = '#000000', bg = '#ffffff', bold = true },
    TabLineFill = { fg = 'NONE',    bg = '#d4d4d4' },
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
  -- Defer: some colorscheme plugins emit multiple ColorScheme events in one
  -- load sequence; the schedule() tick ensures our overrides run last.
  callback = function() schedule(apply_highlights) end,
})

-- === Cache System ===
-- Design notes:
--   * _order_len tracks the logical length of the order array explicitly.
--     Never use # on self.order because _remove_key creates interior nil holes,
--     making # return an undefined "border" value in Lua. This was a silent
--     correctness bug in the original implementation.
--   * _compact() rebuilds order and key_index in-place (no new table allocs).
--   * invalidate() is the public API; _remove_key() remains internal.
local Cache = {}
Cache.__index = Cache

function Cache:new(max_size, ttl)
  return setmetatable({
    data       = {},
    order      = {},
    key_index  = {},
    _size      = 0,
    _order_len = 0,   -- explicit length; never trust # on the sparse order array
    max_size   = max_size or 100,
    ttl        = ttl  or 1000,
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

-- Internal: removes from data + key_index, leaves a nil hole in order.
-- Holes are compacted in bulk by _compact() to avoid O(n) work per removal.
function Cache:_remove_key(key)
  if not self.data[key] then return end
  self.data[key] = nil
  self._size     = self._size - 1
  local idx = self.key_index[key]
  if idx then
    self.order[idx]     = nil  -- sparse hole; length tracked via _order_len
    self.key_index[key] = nil
    -- Do NOT decrement _order_len here: the slot is a hole inside the array,
    -- not a removal from the end. _compact() will rebuild the true length.
  end
end

-- Public alias; external callers must not depend on the internal name.
function Cache:invalidate(key) self:_remove_key(key) end

function Cache:set(key, value)
  local now = uv.now()

  if self.data[key] then
    -- Update in place; position in order is unchanged.
    self.data[key] = { value = value, time = now }
    return
  end

  -- Evict oldest live entry when at capacity (O(n) scan only on overflow).
  if self._size >= self.max_size then
    for i = 1, self._order_len do
      local old_key = self.order[i]
      if old_key then
        self:_remove_key(old_key)
        break
      end
    end
  end

  -- Compact when the order array has grown more than 2x the live entry count.
  if self._order_len > self.max_size * 2 then
    self:_compact()
  end

  self.data[key]              = { value = value, time = now }
  self._size                  = self._size + 1
  self._order_len             = self._order_len + 1
  self.order[self._order_len] = key
  self.key_index[key]         = self._order_len
end

-- Rebuild order and key_index in-place: reuses existing tables, clears
-- trailing stale slots, updates _order_len. Zero new table allocations.
function Cache:_compact()
  local order     = self.order
  local key_index = self.key_index
  local write = 0
  for i = 1, self._order_len do
    local key = order[i]
    if key and self.data[key] then
      write          = write + 1
      order[write]   = key
      key_index[key] = write
    end
  end
  -- Clear stale trailing slots without allocating a replacement array.
  for i = write + 1, self._order_len do order[i] = nil end
  self._order_len = write
end

function Cache:clear()
  self.data       = {}
  self.order      = {}
  self.key_index  = {}
  self._size      = 0
  self._order_len = 0
end

function Cache:gc()
  local now     = uv.now()
  local expired = {}
  for key, entry in pairs(self.data) do
    if (now - entry.time) > self.ttl then
      expired[#expired + 1] = key
    end
  end
  for _, key in ipairs(expired) do self:_remove_key(key) end
  if #expired > 0 then self:_compact() end
end

-- === Global Caches ===
local search_cache = Cache:new(10, 500)
local syntax_cache = Cache:new(20, 2000)
local tab_cache    = Cache:new(5,  200)

-- Hoisted to module scope: reused on every search_info cache miss.
-- Allocating this table inside search_info would cost one allocation per miss.
local _searchcount_opts = { maxcount = 0, timeout = 100 }

-- === Redraw Scheduler ===
-- Uses a bitmask integer instead of a pending table. Eliminates the table
-- entirely; bitwise OR is the accumulation operation. Adding a new redraw
-- type requires only a new constant and one branch in _do_redraw.
--
-- Neovim embeds LuaJIT (Lua 5.1): the Lua 5.4 bitwise operators & | are not
-- available. Use LuaJIT's bit library (bit.band / bit.bor) instead.
local bit_band = bit.band
local bit_bor  = bit.bor

local REDRAW_TABLINE = 1
local REDRAW_STATUS  = 2
local REDRAW_FULL    = 4

local _redraw_pending = 0
local _redraw_delay   = 16   -- ms; ~one frame at 60 Hz

local function _do_redraw()
  local p         = _redraw_pending
  _redraw_pending = 0
  if p == 0 then return end
  if bit_band(p, REDRAW_FULL) ~= 0 then
    cmd("redraw")
  elseif bit_band(p, REDRAW_TABLINE) ~= 0 and bit_band(p, REDRAW_STATUS) ~= 0 then
    cmd("redrawtabline")
    cmd("redrawstatus")
  elseif bit_band(p, REDRAW_TABLINE) ~= 0 then
    cmd("redrawtabline")
  elseif bit_band(p, REDRAW_STATUS) ~= 0 then
    cmd("redrawstatus")
  end
end

local function _redraw_timer_cb() schedule(_do_redraw) end

-- schedule_redraw() replaces RedrawScheduler:schedule(). Plain function;
-- no self lookup, no method dispatch overhead.
local function schedule_redraw(flags)
  _redraw_pending = bit_bor(_redraw_pending, flags)
  if _shutting_down or redraw_timer:is_active() then return end
  redraw_timer:start(_redraw_delay, 0, _redraw_timer_cb)
end

-- === Syntax FileType Handler ===
-- Hash sets give O(1) lookup vs O(n) tbl_contains on every FileType event.
-- Expanded to cover modern filetypes absent from the original sets.
local syntax_fast = {
  c=true, cpp=true, h=true, hpp=true,
  java=true, python=true, lua=true,
  javascript=true, typescript=true, tsx=true, jsx=true,
  go=true, rust=true, zig=true,
  ruby=true, php=true, swift=true,
}
local syntax_heavy = {
  json=true, yaml=true, toml=true,
  markdown=true, text=true, plaintex=true,
  html=true, css=true, scss=true, xml=true,
}
local heavy_buffers = {}
local heavy_window_opts = {
  foldmethod  = "manual",
  wrap        = true,
  linebreak   = true,
  breakindent = true,
}

local function mark_heavy_buffer(buf)
  heavy_buffers[buf] = true
  api.nvim_set_option_value("synmaxcol", 120, { buf = buf })
end

local function apply_heavy_window_settings(win)
  if not api.nvim_win_is_valid(win) then return end
  local buf = api.nvim_win_get_buf(win)
  if not heavy_buffers[buf] then return end
  local wopts = { win = win }
  for k, v in pairs(heavy_window_opts) do
    api.nvim_set_option_value(k, v, wopts)
  end
end

autocmd("FileType", {
  group    = augroup("PerfFileTypeHandler", { clear = true }),
  pattern  = "*",
  callback = function(args)
    local ft  = args.match
    local buf = args.buf
    -- \0 as key separator: cannot appear in a filetype string, avoids
    -- ambiguous concatenation (e.g. ft="lua" buf=5 vs ft="lua5" buf="").
    local cache_key = ft .. "\0" .. buf
    if syntax_cache:get(cache_key) then return end

    if syntax_fast[ft] then
      -- pcall guard: get_parser() returns nil on 0.12+ but could throw on
      -- older patch levels loaded via a version manager.
      local ok, parser = pcall(ts_get_parser, buf, ft)
      if not (ok and parser) then
        cmd("syntax sync minlines=200 maxlines=500")
      end
    elseif syntax_heavy[ft] then
      -- nvim_buf_line_count: native API equivalent of fn.line("$");
      -- avoids the vimscript bridge on every FileType event.
      if api.nvim_buf_line_count(buf) > 1000 then
        mark_heavy_buffer(buf)
        apply_heavy_window_settings(api.nvim_get_current_win())
      end
    end

    syntax_cache:set(cache_key, true)
  end,
})

-- Evict syntax cache entries when a buffer is deleted or wiped.
-- BufDelete covers :bdelete; BufWipeout covers :bwipeout and plugin-created
-- scratch buffers, both of which can immediately reuse the buffer number and
-- would get a false cache hit on the next FileType event.
autocmd({ "BufDelete", "BufWipeout" }, {
  group    = augroup("SyntaxCacheEvict", { clear = true }),
  callback = function(args)
    heavy_buffers[args.buf] = nil
    local buf_suffix = "\0" .. tostring(args.buf)
    local to_del = {}
    for key in pairs(syntax_cache.data) do
      if key:sub(-#buf_suffix) == buf_suffix then
        to_del[#to_del + 1] = key
      end
    end
    for _, k in ipairs(to_del) do syntax_cache:invalidate(k) end
  end,
})

-- === Window Setup ===
-- Unified handler: applies base window defaults, then layers zen settings on
-- top if zen is active. Replaces the two separate WinNew handlers that
-- previously could conflict with each other.
local win_defaults = {
  relativenumber = false,
  wrap           = false,
  linebreak      = false,
  breakindent    = false,
  signcolumn     = "yes:1",
}

local function setup_window(win)
  if not api.nvim_win_is_valid(win) then return end  -- guard against close race
  local wopts = { win = win }
  for k, v in pairs(win_defaults) do
    api.nvim_set_option_value(k, v, wopts)
  end
  api.nvim_set_option_value(
    "foldmethod",
    api.nvim_get_option_value("foldmethod", { scope = "global" }),
    wopts
  )
  apply_heavy_window_settings(win)
  -- If zen is active, layer its per-window overrides on top of base defaults.
  if _G.zen_mode and _G.zen_mode.active then
    for _, opt_name in ipairs(_G.zen_mode.window_opts) do
      local val = _G.zen_mode.config[opt_name]
      if val ~= nil then
        api.nvim_set_option_value(opt_name, val, wopts)
      end
    end
  end
end

setup_window(api.nvim_get_current_win())  -- seed the initial window

local win_setup_group = augroup("WinSetup", { clear = true })

autocmd("WinNew", {
  group    = win_setup_group,
  callback = function()
    -- schedule(): WinNew fires before the window is fully initialised.
    local win = api.nvim_get_current_win()
    schedule(function() setup_window(win) end)
  end,
})

autocmd("BufWinEnter", {
  group    = win_setup_group,
  callback = function()
    setup_window(api.nvim_get_current_win())
  end,
})

-- === Arrow Key Disable ===
-- Extended to insert and operator-pending modes: trains consistent hjkl
-- habits without leaving an escape hatch in insert mode.
local nop_opts   = { desc = "Arrow Disabled", noremap = true, silent = true }
local nop_modes  = { "n", "v", "i", "o" }
local nop_arrows = { "<Up>", "<Down>", "<Left>", "<Right>" }
for _, mode in ipairs(nop_modes) do
  for _, arrow in ipairs(nop_arrows) do
    kset.set(mode, arrow, "<Nop>", nop_opts)
  end
end

-- === Whitespace & Tab Trimmer ===
-- Both transformations share one nvim_buf_get_lines call and accumulate
-- changed lines into a single batch to avoid many undo entries.
--
-- All scratch state and the flush helper are at module scope:
--   * Eliminates one closure allocation + upvalue cells per BufWritePre call.
--   * _cb_run_lines is reused across calls; a snapshot is taken per-run before
--     passing to nvim_buf_set_lines.
local trim_pattern = "^(.-)%s*$"
local tab_pattern  = "\t"

local _cb_ranges     = {}   -- { {start_0idx, end_0idx_excl, lines_snapshot} }
local _cb_ranges_len = 0
local _cb_run_lines  = {}   -- accumulator for the current contiguous run
local _cb_run_len    = 0
local _cb_run_start  = nil  -- 0-indexed inclusive start of current run, or nil

local function _cb_flush(end_excl)
  if not _cb_run_start then return end
  -- Snapshot the current run: _cb_run_lines will be reused for the next run.
  local snapshot = {}
  for i = 1, _cb_run_len do snapshot[i] = _cb_run_lines[i] end
  _cb_ranges_len             = _cb_ranges_len + 1
  _cb_ranges[_cb_ranges_len] = { _cb_run_start, end_excl, snapshot }
  _cb_run_start = nil
  _cb_run_len   = 0
end

local MAX_CLEAN_LINES = 50000   -- skip the pass on very large files

local function clean_buffer()
  if not bo.modifiable then return end
  if not bo.modified   then return end
  local bt = bo.buftype
  if bt ~= "" and bt ~= "acwrite" then return end
  if not bo.expandtab then return end   -- don't mangle intentional tabs

  local bufnr = api.nvim_get_current_buf()
  if api.nvim_buf_line_count(bufnr) > MAX_CLEAN_LINES then return end

  local tab_repl = string.rep(" ", bo.tabstop)
  local lines    = api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Reset scratch state (no allocation).
  _cb_ranges_len = 0
  _cb_run_start  = nil
  _cb_run_len    = 0

  for i, l in ipairs(lines) do
    local new_line = l:match(trim_pattern)
    -- find() guard before gsub(): on files where most lines are tab-free,
    -- skipping gsub() avoids one string operation per tab-free line.
    if new_line:find(tab_pattern, 1, true) then
      new_line = new_line:gsub(tab_pattern, tab_repl)
    end
    if new_line ~= l then
      if not _cb_run_start then _cb_run_start = i - 1 end  -- convert to 0-indexed
      _cb_run_len                = _cb_run_len + 1
      _cb_run_lines[_cb_run_len] = new_line
    else
      _cb_flush(i - 1)  -- 0-indexed exclusive end = unchanged line's 0-idx position
    end
  end
  _cb_flush(#lines)   -- flush trailing run; exclusive end = one past last line

  for i = 1, _cb_ranges_len do
    local r = _cb_ranges[i]
    api.nvim_buf_set_lines(bufnr, r[1], r[2], false, r[3])
  end
end

local save_group = augroup("SaveHooks", { clear = true })
autocmd("BufWritePre", {
  group   = save_group,
  -- Extended to cover modern filetypes absent from the original pattern list.
  pattern = {
    "*.lua",
    "*.c", "*.h", "*.cpp", "*.hpp",
    "*.py",
    "*.js", "*.ts", "*.tsx", "*.jsx",
    "*.java",
    "*.go",
    "*.rs",
    "*.sh", "*.bash",
    "*.toml", "*.yaml", "*.yml",
  },
  callback = clean_buffer,
})

-- === Search Counter ===
-- Cache key includes the full cursor position so same-line movement across
-- multiple matches cannot reuse a stale searchcount() result.
local function get_search_cache_key()
  local pattern = fn.getreg("/")
  local cursor  = api.nvim_win_get_cursor(0)
  return pattern, pattern .. "\0" .. cursor[1] .. "\0" .. cursor[2]
end

local function get_search_count_display()
  if vset.hlsearch == 0 then return "" end
  local _, key = get_search_cache_key()
  local cached = search_cache:get(key)
  if cached then return cached end

  local ok, s = pcall(fn.searchcount, _searchcount_opts)
  local result = ""
  if ok and s and s.total and s.total > 0 then
    result = string.format(" %d/%d", s.current or 0, s.total)
  end
  search_cache:set(key, result)
  return result
end

_G.search_info = function() return get_search_count_display() end

-- === Macro Recording Indicator ===
-- _macro_display is pre-computed once on RecordingEnter so that the hot
-- statusline render path performs zero string allocations per redraw.
local _macro_display = ""

_G.macro_info = function() return _macro_display end

local macro_group = augroup("MacroStatusline", { clear = true })
autocmd("RecordingEnter", {
  group    = macro_group,
  callback = function()
    -- Concatenation happens once per session, not once per statusline render.
    _macro_display = " REC @" .. fn.reg_recording() .. " "
    schedule_redraw(REDRAW_STATUS)
  end,
})
autocmd("RecordingLeave", {
  group    = macro_group,
  callback = function()
    _macro_display = ""
    schedule_redraw(REDRAW_STATUS)
  end,
})

-- === Statusline ===
-- A single %!v:lua.statusline_render() performs one vimscript->Lua bridge
-- per redraw. The original format string made two separate bridges
-- (%{v:lua.macro_info()} and %{v:lua.search_info()}) on every evaluation.
-- search_info logic is inlined here; the _G.search_info global is kept for
-- external compatibility but is no longer invoked by the statusline itself.
_G.statusline_render = function()
  local parts = {}

  -- Left: file name + type flags
  parts[#parts + 1] = "%t %y%h%m%r"

  -- Right-align separator
  parts[#parts + 1] = "%="

  -- Macro indicator (pre-computed string; zero allocation on render)
  if _macro_display ~= "" then
    parts[#parts + 1] = _macro_display
  end

  -- Cursor position
  parts[#parts + 1] = "Ln %l/%L, Col %c"

  -- Search count (cursor-keyed cache shared with _G.search_info)
  if vset.hlsearch == 1 then
    local count = get_search_count_display()
    if count ~= "" then parts[#parts + 1] = count end
  end

  -- Scroll percentage
  parts[#parts + 1] = " %P"

  return table.concat(parts)
end

vim.o.statusline = "%!v:lua.statusline_render()"

-- === Clear Highlight ===
local function clear_hlsearch()
  if vset.hlsearch == 1 then
    cmd("nohlsearch")
    -- Keys are stored as pattern.."\0"..line.."\0"..col, so we must scan for all
    -- entries whose prefix matches the active pattern. A bare-pattern
    -- lookup would never hit any key and silently no-op.
    local prefix = fn.getreg("/") .. "\0"
    local to_del = {}
    for k in pairs(search_cache.data) do
      if k:sub(1, #prefix) == prefix then
        to_del[#to_del + 1] = k
      end
    end
    for _, k in ipairs(to_del) do search_cache:invalidate(k) end
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
local zen_state_cache = nil   -- in-memory cache; avoids repeated disk reads

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
  -- Separate option lists keep global and window restores explicit.
  window_opts = { "number", "signcolumn", "cursorline", "cursorcolumn", "list", "spell" },
  global_opts = { "showcmd", "laststatus", "cmdheight", "showmode", "ruler" },
}

local _zen_global_opt_set = {}
for _, k in ipairs(ZenMode.global_opts) do _zen_global_opt_set[k] = true end

-- === Zen State Persistence (JSON) ===
-- JSON format replaces the raw "0"/"1" byte so future fields (e.g., saved
-- window width, colorscheme override) can be added without a format break.
-- A legacy fallback in load_zen_state_sync handles existing "1"/"0" files.
-- The payload is tiny, so writes stay synchronous for deterministic ordering.
local function save_zen_state_sync()
  zen_state_cache = ZenMode.active
  local fd = uv.fs_open(zen_state_file, "w", 438)
  if not fd then return end
  uv.fs_write(fd, vim.json.encode({ active = ZenMode.active }), 0)
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
  local raw = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  local ok, parsed = pcall(vim.json.decode, raw)
  if ok and type(parsed) == "table" then
    -- Current JSON format: { active = true/false }
    zen_state_cache = parsed.active == true
  else
    -- Legacy fallback: raw "1" or "0" byte from previous format.
    zen_state_cache = (raw == "1")
  end
  return zen_state_cache
end

-- === Batch Window Operations ===
-- nvim_win_is_valid() guard prevents errors when a window closes between
-- nvim_list_wins() and the inner set loop (e.g., during plugin startup chains).
local function apply_global_settings(settings)
  for k, v in pairs(settings) do
    if k == "syntax" then
      cmd(v and "syntax on" or "syntax off")
    elseif _zen_global_opt_set[k] then
      vim.o[k] = v
    end
  end
end

local function apply_window_settings(win, settings)
  if not api.nvim_win_is_valid(win) then return end
  local wopts = { win = win }
  for _, opt_name in ipairs(ZenMode.window_opts) do
    local val = settings[opt_name]
    if val ~= nil then
      api.nvim_set_option_value(opt_name, val, wopts)
    end
  end
end

local function apply_settings_to_all_windows(settings)
  for _, win in ipairs(api.nvim_list_wins()) do
    apply_window_settings(win, settings)
  end
end

-- === Zen State Snapshot ===
local function capture_window_snapshot(win)
  if not api.nvim_win_is_valid(win) then return {} end
  return {
    number       = api.nvim_get_option_value("number",       { win = win }),
    signcolumn   = api.nvim_get_option_value("signcolumn",   { win = win }),
    cursorline   = api.nvim_get_option_value("cursorline",   { win = win }),
    cursorcolumn = api.nvim_get_option_value("cursorcolumn", { win = win }),
    list         = api.nvim_get_option_value("list",         { win = win }),
    spell        = api.nvim_get_option_value("spell",        { win = win }),
  }
end

local function capture_zen_snapshot()
  local windows = {}
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(win) then
      windows[win] = capture_window_snapshot(win)
    end
  end
  return {
    global = {
      syntax     = vim.o.syntax ~= "off",
      showcmd    = vim.o.showcmd,
      laststatus = vim.o.laststatus,
      cmdheight  = vim.o.cmdheight,
      showmode   = vim.o.showmode,
      ruler      = vim.o.ruler,
      status_hl  = api.nvim_get_hl(0, { name = "StatusLine", link = false }),
      statusline = vim.o.statusline,
    },
    windows = windows,
  }
end

local function restore_zen_windows(saved_windows)
  for _, win in ipairs(api.nvim_list_wins()) do
    local saved = saved_windows[win]
    if saved then
      apply_window_settings(win, saved)
    else
      setup_window(win)
    end
  end
end

local function enter_zen_mode()
  ZenMode.saved = capture_zen_snapshot()
  ZenMode.active = true
  apply_global_settings(ZenMode.config)
  apply_settings_to_all_windows(ZenMode.config)
  api.nvim_set_hl(0, "StatusLine", { bg = "NONE", fg = "#4F5258", bold = false })
  vim.o.statusline = "%!v:lua.zen_statusline()"
end

local function leave_zen_mode()
  local saved = ZenMode.saved
  local global = saved.global or {}
  ZenMode.active = false
  apply_global_settings(global)
  restore_zen_windows(saved.windows or {})
  if global.status_hl then
    api.nvim_set_hl(0, "StatusLine", global.status_hl)
  end
  if global.statusline then
    vim.o.statusline = global.statusline
  end
  ZenMode.saved = {}
end

-- === Tabline ===
function _G.tabline_numbers()
  local current   = fn.tabpagenr()
  local total     = fn.tabpagenr('$')
  local cache_key = current .. "_" .. total .. "_" .. (ZenMode.active and "z" or "n")

  local cached = tab_cache:get(cache_key)
  if cached then return cached end

  -- Cache miss: enumerate via API to avoid per-tab fn bridges.
  -- nvim_list_tabpages() is called only here (after the cache check) so the
  -- table allocation does not occur on cache hits.
  local tabpages = api.nvim_list_tabpages()
  local parts = {}
  for i, tp in ipairs(tabpages) do
    parts[#parts + 1] = (i == current) and '%#TabLineSel#' or '%#TabLine#'
    parts[#parts + 1] = ' ' .. i .. ' '   -- .. coerces int; tostring() unneeded

    if not ZenMode.active then
      -- nvim_tabpage_get_win + nvim_win_get_buf: 2 API calls instead of
      -- 2 fn bridges + tabpagebuflist array alloc.
      local win   = api.nvim_tabpage_get_win(tp)
      local bufnr = api.nvim_win_get_buf(win)
      if api.nvim_buf_is_valid(bufnr) then
        local mod  = vim.bo[bufnr].modified and '+' or ''
        local name = api.nvim_buf_get_name(bufnr)
        name = (name ~= "") and fn.fnamemodify(name, ':t') or '[No Name]'
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

local function invalidate_tabline()
  tab_cache:clear()
  schedule_redraw(REDRAW_TABLINE)
end

autocmd({ "BufEnter", "WinEnter", "BufModifiedSet", "BufWritePost", "BufFilePost" }, {
  group    = augroup("TablineCacheInvalidate", { clear = true }),
  callback = invalidate_tabline,
})

-- === Zen Statusline ===
function _G.zen_statusline() return "~" end

-- === Toggle Zen Mode ===
local function toggle_zen_mode()
  if ZenMode._busy then return end
  ZenMode._busy = true

  if ZenMode.active then
    leave_zen_mode()
  else
    enter_zen_mode()
  end

  save_zen_state_sync()
  tab_cache:clear()

  schedule(function()
    ZenMode._busy = false
    schedule_redraw(REDRAW_TABLINE)
  end)
end

kset.set("n", "<Space><Space>", toggle_zen_mode, {
  desc    = "Toggle Zen Mode",
  noremap = true,
  silent  = true,
})

-- Export ZenMode before VimEnter so that setup_window() (fired from WinNew)
-- can read ZenMode.active, ZenMode.window_opts, and ZenMode.config.
_G.zen_mode = ZenMode

-- === Deferred Initialization ===
-- Single VimEnter handler with two chained phases replaces the original two
-- separate handlers at T+100 ms and T+150 ms. Chaining via schedule() makes
-- the phase-2 dependency on phase-1 explicit and eliminates the implicit
-- fixed-offset timing assumption.
--
-- Phase 1 (T+100 ms): shada load + clipboard.
-- Phase 2 (one event-loop tick after phase 1 completes): zen restore.
--
-- Note on shadafile: Neovim reads shada before VimEnter, so setting
-- shadafile="" here only blocks future implicit writes. The explicit rshada
-- call re-reads with the tuned format string — that is the actual intent.
autocmd("VimEnter", {
  once     = true,
  callback = function()
    defer_fn(function()
      -- Phase 1: shada + clipboard setup.
      opt.shadafile = ""
      opt.shada     = "!,'100,<50,s10,h"
      local shada_path = fn.stdpath("data") .. "/shada/main.shada"
      -- uv.fs_stat: native Lua equivalent of fn.filereadable(); no vimscript bridge.
      if uv.fs_stat(shada_path) then
        pcall(cmd, "silent! rshada")
      end
      opt.clipboard = "unnamedplus"

      -- Phase 2: zen restore chained immediately after phase 1.
      schedule(function()
        if load_zen_state_sync() and not ZenMode.active then
          enter_zen_mode()
          schedule(function() schedule_redraw(REDRAW_TABLINE) end)
        end
      end)
    end, 100)
  end,
})

-- === Unified VimLeavePre Cleanup ===
-- _shutting_down is set before timers are closed so that in-flight
-- schedule() callbacks (cursor debounce, redraw) cannot restart closed handles.
autocmd("VimLeavePre", {
  once     = true,
  callback = function()
    _shutting_down = true
    save_zen_state_sync()
    for _, t in pairs(Timers) do
      -- is_closing() is safe on any handle state; prevents double-close errors.
      if not t:is_closing() then
        if t:is_active() then t:stop() end
        t:close()
      end
    end
  end,
})

-- === Memory Management ===
-- run_gc has its own minimum-gap guard (5 s) so that rapid FocusLost events
-- (e.g., alt-tabbing quickly) do not iterate all three caches every time.
-- The heavier collectgarbage() full cycle keeps its separate 10 s cooldown.
local _gc_last_run   = 0
local _gc_min_gap_ms = 5000
local _gc_cooldown   = false

local function run_gc()
  local now = uv.now()
  if (now - _gc_last_run) < _gc_min_gap_ms then return end
  _gc_last_run = now
  search_cache:gc()
  syntax_cache:gc()
  tab_cache:gc()
end

autocmd("FocusLost", {
  callback = function()
    run_gc()
    if not _gc_cooldown then
      _gc_cooldown = true
      defer_fn(function()
        collectgarbage("collect")
        _gc_cooldown = false
      end, 10000)  -- 10 s cooldown between forced full GC cycles
    end
  end,
})

-- === Periodic Cache GC (static timer, no reallocation) ===
gc_timer:start(300000, 300000, function()
  schedule(run_gc)
end)

-- === CursorMoved Debounce ===
-- Both callbacks are module-level functions (pre-allocated once at load time).
-- Without this, every CursorMoved event allocates 2 closures immediately
-- discarded on the next movement (e.g. holding an arrow key).
local function _cursor_redraw()
  if vset.hlsearch == 1 then
    schedule_redraw(REDRAW_STATUS)
  end
end
local function _cursor_timer_cb()
  schedule(_cursor_redraw)
end

autocmd("CursorMoved", {
  callback = function()
    if _shutting_down then return end   -- do not restart a closed timer
    cursor_timer:stop()
    cursor_timer:start(100, 0, _cursor_timer_cb)
  end,
})
