-- ======================================================================
-- Enterprise-Grade Neovim Configuration Framework
-- High-Performance, Production-Ready Architecture
-- ======================================================================

---@class NeovimConfig
---@field private _initialized boolean
---@field private _modules table<string, table>
---@field private _event_handlers table<string, function[]>
local M = {}

-- ======================================================================
-- PERFORMANCE OPTIMIZATIONS
-- ======================================================================

-- Enable native Lua loader for faster startup
if vim.loader and vim.loader.enabled ~= true then
  vim.loader.enable()
end

-- Cache frequently used APIs to reduce table lookups
local api_cache = setmetatable({}, {
  __index = function(t, k)
    local value = vim[k]
    if type(value) == 'table' then
      rawset(t, k, value)
    end
    return value
  end
})

-- Optimized API access layer
local api = {
  -- Core vim APIs
  o = api_cache.o,
  wo = api_cache.wo,
  bo = api_cache.bo,
  opt = api_cache.opt,
  opt_local = api_cache.opt_local,
  cmd = api_cache.cmd,
  fn = api_cache.fn,
  api = api_cache.api,
  keymap = api_cache.keymap,

  -- Performance utilities
  schedule = vim.schedule,
  defer_fn = vim.defer_fn,
  in_fast_event = vim.in_fast_event,
}

-- ======================================================================
-- CONFIGURATION SCHEMA
-- ======================================================================

---@class ConfigSchema
local CONFIG = {
  -- Performance tuning parameters
  PERFORMANCE = {
    UPDATETIME = 100,           -- CursorHold event frequency (ms)
    SYNMAXCOL = 200,           -- Syntax highlighting column limit
    REDRAWTIME = 1000,         -- Maximum redraw time (ms)
    MAXMEMPATTERN = 2000,      -- Pattern matching memory limit (KB)
    TIMEOUTLEN = 300,          -- Key sequence timeout (ms)
    TTIMEOUTLEN = 40,          -- Terminal key code timeout (ms)
    LARGE_FILE_THRESHOLD = 1000, -- Lines threshold for large file optimizations
  },

  -- UI/UX configuration
  INTERFACE = {
    SCROLLOFF = 10,            -- Vertical scroll margin
    SIDESCROLLOFF = 8,         -- Horizontal scroll margin
    SIGN_COLUMN = "yes:1",     -- Sign column configuration
    CMDHEIGHT = 0,             -- Command line height
  },

  -- Editing behavior
  EDITING = {
    INDENT_WIDTH = 2,          -- Standard indentation
    UNDO_LEVELS = 1000,        -- Undo history depth
    COMMAND_HISTORY = 10000,   -- Command history size
  },

  -- File handling patterns
  FILE_PATTERNS = {
    CODE_EXTENSIONS = { "*.lua", "*.py", "*.js", "*.ts", "*.java", "*.c", "*.cpp", "*.go", "*.rs" },
    LARGE_CONTENT_TYPES = { "json", "yaml", "xml", "markdown", "log" },
    BINARY_EXTENSIONS = { "*.exe", "*.dll", "*.so", "*.dylib", "*.zip", "*.tar", "*.gz" },
  },

  -- Feature flags for conditional functionality
  FEATURES = {
    ENABLE_ZEN_MODE = true,
    ENABLE_AUTO_TRIM = true,
    ENABLE_CRLF_GUARD = true,
    ENABLE_LARGE_FILE_OPTS = true,
  },
}

-- ======================================================================
-- UTILITY FUNCTIONS
-- ======================================================================

---@class Utils
local utils = {}

---Safe function execution with error handling
---@param fn function Function to execute
---@param context string? Context for error reporting
---@return boolean success, any result
function utils.safe_call(fn, context)
  local ok, result = pcall(fn)
  if not ok then
    local msg = string.format("[NeovimConfig] Error in %s: %s", context or "unknown", result)
    vim.notify(msg, vim.log.levels.WARN)
  end
  return ok, result
end

---Preserve window view during operation
---@param callback function Function to execute with preserved view
---@return function Wrapped function
function utils.with_preserved_view(callback)
  return function(...)
    local view = api.fn.winsaveview()
    local ok, result = utils.safe_call(function(...) return callback(...) end, "view preservation")
    if view then
      utils.safe_call(function() api.fn.winrestview(view) end, "view restoration")
    end
    return ok and result
  end
