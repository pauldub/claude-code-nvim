# claude-code.nvim

A minimal Neovim plugin for Claude Code integration. One command, no fluff.

## Requirements

- Neovim >= 0.5
- [Claude Code CLI](https://claude.ai/code) installed

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "pauldub/claude-code-nvim",
  config = function()
    require('claude-code').setup({
      -- Optional configuration
      timeout = 60000,  -- milliseconds (default: 1 minute)
      split_direction = "horizontal",  -- or "vertical"
      output_format = "json",  -- "text", "json", or "stream-json"
      show_metadata = false  -- show cost/duration info
    })
  end
}
```

## Usage

### Normal Mode

```vim
:Claude <your prompt>
```

Examples:
- `:Claude explain this function`
- `:Claude refactor for better performance`
- `:Claude write tests for this code`

### Visual Mode

Select code and run `:Claude` to analyze it:

1. Select code in visual mode (`v`, `V`, or `<C-v>`)
2. Type `:Claude` (or `:'<,'>Claude`)
3. Optionally add a prompt: `:'<,'>Claude explain this function`

When used in visual mode:
- Without prompt: sends just the selected code
- With prompt: sends both your prompt and the selected code

The output will open in a new split buffer with markdown syntax highlighting.

## Developer Experience

- **Type Annotations**: Full LuaLS annotations for autocomplete and type checking
- **Documentation**: Access help with `:h claude-code`
- **Testing**: Run tests with `./run_tests.sh`

## Configuration

```lua
require('claude-code').setup({
  timeout = 120000,  -- Timeout in milliseconds (default: 60000 = 1 minute)
  split_direction = "vertical",  -- Split direction: "horizontal" or "vertical"
  output_format = "json",  -- Output format: "text", "json" (default), or "stream-json"
  show_metadata = true,  -- Show cost and timing info (default: false)
  debug = false  -- Enable debug logging (default: false)
})
```

## License

MIT