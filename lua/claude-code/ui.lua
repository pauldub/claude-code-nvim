-- Claude Code UI components
-- Handles display of results and user interactions

local M = {}
local config = {}
local buffers = {} -- Track created buffers for proper cleanup

-- Configure module with user options
function M.setup(opts, global_config)
	-- Store reference to global config
	config = global_config
end

-- Helper function for safe notifications
function M.notify(msg, level)
	level = level or vim.log.levels.INFO
	vim.schedule(function()
		vim.notify(msg, level)
	end)
end

-- Clean up buffer resources
local function cleanup_buffer(bufnr)
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
	buffers[bufnr] = nil
end

-- Create floating window with consistent options
local function create_floating_window(bufnr, title)
	-- Calculate window size
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")

	-- Validate percentage values for safety
	local float_height_pct = config.float_height_pct or 0.8
	local float_width_pct = config.float_width_pct or 0.8

	-- Ensure values are within valid range
	float_height_pct = math.max(0.1, math.min(0.9, float_height_pct))
	float_width_pct = math.max(0.1, math.min(0.9, float_width_pct))

	local win_height = math.floor(height * float_height_pct)
	local win_width = math.floor(width * float_width_pct)

	-- Ensure minimum dimensions
	win_height = math.max(10, win_height)
	win_width = math.max(40, win_width)

	-- Create floating window with reasonable defaults
	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = math.floor((height - win_height) / 2),
		col = math.floor((width - win_width) / 2),
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
		zindex = 50, -- Add z-index for consistent stacking
	})

	-- Set window options
	vim.api.nvim_win_set_option(win, "wrap", true)
	vim.api.nvim_win_set_option(win, "linebreak", true)
	vim.api.nvim_win_set_option(win, "cursorline", true)

	return win
end

-- Create basic buffer with keymaps
local function create_result_buffer(content, filetype)
	-- Create a scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)

	-- Track buffer for cleanup
	buffers[buf] = true

	-- Set buffer content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))

	-- Set filetype for syntax highlighting
	vim.api.nvim_buf_set_option(buf, "filetype", filetype or "markdown")

	-- Add enhanced keybindings
	local keymap_opts = { noremap = true, silent = true }
	local keymaps = {
		{ "n", "q", "<cmd>q<CR>", "Close window" },
		{ "n", "<Esc>", "<cmd>q<CR>", "Close window" },
		{ "n", "yy", '"+yy', "Yank line to system clipboard" },
		{ "v", "y", '"+y', "Yank selection to system clipboard" },
		{ "n", "Y", '"+yg_', "Yank to end of line" },
		{ "n", "<C-f>", "<C-d>", "Scroll down" },
		{ "n", "<C-b>", "<C-u>", "Scroll up" },
		{
			"n",
			"<C-s>",
			function()
				-- Save content to a file
				vim.ui.input({ prompt = "Save as: " }, function(filename)
					if filename and filename ~= "" then
						local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
						-- Expand path if it starts with ~ (home directory)
						if filename:sub(1, 1) == "~" then
							filename = vim.fn.expand(filename)
						end
						local file = io.open(filename, "w")
						if file then
							file:write(content)
							file:close()
							M.notify("Saved to " .. filename, vim.log.levels.INFO)
						else
							M.notify("Failed to save file", vim.log.levels.ERROR)
						end
					end
				end)
			end,
			"Save content to file",
		},
	}

	for _, keymap in ipairs(keymaps) do
		local mode, lhs, rhs, desc = unpack(keymap)
		if type(rhs) == "function" then
			vim.api.nvim_buf_set_keymap(buf, mode, lhs, "", {
				noremap = true,
				silent = true,
				callback = rhs,
				desc = desc,
			})
		else
			vim.api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {
				noremap = true,
				silent = true,
				desc = desc,
			})
		end
	end

	-- Set up an autocommand to clean up when the buffer is closed
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		callback = function()
			cleanup_buffer(buf)
		end,
		once = true,
	})

	return buf
end

