#!/bin/bash
# Script to run all tests for Claude Code Neovim plugin
# Uses real mini.test framework from mini.nvim

# Print header
echo "============================================"
echo "Running Claude Code Neovim Plugin Tests"
echo "============================================"

# Get absolute path to the plugin directory
PLUGIN_DIR="$(pwd)"

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
-- Main test runner for Claude Code Neovim
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

-- Run all tests
local success = setup.run_all()

if not success then
  vim.cmd("cq 1") -- Exit with error code
else
  print("All tests completed successfully")
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
  echo "✅ Tests completed successfully"
else
  echo "❌ Tests failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE