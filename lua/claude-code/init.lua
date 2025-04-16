-- Claude Code Neovim plugin
-- An enhanced Claude Code integration for Neovim
-- Provides AI-assisted coding features using Claude Code CLI

-- Load submodules
local templates = require 'claude-code.templates'
local cli = require 'claude-code.cli'
local ui = require 'claude-code.ui'
local commands = require 'claude-code.commands'

local M = {}

-- Configuration options with defaults
local config = {
  -- Path to Claude Code CLI executable
  claude_path = vim.fn.expand '~/.claude/local/claude',

  -- Default options for Claude Code CLI
  claude_options = '',

  -- File path for custom CLAUDE.md memory file
  memory_path = vim.fn.expand '~/.claude/CLAUDE.md',

  -- Whether to use a floating window for output (true) or buffer (false)
  use_floating = true,

  -- Max height of floating window as percentage of screen
  float_height_pct = 0.8,

  -- Max width of floating window as percentage of screen
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
  
  -- Path for Claude CLI log file (defaults to stdpath("cache")/claude_cli.log)
  log_file = nil,

  -- Output format: "text" (default), "json", or "stream-json"
  output_format = 'text',

  -- Allowed tools (comma or space-separated list like "Bash Edit")
  claude_allowed_tools = nil,

  -- Whether to use JSON parsing for programmatic access to responses
  parse_json = false,

  -- Default Git base branch for PR comparisons
  git_base_branch = 'main',

  -- Request timeout in seconds
  timeout = 60,

  -- Minimum required Claude CLI version (semver)
  min_version = '0.2.70',

  -- Is Claude CLI available (set by check_claude_cli)
  is_available = nil,
}

-- Helper function to validate configuration
local function validate_config(cfg)
  local valid = true

  -- Validate numeric percentage values (0.0-1.0)
  for _, key in ipairs { 'float_height_pct', 'float_width_pct' } do
    if type(cfg[key]) ~= 'number' or cfg[key] <= 0 or cfg[key] > 1 then
      ui.notify(key .. ' must be a number between 0 and 1', vim.log.levels.ERROR)
      valid = false
    end
  end

  -- Validate timeout is a positive number
  if type(cfg.timeout) ~= 'number' or cfg.timeout <= 0 then
    ui.notify('timeout must be a positive number', vim.log.levels.ERROR)
    valid = false
  end

  -- Validate output format is one of the allowed values
  local valid_formats = { text = true, json = true, ['stream-json'] = true }
  if not valid_formats[cfg.output_format] then
    ui.notify('output_format must be one of: text, json, stream-json', vim.log.levels.ERROR)
    valid = false
  end

  return valid
end

-- Configure Claude Code integration
function M.setup(opts)
  -- Merge user config with defaults
  opts = opts or {}
  for k, v in pairs(opts) do
    if k == 'allowed_tools' then
      -- Rename to claude_allowed_tools for clarity
      config.claude_allowed_tools = v
    else
      config[k] = v
    end
  end

  -- Validate the configuration
  if not validate_config(config) then
    ui.notify('Claude Code configuration has errors. Some features may not work correctly.', vim.log.levels.WARN)
  end

  -- Initialize submodules with shared config
  cli.setup(opts, config)
  ui.setup(opts, config)
  commands.setup(config)

  -- Ensure required dependencies are available
  local has_plenary, _ = pcall(require, 'plenary')
  if not has_plenary then
    ui.notify('Claude Code integration requires plenary.nvim', vim.log.levels.ERROR)
    return
  end

  -- Create Claude Code commands
  M.register_commands()

  -- Create memory file if it doesn't exist
  ui.ensure_memory_file()

  -- Check if Claude Code CLI is available
  cli.check_claude_cli()
end

-- Register all user commands and keybindings
function M.register_commands()
  -- Create commands
  local commands = {
    { 'ClaudeReview', 'review_selection', 'Review selected code with Claude', true },
    { 'ClaudeCommit', 'generate_commit_message', 'Generate git commit message with Claude', false },
    { 'ClaudePR', 'generate_pr_description', 'Generate PR description with Claude', false },
    { 'ClaudeExplain', 'explain_selection', 'Explain selected code with Claude', true },
    { 'ClaudeRefactor', 'refactor_selection', 'Refactor selected code with Claude', true },
    { 'ClaudeDebug', 'debug_code', 'Debug code with Claude', true },
    { 'ClaudeTest', 'generate_tests', 'Generate tests with Claude', true },
    { 'ClaudeMemory', 'open_memory_file', 'Edit Claude Memory file', false },
    { 'ClaudeCodebase', 'explain_codebase', 'Get codebase overview with Claude', false },
  }

  for _, cmd in ipairs(commands) do
    local command_name, function_name, description, range = unpack(cmd)
    vim.api.nvim_create_user_command(command_name, function(opts)
      M[function_name](opts)
    end, { range = range, desc = description })
  end

  -- Create the Claude command with args support
  vim.api.nvim_create_user_command('Claude', function(opts)
    M.ask_claude(opts.args)
  end, { nargs = '+', desc = 'Ask Claude a question', complete = 'file' })

  -- Set up keybindings
  local map = vim.keymap.set

  -- Add keybindings under <leader>a for AI operations
  map('n', '<leader>ac', '<cmd>ClaudeCommit<CR>', { desc = '[A]I: Generate [C]ommit message' })
  map('n', '<leader>ap', '<cmd>ClaudePR<CR>', { desc = '[A]I: Generate [P]R description' })
  map('v', '<leader>ar', '<cmd>ClaudeReview<CR>', { desc = '[A]I: [R]eview code' })
  map('v', '<leader>ae', '<cmd>ClaudeExplain<CR>', { desc = '[A]I: [E]xplain code' })
  map('v', '<leader>af', '<cmd>ClaudeRefactor<CR>', { desc = '[A]I: Re[f]actor code' })
  map('v', '<leader>ad', '<cmd>ClaudeDebug<CR>', { desc = '[A]I: [D]ebug code' })
  map('v', '<leader>at', '<cmd>ClaudeTest<CR>', { desc = '[A]I: Generate [T]ests' })
  map('n', '<leader>am', '<cmd>ClaudeMemory<CR>', { desc = '[A]I: Claude [M]emory file' })
  map('n', '<leader>ao', '<cmd>ClaudeCodebase<CR>', { desc = '[A]I: Codebase [O]verview' })
  map('n', '<leader>aq', ':Claude ', { desc = '[A]I: Ask Claude [Q]uestion' })
