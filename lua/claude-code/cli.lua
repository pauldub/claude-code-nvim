-- Claude Code CLI interactions
-- Handles running commands and processing results

local M = {}
local config = {}

-- Semver comparison helper
local function compare_versions(version1, version2)
	local v1_parts = vim.split(version1, "%.")
	local v2_parts = vim.split(version2, "%.")

	for i = 1, 3 do
		local v1_num = tonumber(v1_parts[i] or "0")
		local v2_num = tonumber(v2_parts[i] or "0")

		if v1_num > v2_num then
			return 1
		elseif v1_num < v2_num then
			return -1
		end
	end

	return 0 -- Versions are equal
end

-- Validate configuration options
local function validate_option(key, value, valid_options, error_msg)
	if value ~= nil and not vim.tbl_contains(valid_options, value) then
		vim.schedule(function()
			vim.notify(error_msg, vim.log.levels.ERROR)
		end)
		return false
	end
	return true
end

-- Validate configuration
local function validate_config(cfg)
	local valid = true

	-- Check claude_path is a string
	if cfg.claude_path ~= nil and type(cfg.claude_path) ~= "string" then
		vim.schedule(function()
			vim.notify("claude_path must be a string", vim.log.levels.ERROR)
		end)
		valid = false
	end

	-- Check output_format is valid
	valid = valid
		and validate_option(
			"output_format",
			cfg.output_format,
			{ "text", "json", "stream-json" },
			"output_format must be one of: text, json, stream-json"
		)

	-- Check timeout is a positive number
	if type(cfg.timeout) ~= "number" or cfg.timeout <= 0 then
		vim.schedule(function()
			vim.notify("timeout must be a positive number", vim.log.levels.ERROR)
		end)
		valid = false
	end

	-- Other validations as needed

	return valid
end

-- Create a secure temporary file
local function create_secure_tempfile(content)
	local plenary_path = require("plenary.path")
	local path = require("plenary.path"):new(vim.fn.tempname())

	-- Set restrictive permissions before writing content
	local fd = vim.loop.fs_open(path.filename, "w", 384) -- 0600 in octal
	if not fd then
		return nil, "Failed to create secure temporary file"
	end

	-- Write content and close file
	local success, err = pcall(function()
		vim.loop.fs_write(fd, content, 0)
		vim.loop.fs_close(fd)
	end)

	if not success then
		return nil, "Failed to write to temporary file: " .. (err or "unknown error")
	end

	return path.filename
end

-- Configure module with user options
function M.setup(opts, global_config)
	-- Store reference to global config
	config = global_config

	-- Validate configuration
	if not validate_config(config) then
		vim.schedule(function()
			vim.notify(
				"Claude Code CLI configuration has errors. Some features may not work correctly.",
				vim.log.levels.WARN
			)
		end)
	end

	-- Notify about logging if enabled
	if config.log_commands then
		local log_path = config.log_file or (vim.fn.stdpath("cache") .. "/claude_cli.log")
		vim.schedule(function()
			vim.notify("Claude CLI command logging enabled. Log file: " .. log_path, vim.log.levels.INFO)
		end)
	end
end

-- Check if Claude CLI is available and validate version
function M.check_claude_cli()
	local job = require("plenary.job")

	-- Create a timeout mechanism
	local timeout_timer = vim.loop.new_timer()
	if not timeout_timer then
		vim.schedule(function()
			vim.notify("Failed to create timer for Claude CLI check", vim.log.levels.ERROR)
			config.is_available = false
		end)
		return
	end

	-- Set the timeout (3 seconds should be enough for version check)
	timeout_timer:start(3000, 0, function()
		vim.schedule(function()
			timeout_timer:stop()
			timeout_timer:close()
			vim.notify("Claude CLI version check timed out", vim.log.levels.WARN)
			config.is_available = false
		end)
	end)

	job:new({
		command = config.claude_path,
		args = { "--version" },
		on_exit = function(j, return_val)
			-- Cancel the timeout timer
			timeout_timer:stop()
			timeout_timer:close()

			vim.schedule(function()
				vim.notify("command : " .. config.claude_path)
				if return_val ~= 0 then
					vim.notify(
						"Claude Code CLI not found. Make sure it's installed and in your PATH.",
						vim.log.levels.WARN
					)
					config.is_available = false
				else
					local output = table.concat(j:result(), "")
					local version = output:match("(%d+%.%d+%.%d+)")
					if version then
						-- Compare with minimum required version
						if compare_versions(version, config.min_version) < 0 then
							vim.notify(
								string.format(
									"Claude Code CLI version %s is below required minimum %s",
									version,
									config.min_version
								),
								vim.log.levels.WARN
							)
							config.is_available = false
						else
							config.is_available = true
							vim.notify("Claude Code CLI detected: " .. output, vim.log.levels.INFO)
						end
					else
						vim.notify("Claude Code CLI version not detected: " .. output, vim.log.levels.WARN)
						config.is_available = false
					end
				end
			end)
		end,
	}):start()