end

---Debounce function execution
---@param fn function Function to debounce
---@param delay number Delay in milliseconds
---@return function Debounced function
function utils.debounce(fn, delay)
  local timer = nil
  return function(...)
    local args = {...}
    if timer then
      timer:stop()
      timer:close()
    end
    timer = vim.loop.new_timer()
    timer:start(delay, 0, function()
      timer:stop()
      timer:close()
      timer = nil
      api.schedule(function() fn(unpack(args)) end)
    end)
  end
end

---Check if buffer is modifiable and appropriate for operations
---@param bufnr number? Buffer number (default: current)
---@return boolean
function utils.is_buffer_editable(bufnr)
  bufnr = bufnr or 0
  local ok, result = pcall(function()
    return api.api.nvim_buf_is_valid(bufnr)
      and api.api.nvim_buf_get_option(bufnr, 'modifiable')
      and api.api.nvim_buf_get_option(bufnr, 'buftype') == ""
  end)
  return ok and result
end

-- ======================================================================
-- CORE MODULES
-- ======================================================================

---@class CoreSettings
M.core_settings = {}

---Initialize core Neovim settings
function M.core_settings.setup()
  -- Performance optimizations
  api.o.mouse = ""                      -- Disable mouse for performance
  api.o.updatetime = CONFIG.PERFORMANCE.UPDATETIME
  api.o.lazyredraw = true              -- Reduce unnecessary redraws
  api.o.ttyfast = true                 -- Fast terminal connection
  api.o.synmaxcol = CONFIG.PERFORMANCE.SYNMAXCOL
  api.o.redrawtime = CONFIG.PERFORMANCE.REDRAWTIME
  api.o.maxmempattern = CONFIG.PERFORMANCE.MAXMEMPATTERN
  api.o.timeoutlen = CONFIG.PERFORMANCE.TIMEOUTLEN
  api.o.ttimeoutlen = CONFIG.PERFORMANCE.TTIMEOUTLEN

  -- Disable features that can cause performance issues
  api.o.shadafile = "NONE"             -- Defer persistent state operations
  api.o.keymodel = ""                  -- Disable legacy key model

  -- UI enhancements
  api.o.number = true                   -- Absolute line numbers
  api.wo.relativenumber = true          -- Relative line numbers
  api.o.scrolloff = CONFIG.INTERFACE.SCROLLOFF
  api.o.sidescrolloff = CONFIG.INTERFACE.SIDESCROLLOFF
  api.wo.wrap = false                   -- No line wrapping
  api.wo.linebreak = false              -- No soft line breaks
  api.wo.signcolumn = CONFIG.INTERFACE.SIGN_COLUMN
  api.o.cmdheight = CONFIG.INTERFACE.CMDHEIGHT
  api.o.showmode = false                -- Disable mode display (handled by statusline)

  -- File handling
  api.o.undofile = true                 -- Persistent undo
  api.o.swapfile = false               -- Disable swap files
  api.o.backup = false                 -- Disable backup files
  api.o.writebackup = false            -- Disable write backup

  -- Indentation
  api.o.expandtab = true               -- Use spaces instead of tabs
  api.o.shiftwidth = CONFIG.EDITING.INDENT_WIDTH
  api.o.tabstop = CONFIG.EDITING.INDENT_WIDTH
  api.o.softtabstop = CONFIG.EDITING.INDENT_WIDTH
  api.o.smartindent = true             -- Smart auto-indentation
  api.o.autoindent = true              -- Copy indent from current line

  -- Search behavior
  api.o.ignorecase = true              -- Case-insensitive search
  api.o.smartcase = true               -- Case-sensitive if uppercase present
  api.o.hlsearch = true                -- Highlight search matches
  api.o.incsearch = true               -- Incremental search

  -- Window behavior
  api.o.splitright = true              -- Vertical splits to the right
  api.o.splitbelow = true              -- Horizontal splits below
  api.o.completeopt = "menuone,noinsert,noselect"

  -- History and undo
  api.o.history = CONFIG.EDITING.COMMAND_HISTORY
  api.o.undolevels = CONFIG.EDITING.UNDO_LEVELS

  -- File format enforcement
  api.opt.fileformats = { "unix" }
  api.opt.fileformat = "unix"
