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
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      local exclude_pkgs = {
        ["lua-language-server"] = true,
        ["shfmt"] = true,
        ["stylua"] = true,
      }

      -- Ensure `opts.ensure_installed` is valid before applying the filter
      if opts.ensure_installed and type(opts.ensure_installed) == "table" then
        local filtered = {}
        for _, pkg in ipairs(opts.ensure_installed) do
          if not exclude_pkgs[pkg] then
            table.insert(filtered, pkg)
          end
        end
        opts.ensure_installed = filtered
      end
    end,
  },
}
