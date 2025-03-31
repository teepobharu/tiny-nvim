# Welcome to tiny_nvim 👋

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](#)
[![Twitter: jellydn](https://img.shields.io/twitter/follow/jellydn.svg?style=social)](https://twitter.com/jellydn)

> Slim Neovim config for 0.11+ with minimal plugins.

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

## Author

👤 **Dung Huynh Duc**

- Website: https://productsway.com/
- Twitter: [@jellydn](https://twitter.com/jellydn)
- Github: [@jellydn](https://github.com/jellydn)

## Show your support

Give a ⭐️ if this project helped you!

[![support us](https://img.shields.io/badge/become-a patreon%20us-orange.svg?cacheSeconds=2592000)](https://www.patreon.com/jellydn)