end

---@class KeyboardManager
M.keyboard = {}

---Initialize keyboard mappings and behavior
function M.keyboard.setup()
  -- Disable arrow keys for vim discipline
  local arrow_keys = { "<Up>", "<Down>", "<Left>", "<Right>" }
  local modes = { "n", "v", "i" }

  for _, mode in ipairs(modes) do
    for _, key in ipairs(arrow_keys) do
      api.keymap.set(mode, key, "<Nop>", {
        desc = "Arrow key disabled - use hjkl",
        silent = true
      })
    end
  end

  -- Enhanced ESC behavior - clear search highlighting
  api.keymap.set("n", "<Esc>", function()
    if vim.v.hlsearch == 1 then
      api.cmd("nohlsearch")
    end
    return "<Esc>"
  end, {
    expr = true,
    silent = true,
    desc = "Clear search highlight on Esc"
  })

  -- Quick save with Ctrl+S
  api.keymap.set({"n", "i", "v"}, "<C-s>", function()
    if utils.is_buffer_editable() then
      api.cmd("silent! write")
      vim.notify("Buffer saved", vim.log.levels.INFO)
    end
  end, {
    desc = "Save buffer",
    silent = true
  })
end

---@class FileManager
M.file_manager = {}

---Initialize file management features
function M.file_manager.setup()
  -- Whitespace trimming for code files
  if CONFIG.FEATURES.ENABLE_AUTO_TRIM then
    local trim_group = api.api.nvim_create_augroup("AutoTrimWhitespace", { clear = true })

    api.api.nvim_create_autocmd("BufWritePre", {
      group = trim_group,
      pattern = CONFIG.FILE_PATTERNS.CODE_EXTENSIONS,
      callback = utils.with_preserved_view(function()
        if not utils.is_buffer_editable() then return end

        -- Remove trailing whitespace
        api.cmd("silent! keepjumps %s/\\s\\+$//e")

        -- Remove trailing empty lines
        api.cmd("silent! keepjumps %s/\\n\\+\\%$//e")
      end),
      desc = "Trim whitespace on save"
    })
  end

  -- CRLF to LF conversion
  if CONFIG.FEATURES.ENABLE_CRLF_GUARD then
    local crlf_group = api.api.nvim_create_augroup("CRLFGuard", { clear = true })

    ---Efficiently strip carriage returns
    local function strip_crlf()
      if not utils.is_buffer_editable() then return end

      -- Quick check if CR characters exist
      if api.fn.search('\r', 'nw') == 0 then return end

      local lines = api.api.nvim_buf_get_lines(0, 0, -1, false)
      local modified = false

      for i, line in ipairs(lines) do
        if line:find('\r') then
          lines[i] = line:gsub('\r', '')
          modified = true
        end
      end

      if modified then
        api.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        api.bo.fileformat = "unix"
      end
    end

    api.api.nvim_create_autocmd({ "BufReadPost", "FileChangedShellPost" }, {
      group = crlf_group,
      pattern = "*",
      callback = utils.with_preserved_view(strip_crlf),
      desc = "Convert CRLF to LF on file read"
    })

    api.api.nvim_create_autocmd("BufWritePre", {
      group = crlf_group,
      pattern = "*",
      callback = strip_crlf,
      desc = "Convert CRLF to LF before write"
    })
  end

  -- Large file optimizations
  if CONFIG.FEATURES.ENABLE_LARGE_FILE_OPTS then
    local large_file_group = api.api.nvim_create_augroup("LargeFileOptimization", { clear = true })

    -- Check file size before reading
    api.api.nvim_create_autocmd("BufReadPre", {
      group = large_file_group,
      pattern = "*",
      callback = function(args)
        local file_path = args.file
        if not file_path or file_path == "" then return end

        local file_size = api.fn.getfsize(file_path)
        if file_size < 0 then return end -- File doesn't exist or error

        local is_large = file_size > 1024 * 1024 -- 1MB threshold

        if is_large then
          -- Disable expensive features for large files
          api.opt_local.foldmethod = "manual"
          api.opt_local.synmaxcol = 80
          api.opt_local.undofile = false
          api.opt_local.swapfile = false

          vim.notify(string.format("Large file detected (%.1f MB) - optimizations applied",
                    file_size / (1024 * 1024)), vim.log.levels.INFO)
        end
      end,
      desc = "Optimize settings for large files (pre-read)"
    })

    -- Additional check after reading for line count
    api.api.nvim_create_autocmd("BufReadPost", {
      group = large_file_group,
      pattern = "*",
      callback = function()
        local line_count = api.fn.line("$")
        if line_count and line_count > CONFIG.PERFORMANCE.LARGE_FILE_THRESHOLD then
          api.opt_local.foldmethod = "manual"
          api.opt_local.synmaxcol = 80

          vim.notify(string.format("Large file detected (%d lines) - additional optimizations applied",
                    line_count), vim.log.levels.INFO)
        end
      end,
      desc = "Optimize settings for large files (post-read)"
    })
  end
