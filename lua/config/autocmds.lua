-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Automatically remove trailing whitespace and extra blank lines
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  command = [[%s/\s\+$//e | %s/\n\+\%$//e]],
})

-- Toggle relative line numbers in normal mode and disable them in insert mode
vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
  pattern = "*",
  callback = function()
    if vim.fn.mode() == "i" then
      vim.opt.relativenumber = false
    else
      vim.opt.relativenumber = true
    end
  end,
})

-- Disable auto-commenting on a new line
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    vim.opt.formatoptions:remove("c")
    vim.opt.formatoptions:remove("r")
    vim.opt.formatoptions:remove("o")
  end,
})

-- Enforce Unix file format on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    vim.opt_local.fileformat = "unix"
  end,
})
