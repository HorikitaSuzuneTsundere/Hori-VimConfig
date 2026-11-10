-- === Neovim 0.12+ configuration ===
vim.loader.enable()

local api, fn = vim.api, vim.fn
local autocmd = api.nvim_create_autocmd
local function augroup(name) return api.nvim_create_augroup(name, { clear = true }) end

-- Functions that statusline/tabline call through v:lua live in one global table.
local M = {}
_G.Cfg = M

-- === Built-in plugins and providers ===
for _, name in ipairs({ "matchparen", "matchit", "gzip", "tar", "tarPlugin",
                        "zip", "zipPlugin", "tutor_mode_plugin" }) do
  vim.g["loaded_" .. name] = 1
end
for _, name in ipairs({ "python3", "node", "perl", "ruby" }) do
  vim.g["loaded_" .. name .. "_provider"] = 0
end

-- === Options (only values that differ from Neovim's defaults) ===
local o = vim.opt
-- Performance
o.mouse         = ""
o.updatetime    = 250
o.synmaxcol     = 200
o.redrawtime    = 1000
o.maxmempattern = 2000
-- UI
o.number        = true
o.scrolloff     = 10
o.sidescrolloff = 8
o.showmode      = false        -- the statusline shows the mode instead
o.cmdheight     = 0
o.signcolumn    = "yes:1"
o.wrap          = false
o.pumheight     = 10
o.splitkeep     = "screen"
o.splitright    = true
o.splitbelow    = true
o.termguicolors = true
o.jumpoptions   = "stack"
-- Files. writebackup stays on (the default) so a failed write can't lose the file.
o.modeline      = false
o.undofile      = true
o.swapfile      = false
o.fileformats   = "unix,dos,mac"
o.history       = 2000
-- Timing
o.timeoutlen    = 300
o.ttimeoutlen   = 40
-- Indentation
o.expandtab     = true
o.shiftwidth    = 2
o.tabstop       = 2
o.softtabstop   = 2
o.smartindent   = true
-- Search
o.ignorecase    = true
o.smartcase     = true
-- Completion, messages, clipboard
o.completeopt   = { "menuone", "noinsert", "noselect" }
o.shortmess:append("sI")
o.clipboard     = "unnamedplus" -- the provider loads lazily on first use

-- LSP logging off. Waiting for the first client avoids loading vim.lsp at startup.
autocmd("LspAttach", {
  group = augroup("LspLogOff"),
  once = true,
  callback = function() vim.lsp.log.set_level("OFF") end,
})

-- === Highlights ===
local tab_hl = {
  dark = {
    TabLine     = { fg = "#808080", bg = "#1e1e1e" },
    TabLineSel  = { fg = "#ffffff", bg = "#3a3a3a", bold = true },
    TabLineFill = { bg = "#1e1e1e" },
  },
  light = {
    TabLine     = { fg = "#555555", bg = "#d4d4d4" },
    TabLineSel  = { fg = "#000000", bg = "#ffffff", bold = true },
    TabLineFill = { bg = "#d4d4d4" },
  },
}
local ZEN_STATUSLINE_HL = { fg = "#4F5258" }

M.zen_active = false

local function apply_highlights()
  for name, spec in pairs(tab_hl[vim.o.background] or tab_hl.dark) do
    api.nvim_set_hl(0, name, spec)
  end
  if M.zen_active then api.nvim_set_hl(0, "StatusLine", ZEN_STATUSLINE_HL) end
end
apply_highlights()

local hl_group = augroup("CustomHighlights")
autocmd("ColorScheme", { group = hl_group, callback = apply_highlights })
-- Changing 'background' (including terminal auto-detection) fires OptionSet, not ColorScheme.
autocmd("OptionSet", { group = hl_group, pattern = "background", callback = apply_highlights })

-- === Per-filetype tweaks ===
-- Large files of these types: shorter syntax column limit. Prose: soft wrapping.
local prose      = { markdown = true, text = true, plaintex = true }
local structured = { json = true, yaml = true, toml = true, html = true,
                     css = true, scss = true, xml = true,
                     markdown = true, text = true, plaintex = true }

-- 'wrap' is window-local and a :setlocal value carries over to the next buffer
-- shown in the window, so re-derive it whenever a buffer enters a normal window.
-- Only these three options are touched; floats and special buffers are left alone.
local function apply_wrap(win)
  if api.nvim_win_get_config(win).relative ~= "" then return end
  local buf = api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" then return end
  local on = prose[vim.bo[buf].filetype] or false
  for _, name in ipairs({ "wrap", "linebreak", "breakindent" }) do
    local value = on or api.nvim_get_option_value(name, { scope = "global" })
    api.nvim_set_option_value(name, value, { win = win, scope = "local" })
  end
end

local ft_group = augroup("FileTypeTweaks")
autocmd("FileType", {
  group = ft_group,
  callback = function(args)
    if structured[args.match] and api.nvim_buf_line_count(args.buf) > 1000 then
      vim.bo[args.buf].synmaxcol = 120
    end
    local win = api.nvim_get_current_win()
    if api.nvim_win_get_buf(win) == args.buf then apply_wrap(win) end
  end,
})
autocmd("BufWinEnter", {
  group = ft_group,
  callback = function() apply_wrap(api.nvim_get_current_win()) end,
})

-- === Keymaps ===
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  vim.keymap.set({ "n", "v", "i", "o" }, key, "<Nop>", { desc = "Arrow disabled" })
end
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
vim.keymap.set("i", "<Esc>", "<Esc><cmd>nohlsearch<CR>", { desc = "Leave insert, clear highlight" })

-- === Trim trailing whitespace and expand leading tabs on save ===
-- Only leading tabs are expanded (to the real tab stop), never tabs inside a line,
-- and not in filetypes where leading tabs mean something (heredocs, Makefiles).
local keep_tabs = { sh = true, bash = true, zsh = true, make = true }
local MAX_CLEAN_LINES = 50000

local function expand_leading_tabs(line, ts)
  local lead, rest = line:match("^([ \t]*)(.*)$")
  if not lead:find("\t", 1, true) then return line end
  local col = 0
  for ch in lead:gmatch(".") do
    col = (ch == "\t") and (col + ts - col % ts) or (col + 1)
  end
  return string.rep(" ", col) .. rest
end

local function clean_buffer(args)
  local buf = args.buf
  local bo = vim.bo[buf]
  if not bo.modifiable or not bo.modified then return end
  if bo.buftype ~= "" and bo.buftype ~= "acwrite" then return end
  if api.nvim_buf_line_count(buf) > MAX_CLEAN_LINES then return end

  local retab = bo.expandtab and not keep_tabs[bo.filetype]
  local ts = bo.tabstop
  -- Collect each run of consecutive changed lines and write it in one call.
  -- Line counts never change, so the indices stay valid while applying.
  local runs, run = {}, nil
  for i, line in ipairs(api.nvim_buf_get_lines(buf, 0, -1, false)) do
    -- Byte checks first, so untouched lines skip the pattern work entirely.
    local new, last = line, line:byte(-1)
    if last == 32 or last == 9 then        -- spaces/tabs only; leaves a stray \r alone
      new = line:gsub("[ \t]+$", "")
    end
    if retab then
      local first = new:byte(1)
      if first == 32 or first == 9 then new = expand_leading_tabs(new, ts) end
    end
    if new ~= line then
      if not run then
        run = { start = i - 1, lines = {} }
        runs[#runs + 1] = run
      end
      run.lines[#run.lines + 1] = new
    else
      run = nil
    end
  end
  for _, r in ipairs(runs) do
    api.nvim_buf_set_lines(buf, r.start, r.start + #r.lines, false, r.lines)
  end
end

autocmd("BufWritePre", {
  group = augroup("SaveHooks"),
  pattern = { "*.lua", "*.c", "*.h", "*.cpp", "*.hpp", "*.py", "*.js", "*.ts",
              "*.tsx", "*.jsx", "*.java", "*.go", "*.rs", "*.sh", "*.bash",
              "*.toml", "*.yaml", "*.yml" },
  callback = clean_buffer,
})

-- === Statusline ===
local MODES = {
  n = "NORMAL", i = "INSERT", v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
  s = "SELECT", S = "S-LINE", ["\19"] = "S-BLOCK", R = "REPLACE",
  c = "COMMAND", t = "TERMINAL", r = "PROMPT", ["!"] = "SHELL",
}

-- Search count: capped so huge files can't stall a redraw, and memoised on
-- buffer, edit tick, pattern and cursor so repeated redraws cost nothing.
-- Some answers hold for every cursor position until the buffer or pattern
-- changes, and are remembered per buffer + pattern:
--   * no matches at all -> show nothing
--   * counting timed out or was slow (huge file, rare pattern) -> show "?/?"
-- The cap comes from 'maxsearchcount' (0.12+, default 999), which searchcount()
-- uses when no maxcount is passed.
local SEARCH_SLOW_MS = 8
local search_opts = { timeout = 10 }
local search_memo = { key = nil, text = "" }
local search_fixed = { key = nil, text = "" }

local function search_count()
  if vim.v.hlsearch == 0 then return "" end
  local base = table.concat({ api.nvim_get_current_buf(), vim.b.changedtick, fn.getreg("/") }, "\0")
  if base == search_fixed.key then return search_fixed.text end
  local pos = api.nvim_win_get_cursor(0)
  local key = base .. "\0" .. pos[1] .. "\0" .. pos[2]
  if key == search_memo.key then return search_memo.text end

  local t0 = vim.uv.hrtime()
  local ok, s = pcall(fn.searchcount, search_opts)
  local slow = (vim.uv.hrtime() - t0) / 1e6 > SEARCH_SLOW_MS
  local text = ""
  if not ok then
    text = ""
  elseif s.incomplete == 1 then                    -- timed out
    text = " ?/?"
    search_fixed.key, search_fixed.text = base, text
  elseif (s.total or 0) == 0 then                  -- no matches anywhere
    search_fixed.key, search_fixed.text = base, ""
  else
    local max = vim.o.maxsearchcount
    local cur = s.current > max and (">" .. max) or s.current
    local tot = s.total   > max and (">" .. max) or s.total
    text = (" %s/%s"):format(cur, tot)
    if slow then search_fixed.key, search_fixed.text = base, " ?/?" end
  end
  search_memo.key, search_memo.text = key, text
  return text
end

local macro_text = ""

function M.statusline()
  -- Inside %! the current window is the real one, not the one being drawn,
  -- so mode, macro and search count are shown only in the active window.
  local active = vim.g.statusline_winid == api.nvim_get_current_win()
  local mode = ""
  if active then
    local m = api.nvim_get_mode().mode
    mode = " " .. (MODES[m:sub(1, 1)] or m) .. " "
  end
  return table.concat({
    mode, "%t %y%h%m%r", "%=",
    active and macro_text or "",
    "Ln %l/%L, Col %c",
    active and search_count() or "",
    " %P",
  })
end

function M.zen_statusline() return "~" end

vim.o.statusline = "%!v:lua.Cfg.statusline()"

-- One scheduled redraw at a time, so a macro that changes mode thousands of
-- times queues a single redraw instead of one per change.
local redraw_pending = false
local function redraw_status_soon()
  if redraw_pending then return end
  redraw_pending = true
  vim.schedule(function()
    redraw_pending = false
    vim.cmd.redrawstatus()
  end)
end

local sl_group = augroup("StatuslineRefresh")
autocmd("RecordingEnter", {
  group = sl_group,
  callback = function()
    macro_text = " REC @" .. fn.reg_recording() .. " "
    redraw_status_soon()
  end,
})
autocmd("RecordingLeave", {
  group = sl_group,
  callback = function()
    macro_text = ""
    redraw_status_soon()
  end,
})
autocmd("ModeChanged", { group = sl_group, callback = redraw_status_soon })

-- === Tabline ===
function M.tabline()
  local parts, current = {}, api.nvim_get_current_tabpage()
  for i, tp in ipairs(api.nvim_list_tabpages()) do
    parts[#parts + 1] = (tp == current) and "%#TabLineSel#" or "%#TabLine#"
    parts[#parts + 1] = " " .. i .. " "
    if not M.zen_active then
      local buf  = api.nvim_win_get_buf(api.nvim_tabpage_get_win(tp))
      local name = api.nvim_buf_get_name(buf)
      name = (name ~= "") and fn.fnamemodify(name, ":t") or "[No Name]"
      -- '%' in a file name would be read as a statusline item; escape it.
      parts[#parts + 1] = ":" .. name:gsub("%%", "%%%%") .. (vim.bo[buf].modified and "+" or "")
    end
    parts[#parts + 1] = " "
  end
  parts[#parts + 1] = "%#TabLineFill#"
  return table.concat(parts)
end

vim.o.tabline = "%!v:lua.Cfg.tabline()"

-- === Zen mode ===
local ZEN_WIN    = { number = false, signcolumn = "no", cursorline = false,
                     cursorcolumn = false, list = false, spell = false }
local ZEN_GLOBAL = { showcmd = false, laststatus = 0, cmdheight = 0,
                     showmode = false, ruler = false }
local zen_file   = fn.stdpath("state") .. "/zen_mode_state"
local zen_saved

local function save_zen_state()
  fn.mkdir(fn.fnamemodify(zen_file, ":h"), "p")
  pcall(fn.writefile, { vim.json.encode({ active = M.zen_active }) }, zen_file)
end

local function load_zen_state()
  local ok, lines = pcall(fn.readfile, zen_file)
  if not ok or not lines[1] then return false end
  local okj, data = pcall(vim.json.decode, lines[1])
  if okj and type(data) == "table" then return data.active == true end
  return lines[1] == "1"   -- older one-byte format
end

local function set_win_local(win, name, value)
  api.nvim_set_option_value(name, value, { win = win, scope = "local" })
end

local function zen_enter()
  zen_saved = {
    global     = {},
    win_global = {},
    wins       = {},
    syntax     = vim.g.syntax_on ~= nil,
    statusline = vim.o.statusline,
    status_hl  = api.nvim_get_hl(0, { name = "StatusLine", link = false }),
  }
  for name, value in pairs(ZEN_GLOBAL) do
    zen_saved.global[name] = vim.o[name]
    vim.o[name] = value
  end
  -- Global values of window options too, so windows opened during zen match.
  for name, value in pairs(ZEN_WIN) do
    zen_saved.win_global[name] = api.nvim_get_option_value(name, { scope = "global" })
    api.nvim_set_option_value(name, value, { scope = "global" })
  end
  for _, win in ipairs(api.nvim_list_wins()) do
    local saved = {}
    for name, value in pairs(ZEN_WIN) do
      saved[name] = api.nvim_get_option_value(name, { win = win })
      set_win_local(win, name, value)
    end
    zen_saved.wins[win] = saved
  end
  if zen_saved.syntax then vim.cmd("syntax off") end
  M.zen_active = true
  vim.o.statusline = "%!v:lua.Cfg.zen_statusline()"
  api.nvim_set_hl(0, "StatusLine", ZEN_STATUSLINE_HL)
end

local function zen_leave()
  local s = zen_saved
  M.zen_active = false
  for name, value in pairs(s.global) do vim.o[name] = value end
  for name, value in pairs(s.win_global) do
    api.nvim_set_option_value(name, value, { scope = "global" })
  end
  for _, win in ipairs(api.nvim_list_wins()) do
    for name, value in pairs(s.wins[win] or s.win_global) do
      set_win_local(win, name, value)
    end
  end
  if s.syntax then vim.cmd("syntax on") end
  vim.o.statusline = s.statusline
  api.nvim_set_hl(0, "StatusLine", s.status_hl)
  zen_saved = nil
end

local function toggle_zen()
  if M.zen_active then zen_leave() else zen_enter() end
  save_zen_state()   -- saved only on toggle, so a fast quit can't overwrite it
  vim.cmd.redrawtabline()
  vim.cmd.redrawstatus()
end

vim.keymap.set("n", "<Space><Space>", toggle_zen, { desc = "Toggle zen mode" })

autocmd("VimEnter", {
  group = augroup("ZenRestore"),
  once = true,
  callback = function()
    if load_zen_state() then zen_enter() end
  end,
})
