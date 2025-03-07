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
