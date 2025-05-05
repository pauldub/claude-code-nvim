-- Claude Code commands
-- Provides user commands for template management and other utilities

local M = {}
local templates = require("claude-code.templates")

-- Initialize commands for template management
function M.setup(config)
	-- Create template commands
	vim.api.nvim_create_user_command("ClaudeTemplateEdit", function(opts)
		local template_name = opts.args
		if template_name == "" then
			-- If no template name provided, list available templates
			local available = templates.list_templates()
			vim.ui.select(available, {
				prompt = "Select template to edit:",
			}, function(choice)
				if choice then
					templates.edit_template(choice)
				end
			end)
		else
			templates.edit_template(template_name)
		end
	end, {
		nargs = "?",
		desc = "Edit Claude template",
		complete = function()
			return templates.list_templates()
		end,
	})

	vim.api.nvim_create_user_command("ClaudeTemplateReset", function(opts)
		local template_name = opts.args
		if template_name == "" then
			-- If no template name provided, list available templates
			local available = templates.list_templates()
			vim.ui.select(available, {
				prompt = "Select template to reset:",
			}, function(choice)
				if choice then
					templates.reset_template(choice)
				end
			end)
		else
			templates.reset_template(template_name)
		end
	end, {
		nargs = "?",
		desc = "Reset Claude template to default",
		complete = function()
			return templates.list_templates()
		end,
	})

	vim.api.nvim_create_user_command("ClaudeTemplateList", function()
		local available = templates.list_templates()
		local msg = "Available templates:\n"
		for _, name in ipairs(available) do
			msg = msg .. "- " .. name .. "\n"
		end
		vim.notify(msg, vim.log.levels.INFO)
	end, {
		desc = "List all Claude templates",
	})

	-- Create keybindings for template management
	local map = vim.keymap.set
	map("n", "<leader>ate", "<cmd>ClaudeTemplateEdit<CR>", { desc = "[A]I: [T]emplate [E]dit" })
	map("n", "<leader>atr", "<cmd>ClaudeTemplateReset<CR>", { desc = "[A]I: [T]emplate [R]eset" })
	map("n", "<leader>atl", "<cmd>ClaudeTemplateList<CR>", { desc = "[A]I: [T]emplate [L]ist" })
end

return M
