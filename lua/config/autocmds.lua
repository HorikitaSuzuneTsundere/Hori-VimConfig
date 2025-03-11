-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Automatically remove trailing whitespace and extra blank lines
-- Enforce Unix file format on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    -- Combine both BufWritePre operations
    vim.cmd([[%s/\s\+$//e | %s/\n\+\%$//e]])
    vim.opt_local.fileformat = "unix"
    vim.opt.fillchars = { eob = " " } -- Removes ~ from empty lines
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    callback = function()
        local buf = 0
        local current_date = os.date("%Y-%m-%d")

        -- Read line 5 efficiently
        local line = vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1]
        if not line then return end

        -- Locate `[YYYY-MM-DD]`
        local start_idx, end_idx = line:find("%[%d%d%d%d%-%d%d%-%d%d%]")
        if not start_idx then return end

        -- Replace date while preserving brackets
        local new_line = line:sub(1, start_idx) .. current_date .. line:sub(end_idx)
        if new_line == line then return end

        -- Update only if necessary
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { new_line })
    end,
})
