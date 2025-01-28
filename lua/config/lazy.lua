local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

local concurrency = vim.uv.available_parallelism() -- Default to available parallelism
if jit.os == "Windows" then
  concurrency = math.min(concurrency * 2, 16) -- Cap concurrency on Windows
end

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = true,  -- Lazy load all plugins by default
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  plugins = {
    -- Load only when a file is opened
    { "nvim-treesitter/nvim-treesitter", event = "LazyFile" },
    { "nvim-treesitter/nvim-treesitter-textobjects", event = "LazyFile" },
    { "folke/trouble.nvim", event = "LazyFile" },
    { "folke/flash.nvim", event = "LazyFile" },
    { "folke/ts-comments.nvim", event = "LazyFile" },
    { "akinsho/bufferline.nvim", event = "LazyFile" },
    { "echasnovski/mini.ai", event = "LazyFile" },
    { "echasnovski/mini.pairs", event = "LazyFile" },
    -- Load after all plugins are loaded
    { "folke/tokyonight.nvim", event = "VeryLazy" },
    { "MunifTanjim/nui.nvim", event = "VeryLazy" },
    { "folke/snacks.nvim", event = "VeryLazy" },
    -- Load only in insert mode
    { "Exafunction/codeium.nvim", event = "InsertEnter" },
    { "nvim-lua/plenary.nvim", event = "InsertEnter" },
    { "hrsh7th/nvim-cmp", event = "InsertEnter" },
    { "rafamadriz/friendly-snippets", event = "InsertEnter" },
    -- Disabled plugins
    { "catppuccin/nvim", enabled = false },
  },
  install = { colorscheme = { "tokyonight" } },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    cache = {
      enabled = true,
      path = vim.fn.stdpath("cache") .. "/lazy/cache",
      clear_cache_on_update = true,
    },
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        -- Heavy plugins you likely don't need
        "gzip",               -- For compressed files
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",          -- For tar file support
        "tohtml",
        "tutor",
        "zipPlugin",          -- For zip file support
        "man",                -- For reading man pages inside Vim
        "shada",              -- Session persistence
      },
    },
    concurrency = concurrency,  -- Add concurrency here
  },
})
