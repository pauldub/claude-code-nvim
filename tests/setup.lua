-- setup.lua
-- Common setup for Claude Code Neovim plugin tests
-- Configures environment and mocks for testing

local M = {}

-- Use mini.test from the runtime path
function M.ensure_mini_test()
	-- Get mini.nvim path from global variable or environment
	local temp_dir = _G.TEMP_MINI_DIR or os.getenv("TEMP_MINI_DIR")

	if not temp_dir or temp_dir == "" then
		error("TEMP_MINI_DIR environment variable or global not set. Mini.nvim path unknown.")
	end

	-- Add mini.nvim to runtimepath if not already
	if not vim.tbl_contains(vim.api.nvim_list_runtime_paths(), temp_dir) then
		vim.opt.rtp:prepend(temp_dir)
	end

	-- Try to load mini.test
	local ok, mini_test = pcall(require, "mini.test")
	if not ok then
		error("Failed to load mini.test: " .. tostring(mini_test))
	end

	return mini_test
end

-- Setup function to initialize the test environment
function M.setup()
	-- Add plugin to runtimepath
	local plugin_dir = vim.fn.getcwd():gsub("/tests$", "")
	vim.opt.rtp:prepend(plugin_dir)

	-- Mock plenary.job to avoid actual CLI calls
	package.loaded["plenary.job"] = {
		new = function(opts)
			-- Record jobs for testing
			if not _G._test_job_calls then
				_G._test_job_calls = {}
			end

			local call_details = {
				command = opts.command,
				args = opts.args,
				writer = opts.writer,
			}

			table.insert(_G._test_job_calls, call_details)

			-- Return mock job object
			local mock_job = {}
			function mock_job:start()
				if opts.on_exit then
					vim.schedule(function()
						if opts.on_stdout then
							opts.on_stdout(nil, "Mock response for testing")
						end
						opts.on_exit(nil, 0)
					end)
				end
				return mock_job
			end
			function mock_job:sync()
				return { "mock git diff" }
			end
			mock_job.result = function()
				return { "1.0.0" }
			end
			return mock_job
		end,
	}

	-- Reset test globals
	_G._test_job_calls = {}
	_G._test_ui_result = nil
	_G._test_ui_title = nil
	_G._test_notification = nil

	-- Set up UI mocks
	local ui = require("claude-code.ui")
	ui.show_result = function(result, title)
		_G._test_ui_result = result
		_G._test_ui_title = title
		print(string.format("UI showing: %s (title: %s)", result, title))
	end

	ui.notify = function(msg, level)
		_G._test_notification = {
			msg = msg,
			level = level,
		}
		print(string.format("Notification: %s (level: %s)", msg, level))
	end

	ui.get_visual_selection = function()
		return "function test() { return 42; }"
	end

	-- Configure CLI mocks
	local cli = require("claude-code.cli")
	cli.run_claude_cli = function(prompt, callback)
		if not _G._test_job_calls then
			_G._test_job_calls = {}
		end

		table.insert(_G._test_job_calls, {
			prompt = prompt,
		})

		print(string.format("Claude CLI called with prompt: %s", prompt:sub(1, 50) .. "..."))

		if callback then
			callback("Mock Claude response")
		end
	end

	-- Configure plugin with test settings
	require("claude-code").setup({
		claude_path = "/mock/claude",
		use_floating = false,
		timeout = 1,
		is_available = true,
	})
end

-- Run a suite of standard tests that should be included in all runs
function M.run_standard_tests()
	local MiniTest = M.ensure_mini_test()
	local claude_code = require("claude-code")

	local T = MiniTest.new_set()

	T["standard_tests"] = MiniTest.new_set()

	T["standard_tests"]["ask_claude_with_valid_input"] = function()
		-- Clear job calls
		_G._test_job_calls = {}
		_G._test_ui_result = nil
		_G._test_ui_title = nil

		-- Act
		claude_code.ask_claude("Test question")

		-- Assert
		MiniTest.expect.equality(#_G._test_job_calls, 1)
		MiniTest.expect.equality(_G._test_job_calls[1].prompt, "Test question")
		MiniTest.expect.equality(_G._test_ui_result, "Mock Claude response")
		MiniTest.expect.equality(_G._test_ui_title, "Question")
	end

	T["standard_tests"]["ask_claude_with_empty_input"] = function()
		-- Clear job calls
		_G._test_job_calls = {}
		_G._test_notification = nil

		-- Act
		claude_code.ask_claude("")

		-- Assert
		MiniTest.expect.equality(#_G._test_job_calls, 0)
		MiniTest.expect.equality(_G._test_notification.msg, "Empty question provided")
		MiniTest.expect.equality(_G._test_notification.level, vim.log.levels.ERROR)
	end

	T["standard_tests"]["explain_selection"] = function()
		-- Clear job calls
		_G._test_job_calls = {}
		_G._test_ui_result = nil
		_G._test_ui_title = nil

		-- Act
		claude_code.explain_selection()

		-- Assert
		MiniTest.expect.equality(#_G._test_job_calls, 1)
		MiniTest.expect.no_equality(_G._test_job_calls[1].prompt:find("function test()"), nil)
		MiniTest.expect.no_equality(_G._test_job_calls[1].prompt:find("Explain what this code does"), nil)
		MiniTest.expect.equality(_G._test_ui_title, "Explanation")
	end

	-- Run the test suite using mini.test.run
	MiniTest.run({ T })

	return true
end

-- Run a specific test file with our test environment
function M.run_file(file_path)
	M.setup()

	-- Load mini.test
	local MiniTest = M.ensure_mini_test()

	print("Running test file: " .. file_path)

	-- Get the current rtp to debug
	local rtp = vim.opt.rtp:get()
	print("Runtime paths:")
	for i, path in ipairs(rtp) do
		print(i .. ": " .. path)
	end

	local success, result = pcall(dofile, file_path)
	if not success then
		print("\n❌ Test file failed: " .. tostring(result))
		return false
	end

	-- Check if the file returned a test set
	if type(result) ~= "table" then
		print("\n❌ Test file did not return a test set")
		return false
	end

	-- Run the test sets
	MiniTest.run({ result })

	print("\n✅ Test file completed successfully")
	return true
end

-- Run all test files in the tests directory
function M.run_all()
	M.setup()

	-- Load mini.test
	local MiniTest = M.ensure_mini_test()

	-- Find all test files
	local glob = vim.fn.glob("./tests/test_*.lua", false, true)
	if #glob == 0 then
		print("No test files found in ./tests/")
		return false
	end

	print("Found " .. #glob .. " test files")

	-- First run standard tests
	M.run_standard_tests()

	-- Run each test file
	local all_passed = true
	for _, file in ipairs(glob) do
		print("\nRunning test file: " .. file)
		local success, result = pcall(dofile, file)
		if not success then
			print("❌ Test file failed: " .. file)
			print(tostring(result))
			all_passed = false
		else
			-- Check if the file returned a test set
			if type(result) == "table" then
				-- Run the test sets
				MiniTest.run({ result })
				print("✅ Test file passed: " .. file)
			else
				print("❌ Test file did not return a test set: " .. file)
				all_passed = false
			end
		end
	end

	if all_passed then
		print("\n✅ All tests passed!")
		return true
	else
		print("\n❌ Some tests failed")
		return false
	end
end

return M
