-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Create a namespace for our autocmds for better debugging
local ns = vim.api.nvim_create_namespace("custom_autocmds")

-- Group autocmds for better organization and to prevent duplicates
local augroup = vim.api.nvim_create_augroup("CustomAutocmds", { clear = true })

-- Cache settings to avoid repeated lookups
local settings = {
  date_pattern = "%[(%d%d%d%d%-%d%d%-%d%d)%]",
  date_line = 5,  -- Human readable line number (will be adjusted for 0-indexing)
  eob_char = " ", -- Character to use for end-of-buffer
}

-- Helper functions for better maintainability and reuse
local helpers = {
  -- Clean up document: remove trailing whitespace and extra blank lines
  clean_document = function(bufnr)
    -- Use Lua string operations instead of vim.cmd when possible
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local modified = false

    for i, line in ipairs(lines) do
      -- Remove trailing whitespace
      local trimmed = line:gsub("%s+$", "")
      if trimmed ~= line then
        lines[i] = trimmed
        modified = true
      end
    end

    -- Remove extra blank lines at end of file
    while #lines > 1 and lines[#lines] == "" and lines[#lines-1] == "" do
      table.remove(lines)
      modified = true
    end

    -- Only update buffer if changes were made
    if modified then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end

    return modified
  end,

  -- Update date stamp in specified format
  update_date = function(bufnr)
    local line_idx = settings.date_line - 1  -- Convert to 0-indexed
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    -- Skip if file doesn't have enough lines
    if line_count <= line_idx then
      return false
    end

    -- Get the target line
    local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]
    if not line then
      return false
    end

    -- Parse the date using pattern matching
    local start_pos, end_pos, date = line:find(settings.date_pattern)
    if not start_pos then
      return false
    end

    -- Get current date
    local current_date = os.date("%Y-%m-%d")

    -- Only update if date has changed
    if date == current_date then
      return false
    end

    -- Create updated line
    local new_line = line:sub(1, start_pos - 1) .. "[" .. current_date .. "]" .. line:sub(end_pos + 1)

    -- Update the line
    vim.api.nvim_buf_set_lines(bufnr, line_idx, line_idx + 1, false, { new_line })
    return true
  end,

  -- Ensure Unix file format
  ensure_unix_format = function(bufnr)
    local current_ff = vim.api.nvim_buf_get_option(bufnr, "fileformat")
    if current_ff ~= "unix" then
      vim.api.nvim_buf_set_option(bufnr, "fileformat", "unix")
      return true
    end
    return false
  end
}

-- Create efficient BufWritePre autocmd
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = "*",
  desc = "Format file and update metadata on save",
  callback = function(args)
    local bufnr = args.buf
    local buffer_filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

    -- Skip binary files and certain file types
    local skip_filetypes = { "binary", "diff", "help" }
    for _, ft in ipairs(skip_filetypes) do
      if buffer_filetype == ft then
        return
      end
    end

    -- Apply all transformations, tracking what changed for debugging
    local changes = {
      cleaned = helpers.clean_document(bufnr),
      date_updated = helpers.update_date(bufnr),
      format_updated = helpers.ensure_unix_format(bufnr)
    }

    -- Set fillchars option globally once
    vim.opt.fillchars = { eob = settings.eob_char }

    -- Debug logging if enabled
    if vim.g.custom_autocmd_debug then
      vim.api.nvim_echo({
        {"CustomAutocmds: ", "Normal"},
        {vim.inspect(changes), "Comment"}
      }, false, {})
    end
  end,
})

-- Register command to toggle debug mode
vim.api.nvim_create_user_command("AutocmdDebug", function()
  vim.g.custom_autocmd_debug = not vim.g.custom_autocmd_debug
  vim.notify("Autocmd debugging " .. (vim.g.custom_autocmd_debug and "enabled" or "disabled"))
end, { desc = "Toggle autocmd debug logging" })

-- Allow configuration through global variable
vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup,
  callback = function()
    -- Apply custom settings from user config if available
    if vim.g.custom_autocmd_settings then
      for k, v in pairs(vim.g.custom_autocmd_settings) do
        settings[k] = v
      end
    end
  end,
  once = true
})
