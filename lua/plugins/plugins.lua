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
      picker = {
        -- Core performance settings
        performance = {
          async_loading = true, -- Non-blocking loading
          cache = {
            enabled = true,     -- Enable caching
            max_entries = 100,  -- Optimal for most users
            ttl = 3600,         -- 1 hour cache expiration
            eviction_policy = "LRU",
          },
          debounce = 100, -- Faster than default 150ms
          throttle = 50   -- Render interval in ms
        },
        -- Render optimizations
        layout = {
          width = 0.85,        -- Optimal screen coverage
          height = 0.75,
          preview_cutoff = 50, -- Disable preview for large results
          horizontal = {       -- Better performance than vertical
            mirror = false,
            preview_width = 0.45
          },
          vertical = {
            mirror = false,
            preview_height = 0.35,
          },
        },
        features = {
          animations = false,       -- Biggest performance gain
          image_previews = false,
          nutritional_info = false, -- Changed from calorie_counter
          social_sharing = false
        },
      },
    },
    event = "VeryLazy"
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