end

---@class StatusLine
M.statusline = {}

---Initialize statusline functionality
function M.statusline.setup()
  -- Mode mapping for statusline
  local mode_map = {
    ["n"]  = "NORMAL",    ["no"] = "N·OP",      ["nov"] = "N·OP",
    ["i"]  = "INSERT",    ["ic"] = "INS·COMP",  ["ix"] = "INS·X",
    ["v"]  = "VISUAL",    ["V"]  = "V·LINE",    [""] = "V·BLOCK",
    ["c"]  = "COMMAND",   ["cv"] = "VIM·EX",    ["ce"] = "EX",
    ["r"]  = "REPLACE",   ["R"]  = "REPLACE",   ["Rx"] = "REPL·X",
    ["s"]  = "SELECT",    ["S"]  = "S·LINE",    [""] = "S·BLOCK",
    ["t"]  = "TERMINAL",
  }

  ---Get current mode string
  ---@return string
  _G.get_mode = function()
    local mode = api.api.nvim_get_mode().mode
    return mode_map[mode] or string.format("MODE(%s)", vim.fn.escape(mode, ' '))
  end

  ---Get search count information
  ---@return string
  _G.get_search_info = function()
    if vim.v.hlsearch == 0 then return "" end

    local ok, search_count = pcall(api.fn.searchcount, {
      maxcount = 999,
      timeout = 50
    })

    if ok and search_count and search_count.total and search_count.total > 0 then
      local current = search_count.current or 0
      return string.format(" [%d/%d]", current, search_count.total)
    end

    return ""
  end

  ---Get buffer modification indicator
  ---@return string
  _G.get_buffer_status = function()
    local ok, modified = pcall(function() return api.bo.modified end)
    local modified_indicator = (ok and modified) and "●" or ""

    local ok2, readonly = pcall(function() return api.bo.readonly end)
    local readonly_indicator = (ok2 and readonly) and "" or ""

    return modified_indicator .. readonly_indicator
  end

  -- Configure statusline
  api.o.statusline = table.concat({
    " %{v:lua.get_mode()} │",           -- Mode
    " %f ",                            -- File path
    "%{v:lua.get_buffer_status()}",    -- Buffer status
    "%=",                              -- Right align
    "Ln %l/%L, Col %c",               -- Position
    "%{v:lua.get_search_info()}",     -- Search info
    " %P ",                           -- Percentage
  })
end

---@class ZenMode
M.zen_mode = {
  active = false,
  saved_state = {},
  _busy = false,
}

