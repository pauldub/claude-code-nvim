-- Claude Code plugin registration
local has_plenary, _ = pcall(require, 'plenary')
if not has_plenary then
  vim.notify('Claude Code integration requires plenary.nvim', vim.log.levels.ERROR)
  return
end

-- Initialize the plugin
require('claude-code').setup({})