end

-- Get git diff using plenary.job for better performance
function M.get_git_diff()
	local job = require("plenary.job")
	local result = {}

	job:new({
		command = "git",
		args = { "diff", "--staged" },
		on_stdout = function(_, data)
			if data then
				table.insert(result, data)
			end
		end,
		on_stderr = function(_, data)
			if data and data ~= "" then
				vim.schedule(function()
					vim.notify("Git error: " .. data, vim.log.levels.ERROR)
				end)
			end
		end,
		on_exit = function(_, code)
			if code > 0 then
				vim.schedule(function()
					vim.notify("Git command failed with code " .. code, vim.log.levels.ERROR)
				end)
			end
		end,
	}):sync()

	return table.concat(result, "\n")
end

-- Get PR diff using plenary.job
function M.get_pr_diff(base_branch)
	if not base_branch or base_branch == "" then
		base_branch = "main" -- Default fallback
	end

	local job = require("plenary.job")
	local result = {}
	local error_output = {}

	job:new({
		command = "git",
		args = { "diff", "origin/" .. base_branch .. "...HEAD" },
		on_stdout = function(_, data)
			if data then
				table.insert(result, data)
			end
		end,
		on_stderr = function(_, data)
			if data and data ~= "" then
				table.insert(error_output, data)
			end
		end,
		on_exit = function(_, code)
			if code > 0 and #error_output > 0 then
				vim.schedule(function()
					vim.notify("Git error: " .. table.concat(error_output, "\n"), vim.log.levels.ERROR)
				end)
			end
		end,
	}):sync()

	return table.concat(result, "\n")
end

-- Parse command line options safely
local function parse_options(options_str)
	if not options_str or options_str == "" then
		return {}
	end

	local parsed_options = {}
	local current_opt = nil
	local in_quotes = false
	local quote_char = nil
	local buffer = ""

	for i = 1, #options_str do
		local char = options_str:sub(i, i)

		if (char == '"' or char == "'") and (i == 1 or options_str:sub(i - 1, i - 1) ~= "\\") then
			if not in_quotes then
				in_quotes = true
				quote_char = char
			elseif char == quote_char then
				in_quotes = false
				quote_char = nil
			else
				buffer = buffer .. char
			end
		elseif char:match("%s") and not in_quotes then
			if #buffer > 0 then
				if buffer:match("^%-%-") then
					if current_opt then
						table.insert(parsed_options, current_opt)
					end
					current_opt = buffer
				else
					if current_opt then
						table.insert(parsed_options, current_opt)
						table.insert(parsed_options, buffer)
						current_opt = nil
					else
						table.insert(parsed_options, buffer)
					end
				end
				buffer = ""
			end
		else
			buffer = buffer .. char
		end
	end

	-- Handle the last token
	if #buffer > 0 then
		if current_opt then
			table.insert(parsed_options, current_opt)
			table.insert(parsed_options, buffer)
		else
			table.insert(parsed_options, buffer)
		end
	elseif current_opt then
		table.insert(parsed_options, current_opt)
	end

	return parsed_options
end

-- Log Claude CLI command and arguments for debugging
local function log_claude_command(cmd, args, prompt_content)
	-- Skip logging if disabled in config
	if not config.log_commands then
		return
	end

	-- Use the configured log file path or default
	local log_file = config.log_file or (vim.fn.stdpath("cache") .. "/claude_cli.log")

	local log_line = cmd .. " " .. table.concat(args, " ") .. " [stdin]"

	-- Add timestamp to log entry
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	log_line = timestamp .. " | " .. log_line

	-- Append log entry to file
	local file = io.open(log_file, "a")
	if file then
		file:write(log_line .. "\n")

		-- If debug_mode is enabled, also log the prompt content (truncated if very long)
		if config.debug_mode and prompt_content and prompt_content ~= "stdin" then
			if #prompt_content > 500 then
				prompt_content = prompt_content:sub(1, 500)
					.. "... [truncated, total length: "
					.. #prompt_content
					.. "]"
			end
			file:write("PROMPT: " .. prompt_content:gsub("\n", "\\n") .. "\n\n")
		else
			file:write("\n")
		end

		file:close()
	end
end