---Initialize zen mode functionality
function M.zen_mode.setup()
  if not CONFIG.FEATURES.ENABLE_ZEN_MODE then return end

  local zen_config = {
    number = false,
    relativenumber = false,
    signcolumn = "no",
    laststatus = 0,
    cmdheight = 0,
    showtabline = 0,
    syntax = false,
  }

  ---Apply settings to all windows
  ---@param settings table
  local function apply_settings(settings)
    -- Global settings
    if settings.laststatus ~= nil then api.o.laststatus = settings.laststatus end
    if settings.cmdheight ~= nil then api.o.cmdheight = settings.cmdheight end
    if settings.showtabline ~= nil then api.o.showtabline = settings.showtabline end
    if settings.syntax ~= nil then
      api.cmd(settings.syntax and "syntax on" or "syntax off")
    end

    -- Window-local settings
    for _, win in ipairs(api.api.nvim_list_wins()) do
      if api.api.nvim_win_is_valid(win) then
        utils.safe_call(function()
          api.api.nvim_win_call(win, function()
            if settings.number ~= nil then api.wo.number = settings.number end
            if settings.relativenumber ~= nil then api.wo.relativenumber = settings.relativenumber end
            if settings.signcolumn ~= nil then api.wo.signcolumn = settings.signcolumn end
          end)
        end, "zen mode window settings")
      end
    end
  end

  ---Toggle zen mode with debouncing
  local function toggle_zen_mode()
    if M.zen_mode._busy then return end
    M.zen_mode._busy = true

    api.schedule(function()
      M.zen_mode._busy = false
    end)

    M.zen_mode.active = not M.zen_mode.active

    if M.zen_mode.active then
      -- Save current state
      M.zen_mode.saved_state = {
        number = api.wo.number,
        relativenumber = api.wo.relativenumber,
        signcolumn = api.wo.signcolumn,
        laststatus = api.o.laststatus,
        cmdheight = api.o.cmdheight,
        showtabline = api.o.showtabline,
        syntax = pcall(function() return vim.bo.syntax ~= "off" end) and vim.bo.syntax ~= "off" or true,
      }

      apply_settings(zen_config)
      vim.notify("Zen mode enabled", vim.log.levels.INFO)
    else
      apply_settings(M.zen_mode.saved_state)
      vim.notify("Zen mode disabled", vim.log.levels.INFO)
    end
  end

  -- Keymap for zen mode toggle
  api.keymap.set("n", "<Space><Space>", utils.debounce(toggle_zen_mode, 200), {
    desc = "Toggle zen mode",
    silent = true
  })

  -- Maintain zen mode settings for new windows
  local zen_group = api.api.nvim_create_augroup("ZenModeAuto", { clear = true })

  api.api.nvim_create_autocmd({"WinNew", "WinEnter"}, {
    group = zen_group,
    callback = function()
      if M.zen_mode.active then
        utils.safe_call(function()
          api.wo.number = zen_config.number
          api.wo.relativenumber = zen_config.relativenumber
          api.wo.signcolumn = zen_config.signcolumn
        end, "zen mode new window")
      end
    end,
    desc = "Apply zen settings to new windows"
  })
end

---@class LateInit
M.late_init = {}

---Initialize features that can be deferred
function M.late_init.setup()
  api.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      api.defer_fn(function()
        -- Configure persistent state
        api.o.shadafile = ""
        api.o.shada = "!,'100,<50,s10,h"

        local shada_path = api.fn.stdpath("data") .. "/shada/main.shada"
        if api.fn.filereadable(shada_path) == 1 then
          utils.safe_call(function()
            api.cmd("silent! rshada")
          end, "shada restoration")
        end

        -- Enable system clipboard
        utils.safe_call(function()
          api.o.clipboard = "unnamedplus"
        end, "clipboard setup")

        vim.notify("Neovim configuration loaded successfully", vim.log.levels.INFO)
      end, 100)
    end,
    desc = "Late initialization tasks"
  })
end

-- ======================================================================
-- MAIN SETUP FUNCTION
-- ======================================================================

---Initialize the entire configuration
---@return table Module instance
function M.setup()
  if M._initialized then
    vim.notify("Configuration already initialized", vim.log.levels.WARN)
    return M
  end

  -- Initialize modules in dependency order
  local setup_order = {
    { "core_settings", "Core settings" },
    { "keyboard", "Keyboard mappings" },
    { "file_manager", "File management" },
    { "statusline", "Status line" },
    { "zen_mode", "Zen mode" },
    { "late_init", "Late initialization" },
  }

  for _, module_info in ipairs(setup_order) do
    local module_name, description = module_info[1], module_info[2]
    local module = M[module_name]

    if module and type(module.setup) == "function" then
      local ok = utils.safe_call(module.setup, description)
      if not ok then
        vim.notify(string.format("Failed to initialize %s", description), vim.log.levels.ERROR)
      end
    end
  end

  M._initialized = true
  return M
end

-- ======================================================================
-- MODULE EXPORT
-- ======================================================================

return M.setup()
