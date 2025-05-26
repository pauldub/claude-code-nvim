# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Neovim is a minimal Neovim plugin that provides a single `:Claude` command to interact with Claude Code CLI.

## Common Commands

- **Run tests**: `./run_tests.sh`
- **Format code**: Use Stylua formatter for Lua files

## Architecture

The plugin consists of:

1. **plugin/claude-code.lua**: Entry point that loads the main module
2. **lua/claude-code.lua**: Core module with SDK wrapper, implements `:Claude` command
   - Full LuaLS type annotations for autocomplete
   - Configurable timeout and split direction
   - Async execution using vim.fn.jobstart
3. **doc/claude-code.txt**: Vimdoc help file
4. **tests/claude-code_spec.lua**: Plenary test suite with mocking

## Developer Notes

- All public APIs have LuaLS annotations for better DX
- Tests mock Neovim's job APIs to avoid real CLI calls
- Documentation is accessible via `:h claude-code`