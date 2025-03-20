-- plugins.lua

-- ============================================================================
-- PERFORMANCE OPTIMIZATION HELPERS
-- ============================================================================

-- Common performance settings shared across plugins
local function get_performance_settings()
  return {
    logging = {
      level = vim.log.levels.OFF  -- Disable logging for better performance
    },
  }
end

local perf = get_performance_settings()

-- ============================================================================
-- PLUGIN CONFIGURATIONS
-- ============================================================================

return {
  -- ----------------------------------------------------------------------------
  -- LSP Configuration
  -- ----------------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    description = "Core LSP client configuration",
    opts = {
      -- Disable inlay hints to reduce visual noise and improve performance
      inlay_hints = {
        enabled = false,
      },
    },
  },

  -- ----------------------------------------------------------------------------
  -- UI Enhancement
  -- ----------------------------------------------------------------------------
  {
    "folke/snacks.nvim",
    description = "UI picker with performance optimizations",
    opts = {
      -- Disable smooth scrolling to reduce animation overhead
      scroll = {
        enabled = false,
      },
      picker = {
        -- Core performance settings
        performance = {
          async_loading = true,  -- Use non-blocking loading
          cache = {
            enabled = true,      -- Enable result caching
            max_entries = 100,   -- Balance between memory usage and cache hits
            ttl = 3600,          -- Cache lifetime (1 hour)
            eviction_policy = "LRU",  -- Least Recently Used eviction
          },
          debounce = 100,  -- Reduce input processing frequency (ms)
          throttle = 50     -- Limit render frequency (ms)
        },
        -- UI layout optimizations
        layout = {
          width = 0.85,         -- Optimal screen coverage
          height = 0.75,        -- Optimal screen coverage
          preview_cutoff = 50,  -- Disable preview for large results
        },
        -- Disable unnecessary features
        features = {
          animations = false,     -- Disable animations for performance
          image_previews = false, -- Disable image previews
        },
      },
    },
  },

  -- ----------------------------------------------------------------------------
  -- Development Tools
  -- ----------------------------------------------------------------------------
  {
    "williamboman/mason.nvim",
    description = "Tool installer with optimized package management",
    cmd = "Mason",  -- Only load when the Mason command is explicitly used
    log_level = perf.logging.level,
    opts = function(_, opts)
      -- Exclude packages that might be provided by other means or not needed
      local exclude_pkgs = {
        ["lua-language-server"] = true,
        ["shfmt"] = true,
        ["stylua"] = true,
      }

      -- Filter out excluded packages from auto-installation
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

  -- ----------------------------------------------------------------------------
  -- Notification System
  -- ----------------------------------------------------------------------------
  {
    "folke/noice.nvim",
    description = "Enhanced UI with focused optimizations for notifications",
    opts = {
      -- Optimize LSP-related UI elements
      lsp = {
        progress = { enabled = false },  -- Disable LSP progress UI
        signature = { enabled = false }, -- Disable signature help popups
        message = { enabled = false },   -- Disable LSP messages
      },
      -- Minimize notification visual impact
      messages = {
        view = "mini",
        view_error = "mini",
        view_warn = "mini",
        view_history = "mini",
        view_search = "virtualtext",
      },
      throttle = 100, -- Limit UI update frequency
    },
  },

  -- ----------------------------------------------------------------------------
  -- Syntax and Parsing
  -- ----------------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter",
    description = "Syntax parsing with performance optimizations",
    opts = {
      -- Disable indentation for performance
      indent = { enable = false },
    },
  },

  -- ----------------------------------------------------------------------------
  -- Code Formatting
  -- ----------------------------------------------------------------------------
  {
    "stevearc/conform.nvim",
    description = "Code formatter with minimized overhead",
    log_level = perf.logging.level,
  },
}
