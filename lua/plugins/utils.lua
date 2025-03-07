-- /nvim/lua/plugins/utils.lua
return {
  "nvim-lua/plenary.nvim",
  {
    dir = vim.fn.stdpath("config") .. "/lua/utils",
    name = "utils",
    lazy = true, -- We want this available immediately
    event = "VeryLazy",
    config = function()
      -- Make utils globally available
      _G.Utils = require("utils.utils")

      -- Optional: Set up autocommands to clear caches periodically
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          if _G.Utils and _G.Utils.clear_caches then
            _G.Utils.clear_caches()
          end
        end,
      })
    end,
  }
}
