local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

local concurrency = math.min(vim.uv.available_parallelism() * 2, 16)

require("lazy").setup({
  debug = false, -- Disable Lazy.nvim debug logs
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = true, -- Lazy load all plugins by default
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  plugins = {
    -- Specific events per plugin
    { "nvim-treesitter/nvim-treesitter",             event = "BufReadPre" },
    { "folke/trouble.nvim",                          cmd = "TroubleToggle" },
    { "folke/flash.nvim",                            keys = { "s", "S", "f", "F", "t", "T" } },
    { "folke/ts-comments.nvim",                      keys = { "gc", "gb" } },
    { "echasnovski/mini.ai",                         event = "ModeChanged" },
    { "echasnovski/mini.pairs",                      event = "InsertEnter" },
    { "nvim-treesitter/nvim-treesitter-textobjects", after = "nvim-treesitter" },
    { "akinsho/bufferline.nvim",                     event = "BufAdd" },
    { "folke/tokyonight.nvim",                       event = "VimEnter" },
    { "folke/snacks.nvim",                           event = "VeryLazy" },
    { "Exafunction/codeium.nvim",                    event = "InsertEnter" },
    { "hrsh7th/nvim-cmp",                            event = "InsertEnter" },
    { "rafamadriz/friendly-snippets",                after = "nvim-cmp" },
    -- Disabled plugins
    { "catppuccin/nvim",                             enabled = false },
  },
  install = { colorscheme = { "tokyonight" } },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
    frequency = 3600, -- Check for updates every hour instead of default 15 mins
  },                -- automatically check for plugin updates
  performance = {
    cache = {
      enabled = true,
      path = vim.fn.stdpath("cache") .. "/lazy/cache",
      clear_cache_on_update = false, -- Avoid clearing cache unless necessary
    },
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        -- Heavy plugins you likely don't need
        "gzip", -- For compressed files
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin", -- For tar file support
        "tohtml",
        "tutor",
        "zipPlugin", -- For zip file support
        "man",       -- For reading man pages inside Vim
        "shada",     -- Session persistence
        -- More plugins to disable
        "spellfile_plugin", -- Spell checking
        "logiPat",          -- Legacy pattern matching
        "rrhelper",         -- Rarely used remote debugging helper
      },
    },
    concurrency = concurrency, -- Add concurrency here
  },
})