end

-- Get current file path
function M.get_current_file()
  return vim.api.nvim_buf_get_name(0)
end

-- Get file type
function M.get_filetype()
  return vim.bo.filetype
end

-- Generic function to handle code selection operations
-- This eliminates duplication across similar functions
function M.handle_code_selection(template_name, operation_title, opts)
  local code = ui.get_visual_selection()
  if not code or code == '' then
    ui.notify('No code selected', vim.log.levels.ERROR)
    return false
  end

  local template = templates[template_name]
  if not template then
    ui.notify('Template not found: ' .. template_name, vim.log.levels.ERROR)
    return false
  end

  -- Build context with file info
  local context = {
    code = code,
    filetype = M.get_filetype(),
    filepath = M.get_current_file(),
  }

  -- Add any additional parameters
  if opts then
    for k, v in pairs(opts) do
      context[k] = v
    end
  end

  -- Process the template with all context variables
  local prompt = template
  for k, v in pairs(context) do
    prompt = prompt:gsub('{{' .. k .. '}}', v or '')
  end

  cli.run_claude_cli(prompt, function(result)
    ui.show_result(result, operation_title)
  end)

  return true
end

-- Ask Claude a general question
function M.ask_claude(question)
  if not question then
    ui.notify('No question provided', vim.log.levels.ERROR)
    return
  end

  if type(question) == 'table' then
    question = table.concat(question, ' ')
  end

  if question:trim() == '' then
    ui.notify('Empty question provided', vim.log.levels.ERROR)
    return
  end

  cli.run_claude_cli(question, function(result)
    ui.show_result(result, 'Question')
  end)
end

-- Explain the selected code with Claude
function M.explain_selection()
  M.handle_code_selection('explain', 'Explanation')
end

-- Review the selected code with Claude
function M.review_selection()
  M.handle_code_selection('review', 'Code Review')
end

-- Refactor the selected code with Claude
function M.refactor_selection()
  M.handle_code_selection('refactor', 'Refactor')
end

-- Debug code with Claude
function M.debug_code()
  local code = ui.get_visual_selection()
  if not code or code == '' then
    ui.notify('No code selected', vim.log.levels.ERROR)
    return
  end

  -- Ask for error message
  vim.ui.input({ prompt = 'Error message (optional): ' }, function(error_msg)
    if error_msg == nil then
      -- User cancelled the input
      return
    end

    M.handle_code_selection('debug', 'Debug', {
      error = error_msg:trim() ~= '' and error_msg or 'No specific error message provided',
    })
  end)
end

-- Generate tests for code
function M.generate_tests()
  M.handle_code_selection('test', 'Tests')
end

-- Generate a commit message with Claude
function M.generate_commit_message()
  local diff = cli.get_git_diff()
  if not diff or diff == '' then
    ui.notify('No staged changes found', vim.log.levels.ERROR)
    return
  end

  local prompt = templates.commit:gsub('{{diff}}', diff)
  cli.run_claude_cli(prompt, function(result)
    ui.show_result(result, 'Commit Message')
  end)
end

-- Generate a PR description with Claude
function M.generate_pr_description()
  -- Get the diff between the current branch and the base branch
  local diff = cli.get_pr_diff(config.git_base_branch)

  if not diff or diff == '' then
    ui.notify('No changes found between current branch and ' .. config.git_base_branch, vim.log.levels.ERROR)
    return
  end

  local prompt = templates.pr:gsub('{{changes}}', diff)
  cli.run_claude_cli(prompt, function(result)
    ui.show_result(result, 'PR Description')
  end)
end

-- Get codebase overview with Claude
function M.explain_codebase()
  cli.run_claude_cli(templates.codebase, function(result)
    ui.show_result(result, 'Codebase Overview')
  end)
end

-- Open memory file
function M.open_memory_file()
  ui.open_memory_file()
end

return M