-- Run Claude CLI with given prompt
function M.run_claude_cli(prompt, callback)
	if not prompt or prompt == "" then
		vim.schedule(function()
			vim.notify("Empty prompt provided", vim.log.levels.ERROR)
		end)
		return
	end

	-- Skip if CLI not available
	if config.is_available == false then
		vim.schedule(function()
			vim.notify("Claude Code CLI is not available. Please check installation.", vim.log.levels.ERROR)
		end)
		return
	end

	-- Check if Claude CLI path exists and is executable
	local claude_exists = vim.fn.executable(config.claude_path) == 1
	if not claude_exists then
		vim.schedule(function()
			vim.notify("Claude Code CLI not found at: " .. config.claude_path, vim.log.levels.ERROR)
		end)
		return
	end

	-- Enable thinking mode if requested
	if config.show_thinking and not prompt:match("think") then
		prompt = "Think about this in detail: " .. prompt
	end

	local job = require("plenary.job")
	local args = {}

	-- Always use print mode (-p) since we're in a non-interactive environment
	table.insert(args, "--print")

	-- Add output format if specified (other than default text)
	if config.output_format ~= "text" then
		table.insert(args, "--output-format")
		table.insert(args, config.output_format)
	end

	-- Enable debug mode if configured
	if config.debug_mode then
		table.insert(args, "--debug")
	end

	-- Enable MCP debug mode if configured
	if config.mcp_debug then
		table.insert(args, "--mcp-debug")
	end

	-- Add allowed tools if specified
	if config.claude_allowed_tools then
		table.insert(args, "--allowedTools")
		table.insert(args, config.claude_allowed_tools)
	end

	-- Add custom options if configured
	if config.claude_options and config.claude_options ~= "" then
		local parsed_options = parse_options(config.claude_options)
		for _, opt in ipairs(parsed_options) do
			table.insert(args, opt)
		end
	end

	-- Add MCP server if configured
	if config.mcp_server then
		table.insert(args, "--mcp")
		table.insert(args, config.mcp_server)
	end

	-- Log the command and arguments for debugging
	log_claude_command(config.claude_path, args, prompt)

	-- Show initial notification
	vim.schedule(function()
		vim.notify("Running Claude Code...", vim.log.levels.INFO)
	end)

	-- Store both stdout and stderr
	local stdout_results = {}
	local stderr_results = {}

	-- Create timeout mechanism
	local timeout_timer = vim.loop.new_timer()
	local timed_out = false

	if timeout_timer then
		timeout_timer:start(config.timeout * 1000, 0, function()
			timed_out = true
			vim.schedule(function()
				vim.notify("Claude Code request timed out after " .. config.timeout .. " seconds", vim.log.levels.ERROR)
			end)

			-- Clean up the job (it will trigger on_exit)
			timeout_timer:stop()
			timeout_timer:close()
		end)
	else
		vim.schedule(function()
			vim.notify("Failed to create timer for Claude command", vim.log.levels.WARN)
		end)
	end

	job:new({
		command = config.claude_path,
		args = args,
		writer = prompt, -- Pipe the prompt directly to stdin
		on_stdout = function(_, data)
			table.insert(stdout_results, data)
		end,
		on_stderr = function(_, data)
			table.insert(stderr_results, data)
		end,
		on_exit = function(j, return_val)
			-- Cancel timeout timer if it's running
			if timeout_timer and not timed_out then
				timeout_timer:stop()
				timeout_timer:close()
			end

			-- Skip further processing if timed out
			if timed_out then
				return
			end

			-- Schedule to avoid fast event context error
			vim.schedule(function()
				if return_val ~= 0 then
					local stderr = table.concat(stderr_results, "\n")
					if stderr ~= "" then
						vim.notify("Claude Code error: " .. stderr, vim.log.levels.ERROR)

						-- Log error response if logging is enabled
						if config.log_commands then
							local log_file = config.log_file or (vim.fn.stdpath("cache") .. "/claude_cli.log")
							local file = io.open(log_file, "a")
							if file then
								file:write("[ERROR RESPONSE] Exit code: " .. return_val .. "\n")
								file:write(stderr .. "\n\n")
								file:close()
							end
						end
					else
						vim.notify("Claude Code command failed with exit code " .. return_val, vim.log.levels.ERROR)
					end
					return
				end

				local result = table.concat(stdout_results, "\n")
				if result == "" then
					vim.notify("Claude Code returned empty response", vim.log.levels.WARN)
					return
				end

				-- Log successful response if logging is enabled
				if config.log_commands then
					local log_file = config.log_file or (vim.fn.stdpath("cache") .. "/claude_cli.log")
					local file = io.open(log_file, "a")
					if file then
						-- Log a truncated version of the response to avoid huge log files
						local log_response = result
						if #log_response > 1000 then
							log_response = log_response:sub(1, 1000)
								.. "... [truncated, total length: "
								.. #result
								.. "]"
						end
						file:write("[RESPONSE] " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
						file:write(log_response .. "\n\n")
						file:close()
					end
				end

				-- Handle JSON parsing if configured and output format is JSON
				if config.parse_json and config.output_format == "json" then
					local status, parsed = pcall(vim.fn.json_decode, result)
					if status then
						-- Extract the text from the JSON result
						if parsed.result then
							result = parsed.result
							-- Optionally show cost/timing info
							if parsed.cost_usd then
								vim.notify(
									string.format(
										"Claude request cost: $%.6f, time: %dms",
										parsed.cost_usd,
										parsed.duration_ms or 0
									),
									vim.log.levels.INFO
								)
							end
						end
					else
						vim.notify("Failed to parse JSON response", vim.log.levels.WARN)
					end
				end

				if callback then
					callback(result)
				else
					-- Return to the module to display
					return result
				end
			end)
		end,
	}):start()
end

return M