-- Show the result in a buffer or floating window
function M.show_result(result, operation_type)
	if not result or result == "" then
		M.notify("No response from Claude", vim.log.levels.WARN)
		return
	end

	-- Format title based on operation type
	local title = "Claude: " .. (operation_type or "Response")

	if config.use_floating then
		-- Create buffer with content and keybindings
		local buf = create_result_buffer(result, "markdown")

		-- Display in floating window
		create_floating_window(buf, title)
	else
		-- Open in a new buffer
		vim.cmd("enew")
		local buf = vim.api.nvim_get_current_buf()

		-- Track buffer
		buffers[buf] = true

		-- Set buffer content and options
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n"))
		vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
		vim.api.nvim_buf_set_name(buf, title)

		-- Add keybindings for basic buffer
		local keymap_opts = { noremap = true, silent = true }
		vim.api.nvim_buf_set_keymap(buf, "n", "q", ":bd<CR>", keymap_opts)
	end
end

-- Get selected text from visual mode using modern API
function M.get_visual_selection()
	-- Safely get current buffer
	local bufnr = vim.api.nvim_get_current_buf()

	-- Safely get visual selection marks
	local ok, visual_start = pcall(vim.api.nvim_buf_get_mark, bufnr, "<")
	if not ok then
		M.notify("Error getting visual selection start", vim.log.levels.ERROR)
		return ""
	end

	local ok2, visual_end = pcall(vim.api.nvim_buf_get_mark, bufnr, ">")
	if not ok2 then
		M.notify("Error getting visual selection end", vim.log.levels.ERROR)
		return ""
	end

	local start_row, start_col = visual_start[1] - 1, visual_start[2]
	local end_row, end_col = visual_end[1] - 1, visual_end[2]

	-- Handle selection direction (if end is before start, swap them)
	if end_row < start_row or (end_row == start_row and end_col < start_col) then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end

	-- Safely get lines in selection
	local ok3, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, start_row, end_row + 1, false)
	if not ok3 or not lines then
		M.notify("Error getting selected lines", vim.log.levels.ERROR)
		return ""
	end

	if #lines == 0 then
		return ""
	end

	-- Adjust the first and last lines to only include the selected text
	if #lines == 1 then
		lines[1] = string.sub(lines[1], start_col + 1, end_col + 1)
	else
		lines[1] = string.sub(lines[1], start_col + 1)
		lines[#lines] = string.sub(lines[#lines], 1, end_col + 1)
	end

	return table.concat(lines, "\n")
end

-- Open memory file
function M.open_memory_file()
	-- Ensure the path exists
	M.ensure_memory_file()

	-- Open the file
	vim.cmd("edit " .. vim.fn.fnameescape(config.memory_path))

	-- Set up auto-save
	local augroup = vim.api.nvim_create_augroup("ClaudeMemoryFile", { clear = true })
	vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
		group = augroup,
		pattern = vim.fn.fnamemodify(config.memory_path, ":t"),
		callback = function()
			vim.cmd("silent! write")
		end,
		desc = "Auto-save Claude memory file",
	})
end

-- Ensure memory file exists with proper directory structure
function M.ensure_memory_file()
	local path = config.memory_path

	-- Expand path
	path = vim.fn.expand(path)

	-- Check if file exists
	local f = io.open(path, "r")
	if not f then
		-- Check if directory exists, create if needed
		local dir = vim.fn.fnamemodify(path, ":h")
		local ok, err = pcall(vim.fn.mkdir, dir, "p")
		if not ok then
			M.notify("Failed to create directory: " .. err, vim.log.levels.ERROR)
			return
		end

		-- Create the file with default template
		f = io.open(path, "w")
		if f then
			f:write("# Claude Memory File\n\n")
			f:write("This file contains important context for Claude when working with your codebase.\n\n")
			f:write("## Project Information\n\n")
			f:write("## Common Commands\n\n")
			f:write("## Coding Conventions\n\n")
			f:close()
			M.notify("Created new Claude memory file at " .. path, vim.log.levels.INFO)
		else
			M.notify("Failed to create Claude memory file", vim.log.levels.ERROR)
		end
	else
		f:close()
	end
end

-- Clean up all tracked buffers
function M.cleanup()
	for bufnr, _ in pairs(buffers) do
		cleanup_buffer(bufnr)
	end
end

return M
