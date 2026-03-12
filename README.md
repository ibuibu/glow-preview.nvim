# glow-preview.nvim

Neovim plugin for real-time markdown preview using [glow](https://github.com/charmbracelet/glow).

Opens a right pane that renders your markdown with ANSI colors as you type.

## Requirements

- Neovim >= 0.10
- [glow](https://github.com/charmbracelet/glow)

## Installation

### lazy.nvim

```lua
{
  "ibuibu/glow-preview.nvim",
  cmd = "GlowPreview",
  ft = "markdown",
}
```

## Usage

Open a markdown file, then run:

```
:GlowPreview
```

Run again to close the preview pane.

## How it works

- Watches `TextChanged` / `TextChangedI` events with 300ms debounce
- Renders buffer content via `glow` asynchronously
- Displays ANSI-colored output in a virtual terminal buffer (`nvim_open_term`)
