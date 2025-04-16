# Claude Code Neovim

An enhanced Claude Code integration for Neovim. Provides AI-assisted coding features using Claude Code CLI.

![Claude Code Neovim](https://github.com/pauldub/claude-code-nvim/blob/main/assets/screenshot.png?raw=true)

## Features

- 🧠 Code analysis and insights powered by Claude AI
- 🔍 Code review with detailed feedback
- 📝 Code explanation to understand complex sections
- 🔄 Code refactoring suggestions
- 🐛 Debugging assistance
- ✅ Test generation
- 💬 Git commit message generation
- 📋 Pull request description creation
- 📚 Codebase overview
- 🔧 Customizable templates for all operations
- 💻 Intuitive keybindings and commands

## Requirements

- Neovim 0.7.0+
- [Claude Code CLI](https://claude.ai/code) installed
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Installation

### Using Lazy

```lua
{
  'pauldub/claude-code-nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('claude-code').setup({})
  end
}
```

## Configuration

Claude Code Neovim can be configured with these options:

```lua
require('claude-code').setup({
  -- Path to Claude Code CLI executable
  claude_path = vim.fn.expand('~/.claude/local/claude'),

  -- Default options for Claude CLI
  claude_options = '',

  -- File path for custom CLAUDE.md memory file
  memory_path = vim.fn.expand('~/.claude/CLAUDE.md'),

  -- Whether to use a floating window for output (true) or buffer (false)
  use_floating = true,

  -- Max height/width of floating window as percentage of screen
  float_height_pct = 0.8,
  float_width_pct = 0.8,

  -- Whether to show thinking in extended mode
  show_thinking = false,

  -- Default MCP server to use (if any)
  mcp_server = nil,

  -- Whether to enable debug mode (--debug)
  debug_mode = false,

  -- Whether to enable MCP debug mode (--mcp-debug)
  mcp_debug = false,

  -- Whether to log Claude CLI invocations to a log file
  log_commands = true,

  -- Path for Claude CLI log file
  log_file = nil, -- defaults to stdpath("cache")/claude_cli.log

  -- Output format: "text" (default), "json", or "stream-json"
  output_format = 'text',

  -- Allowed tools (comma or space-separated list like "Bash Edit")
  allowed_tools = nil,

  -- Whether to use JSON parsing for programmatic access to responses
  parse_json = false,

  -- Default Git base branch for PR comparisons
  git_base_branch = 'main',

  -- Request timeout in seconds
  timeout = 60,

  -- Minimum required Claude CLI version (semver)
  min_version = '0.2.70',
})
```

## Commands

- `:ClaudeReview` - Review selected code with Claude (visual mode)
- `:ClaudeCommit` - Generate git commit message with Claude
- `:ClaudePR` - Generate PR description with Claude
- `:ClaudeExplain` - Explain selected code with Claude (visual mode)
- `:ClaudeRefactor` - Refactor selected code with Claude (visual mode)
- `:ClaudeDebug` - Debug code with Claude (visual mode)
- `:ClaudeTest` - Generate tests with Claude (visual mode)
- `:ClaudeMemory` - Edit Claude Memory file
- `:ClaudeCodebase` - Get codebase overview with Claude
- `:Claude [prompt]` - Ask Claude a question
- `:ClaudeTemplateEdit [template]` - Edit a template
- `:ClaudeTemplateReset [template]` - Reset a template to default
- `:ClaudeTemplateList` - List all available templates

## Keybindings

Claude Code adds keybindings under `<leader>a` namespace for AI operations:

**Normal mode:**
- `<leader>ac` - Generate commit message with Claude
- `<leader>ap` - Generate PR description with Claude
- `<leader>am` - Edit Claude Memory file
- `<leader>ao` - Get codebase overview with Claude
- `<leader>aq` - Ask Claude a question (opens command with prompt)
- `<leader>ate` - Edit Claude template
- `<leader>atr` - Reset Claude template to default
- `<leader>atl` - List all Claude templates

**Visual mode:**
- `<leader>ar` - Review selected code with Claude
- `<leader>ae` - Explain selected code with Claude
- `<leader>af` - Refactor selected code with Claude
- `<leader>ad` - Debug selected code with Claude
- `<leader>at` - Generate tests for selected code with Claude

## Templates

Claude Code uses customizable templates for different operations. Templates are stored in `{config_dir}/templates/claude-code/` with .tpl extension.

Available templates:
- commit: Generate git commit messages
- pr: Generate pull request descriptions
- review: Code review
- debug: Debug assistance
- explain: Code explanation
- refactor: Code refactoring
- test: Test generation
- codebase: Codebase overview

You can edit templates via `:ClaudeTemplateEdit` command or directly edit the files in the templates directory.

## License

MIT License
