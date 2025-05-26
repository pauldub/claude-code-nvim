---@mod claude-code Claude Code Neovim Plugin
---@brief [[
--- A minimal Neovim plugin for Claude Code integration.
---
--- Usage:
---   :Claude <prompt>
---
--- Example:
---   :Claude explain this function
---@brief ]]

local M = {}

---@class ClaudeConfig
---@field timeout? number Timeout in milliseconds (default: 60000 = 1 minute)
---@field split_direction? "horizontal"|"vertical" Split direction (default: "horizontal")
---@field output_format? "text"|"json"|"stream-json" Output format (default: "json")
---@field show_metadata? boolean Show metadata in output (default: false)
---@field debug? boolean Enable debug logging (default: false)

-- Private config table
local config = {
	timeout = 60000, -- 1 minute default
	split_direction = "horizontal",
	output_format = "json",
	show_metadata = false,
	debug = false,
}

---@class ClaudeResult
---@field type "result"
---@field subtype "success"|"error_max_turns"
---@field cost_usd number
---@field is_error boolean
---@field duration_ms number
---@field duration_api_ms number
---@field num_turns number
---@field result string
---@field session_id string

---Debug log helper
---@param msg string Message to log
---@private
local function debug_log(msg)
	if config.debug then
		vim.notify("[Claude Debug] " .. msg, vim.log.levels.INFO)
	end
end

---Execute command using vim.system (Neovim 0.10+) or vim.fn.system
---@param cmd string[] Command array
---@return string output Command output
---@return number exit_code Exit code
---@private
local function execute_command_modern(cmd)
	debug_log("Executing: " .. table.concat(cmd, " "))
	
	-- Try vim.system if available (Neovim 0.10+)
	if vim.system then
		debug_log("Using vim.system")
		local result = vim.system(cmd, { text = true }):wait(config.timeout)
		
		if result.code == 124 then -- timeout exit code
			error("Claude command timed out after " .. config.timeout .. "ms")
		end
		
		debug_log("Exit code: " .. result.code)
		debug_log("Stdout length: " .. string.len(result.stdout or ""))
		debug_log("Stderr: " .. (result.stderr or ""))
		
		if result.code ~= 0 then
			local error_msg = result.stderr or ("Exit code: " .. result.code)
			error("Claude command failed: " .. error_msg)
		end
		
		return result.stdout or "", result.code
	else
		-- Fallback to vim.fn.system
		debug_log("Using vim.fn.system")
		local cmd_str = table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ")
		
		-- Save and modify shell options for better compatibility
		local old_shell = vim.o.shell
		local old_shellcmdflag = vim.o.shellcmdflag
		local old_shellredir = vim.o.shellredir
		local old_shellxquote = vim.o.shellxquote
		
		-- Use sh for better compatibility
		vim.o.shell = '/bin/sh'
		vim.o.shellcmdflag = '-c'
		vim.o.shellredir = '>%s 2>&1'
		vim.o.shellxquote = ''
		
		local output = vim.fn.system(cmd_str)
		local exit_code = vim.v.shell_error
		
		-- Restore shell options
		vim.o.shell = old_shell
		vim.o.shellcmdflag = old_shellcmdflag
		vim.o.shellredir = old_shellredir
		vim.o.shellxquote = old_shellxquote
		
		debug_log("Exit code: " .. exit_code)
		debug_log("Output length: " .. string.len(output))
		
		if exit_code ~= 0 then
			error("Claude command failed with exit code " .. exit_code .. ": " .. vim.trim(output))
		end
		
		return output, exit_code
	end
end

---Run Claude with a prompt
---@param prompt string The prompt to send to Claude
---@return string output Claude's response
---@return ClaudeResult? metadata Result metadata (only if output_format is "json")
function M.run(prompt)
	-- Check if claude is available
	if vim.fn.executable("claude") ~= 1 then
		error("Claude CLI not found. Please install from https://claude.ai/code")
	end
	
	local cmd = { "claude", "-p", prompt, "--output-format", config.output_format }
	
	debug_log("Running claude with prompt: " .. prompt)
	
	local raw_output = execute_command_modern(cmd)
	
	if config.output_format == "json" then
		debug_log("Parsing JSON output...")
		-- Trim output to handle any extra whitespace
		raw_output = vim.trim(raw_output)
		local ok, result = pcall(vim.json.decode, raw_output)
		if ok and result and result.type == "result" then
			debug_log("JSON parse successful. Session ID: " .. (result.session_id or "unknown"))
			return result.result or "", result
		else
			debug_log("JSON parse failed or unexpected format. Using raw output.")
			if not ok then
				debug_log("Parse error: " .. tostring(result))
			end
			-- Fallback if JSON parsing fails
			return raw_output, nil
		end
	else
		return raw_output, nil
	end
end

---Create a buffer for Claude output
---@param content string Content to display
---@return number bufnr Buffer number
---@private
local function create_output_buffer(content)
	local buf = vim.api.nvim_create_buf(false, true)

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	
	-- Use a unique name to avoid conflicts
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	vim.api.nvim_buf_set_name(buf, "Claude Output - " .. timestamp)

	local lines = vim.split(content, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.bo[buf].modifiable = false

	return buf
end

---Show Claude output in a split
---@param content string Content to display
---@private
local function show_in_split(content)
	local cmd = config.split_direction == "vertical" and "vnew" or "new"
	vim.cmd(cmd)
	local win = vim.api.nvim_get_current_win()
	local buf = create_output_buffer(content)
	vim.api.nvim_win_set_buf(win, buf)
end

---Execute Claude command
---@param args string Command arguments
function M.claude_command(args)
	-- Validate and clean input
	args = vim.trim(args or "")
	if args == "" then
		vim.notify("Usage: :Claude <prompt>", vim.log.levels.ERROR)
		return
	end

	vim.notify("Running Claude...", vim.log.levels.INFO)

	local ok, result, metadata = pcall(M.run, args)

	if not ok then
		vim.notify("Error: " .. tostring(result), vim.log.levels.ERROR)
		return
	end
	
	local content = result
	
	-- Add metadata to output if requested
	if config.show_metadata and metadata then
		local meta_lines = {
			"---",
			string.format("Session: %s", metadata.session_id or "unknown"),
			string.format("Cost: $%.4f", metadata.cost_usd or 0),
			string.format("Duration: %.2fs", (metadata.duration_ms or 0) / 1000),
			string.format("Turns: %d", metadata.num_turns or 0),
			"---",
			"",
		}
		content = table.concat(meta_lines, "\n") .. content
	end

	show_in_split(content)
end

---Setup the Claude Code plugin
---@param user_config? ClaudeConfig Plugin configuration
function M.setup(user_config)
	if user_config then
		-- Validate config
		if user_config.timeout and user_config.timeout < 0 then
			error("Timeout must be a positive number")
		end
		config = vim.tbl_deep_extend("force", config, user_config)
	end

	vim.api.nvim_create_user_command("Claude", function(opts)
		M.claude_command(opts.args)
	end, {
		nargs = "+",
		desc = "Run Claude with a prompt",
	})
end

return M