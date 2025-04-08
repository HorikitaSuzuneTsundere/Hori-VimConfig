# VimHardMode: The Ultimate Neovim Training Configuration

![Vim Logo](https://raw.githubusercontent.com/neovim/neovim.github.io/master/logos/neovim-logo-300x87.png)

## 🎯 Purpose

Welcome to VimHardMode - a Neovim configuration designed to transform you into a Vim ninja by enforcing strict keyboard-only workflows and best practices. This configuration intentionally disables common "crutches" to help you master Vim's powerful native features.

## 🚫 Key Features

### Disabled Distractions
- **No Arrow Keys**: Force yourself to use `hjkl` for navigation
- **No Mouse Support**: Pure keyboard-driven workflow
- **No Function Keys**: Learn the proper Vim commands instead
- **No Numpad**: Embrace the home row
- **No Common Shortcuts**: Say goodbye to `Ctrl+C`, `Ctrl+V`, `Ctrl+Z`

### Strict File Management
- **Unix-Style Line Endings**: Enforced on save
- **No Backup Files**: Clean workspace, no `.swp` or backup files
- **No Auto-formatting**: Full control over your code formatting

### Enhanced Editing Experience
- **Auto Whitespace Cleanup**: Removes trailing whitespace on save
- **Smart Line Numbers**: Relative in normal mode, absolute in insert mode
- **No Auto-commenting**: Prevents automatic comment continuation
- **Disabled Diagnostics**: Focus on coding without distractions

## ⚙️ Configuration Structure

```
lua/config/
├── autocmds.lua    # Automatic commands and behaviors
├── keymaps.lua     # Key mapping configurations
├── options.lua     # General Neovim options
└── plugins/
    └── plugins.lua # Plugin-specific settings
```

## 🛠️ Installation

1. Back up your existing Neovim configuration:
```bash
mv ~/.config/nvim ~/.config/nvim.backup
```

2. Clone this repository:
```bash
git clone https://github.com/yourusername/vim-hardmode.git ~/.config/nvim
```

3. Start Neovim and let it install dependencies:
```bash
nvim
```

## 💡 Philosophy

This configuration follows the "hard way is the right way" philosophy. By removing common shortcuts and comfort features, it forces users to:

- Master Vim's native movement commands
- Learn efficient text manipulation
- Develop muscle memory for powerful Vim operations
- Break away from inefficient editing habits

## 🤔 Why So Strict?

1. **Muscle Memory Development**: Without fallback options, you're forced to learn the efficient way
2. **Speed Optimization**: Keyboard-only workflow is faster once mastered
3. **Cross-Platform Consistency**: These skills work everywhere Vim is installed
4. **Better Understanding**: Learning the "Vim way" helps you understand its philosophy

## 📝 Notes

- This configuration is intentionally challenging for beginners
- Expect a learning curve of 1-2 weeks
- Consider practicing with `vimtutor` before using this configuration
- Keep a cheat sheet handy for common Vim commands

## ⚠️ Warning

This configuration intentionally disables many familiar features. It's designed for learning and may not be suitable for production environments without modifications.

## 🤝 Contributing

Feel free to submit pull requests or suggest improvements! Let's make the path to Vim mastery even better together.

## ⚡ Want Speed Without the Bloat?

If you're a developer who values **performance, minimalism, and full control**, check out the [`nvim_lite`](https://github.com/HorikitaSuzuneTsundere/Hori-VimConfig/tree/main/nvim_lite) directory.

It's a stripped-down, blazing-fast variant of this config — zero fluff, just the essentials. Perfect as a clean foundation to build your own high-performance Neovim workflow without the noise.

No distractions. No hand-holding. Just speed.
