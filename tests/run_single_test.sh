#!/bin/bash
# Script to run a single test file for Claude Code Neovim plugin
# Uses real mini.test framework from mini.nvim

# Check if a test file is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <test_file>"
  echo "Example: $0 test_claude_code.lua"
  exit 1
fi

TEST_FILE="$1"
FULL_PATH="$(pwd)/$TEST_FILE"

# Check if the test file exists
if [ ! -f "$FULL_PATH" ]; then
  echo "❌ Test file not found: $FULL_PATH"
  exit 1
fi

# Get absolute path to the plugin directory
if [[ "$(pwd)" == *"/tests" ]]; then
  PLUGIN_DIR="$(dirname "$(pwd)")"
else
  PLUGIN_DIR="$(pwd)"
fi

# Print header
echo "============================================"
echo "Running Test: $TEST_FILE"
echo "============================================"

# Create temp dir for mini.nvim
TEMP_MINI_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'mini_nvim')
echo "Cloning mini.nvim to $TEMP_MINI_DIR..."
git clone --quiet --depth 1 https://github.com/echasnovski/mini.nvim.git "$TEMP_MINI_DIR"

if [ $? -ne 0 ]; then
  echo "❌ Failed to clone mini.nvim."
  # Clean up temp dir
  rm -rf "$TEMP_MINI_DIR"
  exit 1
fi

# Create a temporary test runner
TEMP_RUNNER=$(mktemp)
cat > "$TEMP_RUNNER" << EOF
-- Single test runner for Claude Code Neovim
-- Uses the common setup module with actual mini.test

-- Export the temp mini.nvim directory using a global variable
_G.TEMP_MINI_DIR = "${TEMP_MINI_DIR}"

-- Add plugin directory to runtimepath first
vim.opt.rtp:prepend('${PLUGIN_DIR}')

-- Add mini.nvim to runtimepath
vim.opt.rtp:prepend('${TEMP_MINI_DIR}')

-- Load the setup module
package.path = package.path .. ";${PLUGIN_DIR}/?.lua"
local setup = require('tests.setup')

-- Run the specific test file
local success = setup.run_file('$FULL_PATH')

-- Run standard tests too for basic validation
setup.run_standard_tests()

if not success then
  vim.cmd("cq 1") -- Exit with error code
else
  print("Test completed successfully")
  vim.cmd("q") -- Exit with success
end
EOF

# Run the temporary test script in headless mode with mini.nvim dir as env variable
TEMP_MINI_DIR="$TEMP_MINI_DIR" nvim --headless -l "$TEMP_RUNNER"

# Capture exit code
EXIT_CODE=$?

# Remove the temporary file
rm "$TEMP_RUNNER"

# Cleanup the mini.nvim clone
rm -rf "$TEMP_MINI_DIR"

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "\n✅ Test completed successfully"
else
  echo -e "\n❌ Test failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE