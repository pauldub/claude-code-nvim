# Claude Code Neovim Plugin Tests

This directory contains integration tests for the Claude Code Neovim plugin using the actual mini.test framework.

## Running Tests

### Using the Test Runner Scripts

The simplest way to run all tests:

```bash
./run_tests.sh
```

To run a specific test file:

```bash
cd tests
./run_single_test.sh test_claude_code.lua
```

### How It Works

The test runners:

1. Clone mini.nvim to a temporary directory
2. Set up the runtime path to include both the plugin and mini.nvim
3. Load the actual mini.test framework from the cloned repository
4. Create mocks for external dependencies (like plenary.job)
5. Run the tests using the real mini.test framework
6. Clean up temporary files and directories

This approach ensures that tests run with the actual mini.test framework without requiring a permanent installation.

## Test Structure

Tests use the mini.test framework with:
- Test sets organized by feature
- Standard assertions (equality, inequality)
- Hooks for setup and teardown

Each test file follows the structure:

```lua
-- Load the plugin
local claude_code = require('claude-code')

-- Get mini.test from the setup module
local mini_test = require("mini.test")

-- Create test set
local T = mini_test.new_set()

-- Group tests by feature
T["feature_name"] = mini_test.new_set({
  hooks = {
    pre_case = function()
      -- Reset test state before each test
      _G._test_job_calls = {}
      _G._test_ui_result = nil
      _G._test_ui_title = nil
    end,
  }
})

-- Individual test case
T["feature_name"]["test_description"] = function()
  -- Arrange
  -- Act
  claude_code.some_function()
  
  -- Assert
  mini_test.expect.equality(actual, expected, "Assert message")
end

-- Return the test set
return T
```

## Adding New Tests

1. Create a new test file in the `tests` directory with a name like `test_your_feature.lua`
2. Follow the mini.test structure shown above
3. Use mini_test.expect assertions for validation
4. Return the test set at the end of the file

For detailed documentation about mini.test, refer to the [mini.test documentation](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md).

## Mocks and Testing Environment

The testing framework provides mocks for:
- `plenary.job` to avoid actual CLI calls
- UI functions to capture results without displaying UI
- Claude CLI to record prompts and return mock responses

Global test state is available in `_G`:
- `_G._test_job_calls` - Records CLI calls
- `_G._test_ui_result` - Captures UI results
- `_G._test_ui_title` - Captures UI titles
- `_G._test_notification` - Captures notifications