if vim.g.loaded_claude_code then
  return
end
vim.g.loaded_claude_code = true

require('claude-code').setup()