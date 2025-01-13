return {
  { -- Disable inlay hints
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        enabled = false,
      },
    },
  },
  {
    "folke/snacks.nvim",
    --@type snacks.Config
    opts = {
      scroll = {
        enabled = false, -- Disable smooth scrolling
      },
    },
  },
}
