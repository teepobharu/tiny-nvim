# Welcome to tiny_nvim 👋

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](#)
[![Twitter: jellydn](https://img.shields.io/twitter/follow/jellydn.svg?style=social)](https://twitter.com/jellydn)

> Slim Neovim config for 0.11+ with minimal plugins.

[![Slim Neovim config for 0.11](https://i.gyazo.com/6e351d72c2f119f70dbc55d61e9452fd.png)](https://gyazo.com/6e351d72c2f119f70dbc55d61e9452fd)

## Motivation

This configuration is a migration from [my-nvim-ide](https://github.com/jellydn/my-nvim-ide) with two main goals:

1. **Leverage Neovim 0.11+ Built-in Features**:

   - Remove dependency on [`lspconfig`](https://github.com/neovim/nvim-lspconfig/pull/3659) by utilizing Neovim's built-in LSP support

   - Experience faster startup times and reduced complexity
   - Take advantage of the latest Neovim improvements

2. **Optimize Plugin Selection**:
   - Trim down the plugin list to only essential ones
   - Use `blink.cmp` for completion instead of built-in completion for better UX
   - Maintain a minimal yet powerful development environment

The result is a faster, more maintainable configuration that still provides all the necessary features for modern development.

### 🏠 [Homepage](itman.fyi)

## Quick Start

1. Clone this repository:

```bash
git clone https://github.com/jellydn/tiny_nvim.git ~/.config/tiny_nvim
```

2. Run the installation script to set up all required tools:

```bash
cd ~/.config/tiny_nvim
./scripts/install-tools.sh
```

3. Launch Neovim with this configuration:

```bash
NVIM_APPNAME=tiny_nvim nvim
```

## Features

- **Minimal Plugins**: Carefully selected plugins for essential functionality.

  - [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter): Syntax highlighting and incremental selection.
  - [nvim-lint](https://github.com/mfussenegger/nvim-lint): Linting support for multiple file types.
  - [bufferline.nvim](https://github.com/akinsho/bufferline.nvim): Enhanced buffer management.
  - [mini.statusline](https://github.com/echasnovski/mini.statusline): Lightweight statusline.
  - [mini.icons](https://github.com/echasnovski/mini.icons): Improved icon support for better performance.
  - [CopilotChat.nvim](https://github.com/CopilotC-Nvim/CopilotChat.nvim): AI-powered coding assistant.
  - [flash.nvim](https://github.com/folke/flash.nvim): Navigation and search enhancements.
  - [conform.nvim](https://github.com/stevearc/conform.nvim): Formatting support.
  - [which-key.nvim](https://github.com/folke/which-key.nvim): Keybinding hints and management.
  - [snacks.nvim](https://github.com/folke/snacks.nvim): Enhanced UI and utilities.
  - [noice.nvim](https://github.com/folke/noice.nvim): Improved notifications and command-line UI.
  - [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim): Markdown rendering and preview.
  - [trouble.nvim](https://github.com/folke/trouble.nvim): Diagnostics and quickfix management.
  - [catppuccin](https://github.com/catppuccin/nvim): A beautiful colorscheme for Neovim.
  - [lazy.nvim](https://github.com/folke/lazy.nvim): Plugin manager for Neovim.
  - [lazydev.nvim](https://github.com/folke/lazydev.nvim): Development tools for lazy.nvim.
  - [persistence.nvim](https://github.com/folke/persistence.nvim): Session management.
  - [ts-error-translator.nvim](https://github.com/dmmulroy/ts-error-translator.nvim): TypeScript error translation.
  - [better-escape.nvim](https://github.com/max397574/better-escape.nvim): Better escape functionality.
  - [LuaSnip](https://github.com/L3MON4D3/LuaSnip): Snippet engine.
  - [friendly-snippets](https://github.com/rafamadriz/friendly-snippets): Snippet collection.
  - [blink-copilot](https://github.com/folke/blink-copilot): Copilot integration.
  - [blink.cmp](https://github.com/folke/blink.cmp): Completion menu integration.

### How to Use Extra Plugins

To use the extra plugins, you need to import them in your lazy.nvim configuration. For example:

```lua
require("lazy").setup({
  spec = {
    { import = "plugins" },
    { import = "langs" },
    { import = "plugins.extra" }, -- Import extra plugins
  },
  install = { colorscheme = { "kanagawa" } },
  checker = { enabled = true },
})
```

## Resources

- [What's New in Neovim 0.11](https://gpanders.com/blog/whats-new-in-neovim-0-11/): A detailed overview of the latest features and improvements in Neovim 0.11.
- [Neovim 0.11 Built-in Completion Setup](https://gist.github.com/miroshQa/7c61292bc37070bb7606a29e07fe00e2): A comprehensive guide for setting up built-in completion in Neovim 0.11+.

## Author

👤 **Dung Huynh Duc**

- Website: https://productsway.com/
- Twitter: [@jellydn](https://twitter.com/jellydn)
- Github: [@jellydn](https://github.com/jellydn)

## Neovide

```toml
# .config/neovide/config.toml
fork = true # Detach from the terminal instead of waiting for the Neovide process to terminate.
frame = "buttonless" # Transparent decorations including a transparent bar.
maximized = true # Maximize the window on startup, while still having decorations and the status bar of your OS visible.
title-hidden = true
```

# Fonts

I recommend using the following repo to get a "Nerd Font" (Font that supports icons)

[getnf](https://github.com/ronniedroid/getnf)

## Uninstall

```sh
  rm -rf ~/.config/nvim
  rm -rf ~/.local/share/nvim
  rm -rf ~/.cache/nvim
  rm -rf ~/.local/state/nvim
```

# Tips

- Improve key repeat on Mac OSX, need to restart

```sh
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 14
```

- VSCode on Mac

To enable key-repeating, execute the following in your Terminal, log out and back in, and then restart VS Code:

```sh
# For VS Code
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
# For VS Code Insider
defaults write com.microsoft.VSCodeInsiders ApplePressAndHoldEnabled -bool false
# If necessary, reset global default
defaults delete -g ApplePressAndHoldEnabled
# For Cursor
defaults write com.todesktop.230313mzl4w4u92 ApplePressAndHoldEnabled -bool false
```

Also increasing Key Repeat and Delay Until Repeat settings in System Preferences -> Keyboard.

[![Key repeat rate](https://i.gyazo.com/e58be996275fe50bee31412ea5930017.png)](https://gyazo.com/e58be996275fe50bee31412ea5930017)

- Disable `full stop with double-space` if you see the delay with `<space>-<space>`

[![Which-key](https://i.gyazo.com/6403f6c57d2e54aca230589b2173eeb0.png)](https://gyazo.com/6403f6c57d2e54aca230589b2173eeb0)

## Resources

[![IT Man - LazyVim Power User Guide](https://i.ytimg.com/vi/jveM3hZs_oI/hqdefault.jpg)](https://www.youtube.com/watch?v=jveM3hZs_oI)

[![IT Man - Talk #33 NeoVim as IDE [Vietnamese]](https://i.ytimg.com/vi/dFi8CzvqkNE/hqdefault.jpg)](https://www.youtube.com/watch?v=dFi8CzvqkNE)

[![IT Man - Talk #35 #Neovim IDE for Web Developer](https://i.ytimg.com/vi/3EbgMJ-RcWY/hqdefault.jpg)](https://www.youtube.com/watch?v=3EbgMJ-RcWY)

[![IT Man - Step-by-Step Guide: Integrating Copilot Chat with Neovim [Vietnamese]](https://i.ytimg.com/vi/By_CCai62JE/hqdefault.jpg)](https://www.youtube.com/watch?v=By_CCai62JE)

[![IT Man - Power up your Neovim with Gen.nvim](https://i.ytimg.com/vi/2nt_qcchW_8/hqdefault.jpg)](https://www.youtube.com/watch?v=2nt_qcchW_8)

[![IT Man - Boost Your Neovim Productivity with GitHub Copilot Chat](https://i.ytimg.com/vi/6oOPGaKCd_Q/hqdefault.jpg)](https://www.youtube.com/watch?v=6oOPGaKCd_Q)

[![IT Man - Get to know GitHub Copilot Chat in #Neovim and be productive IMMEDIATELY](https://i.ytimg.com/vi/sSih4khcstc/hqdefault.jpg)](https://www.youtube.com/watch?v=sSih4khcstc)

[![IT Man - Master Neovim with CopilotChat.nvim v3: Features, Demos, and Innovations](https://i.ytimg.com/vi/PfYnLcSVPh0/hqdefault.jpg)](https://www.youtube.com/watch?v=PfYnLcSVPh0)

[![IT Man - Enhance Your Neovim Experience with LSP Plugins](https://i.ytimg.com/vi/JwWNIQgL4Fk/hqdefault.jpg)](https://www.youtube.com/watch?v=JwWNIQgL4Fk)

[![IT Man - Bringing Zed AI Experience to Neovim with codecompanion.nvim](https://i.ytimg.com/vi/KbWI4ilHKv4/hqdefault.jpg)](https://www.youtube.com/watch?v=KbWI4ilHKv4)

## Show your support

Give a ⭐️ if this project helped you!
