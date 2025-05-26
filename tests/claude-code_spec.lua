describe("claude-code", function()
  local claude_code
  
  before_each(function()
    -- Reset modules before each test
    package.loaded['claude-code'] = nil
    claude_code = require('claude-code')
  end)
  
  describe("setup", function()
    it("should create Claude user command", function()
      claude_code.setup()
      
      -- Check if command exists
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.Claude)
      assert.equals("Run Claude with a prompt", commands.Claude.definition)
    end)
    
    it("should accept configuration options", function()
      -- Just verify setup doesn't error with valid config
      claude_code.setup({
        timeout = 90000,
        split_direction = "vertical",
        output_format = "text",
        show_metadata = true,
        debug = true,
        allowed_tools = "Bash(npm install),Edit",
        disallowed_tools = {"Bash(git commit)", "Write"}
      })
    end)
    
    it("should validate timeout configuration", function()
      assert.has_error(function()
        claude_code.setup({
          timeout = -1000
        })
      end, "Timeout must be a positive number")
    end)
  end)
  
  describe("claude_command", function()
    it("should show error when no arguments provided", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, {msg = msg, level = level})
      end
      
      claude_code.claude_command("", {})
      
      assert.equals(1, #messages)
      assert.equals("Usage: :Claude <prompt>", messages[1].msg)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
      
      vim.notify = original_notify
    end)
    
    it("should trim whitespace from arguments", function()
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, {msg = msg, level = level})
      end
      
      claude_code.claude_command("   ", {})
      
      assert.equals(1, #messages)
      assert.equals("Usage: :Claude <prompt>", messages[1].msg)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
      
      vim.notify = original_notify
    end)
    
    it("should work with visual selection", function()
      -- Setup a buffer with some content
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "function test()",
        "  return 42",
        "end"
      })
      
      -- Mock visual selection positions
      local original_getpos = vim.fn.getpos
      vim.fn.getpos = function(mark)
        if mark == "'<" then
          return {0, 1, 1, 0}  -- Start of first line
        elseif mark == "'>" then
          return {0, 3, 4, 0}  -- End of third line
        end
        return {0, 0, 0, 0}
      end
      
      -- Mock executable and run
      local original_executable = vim.fn.executable
      vim.fn.executable = function() return 1 end
      
      local messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(messages, {msg = msg, level = level})
      end
      
      -- Simulate visual mode command with prompt
      claude_code.claude_command("explain this code", {range = 2})
      
      -- Should see "Running Claude..." message
      assert.is_true(#messages > 0)
      local found_running = false
      for _, msg in ipairs(messages) do
        if msg.msg == "Running Claude..." then
          found_running = true
          break
        end
      end
      assert.is_true(found_running)
      
      -- Cleanup
      vim.fn.getpos = original_getpos
      vim.fn.executable = original_executable
      vim.notify = original_notify
    end)
  end)
  
  describe("run", function()
    it("should check if claude is executable", function()
      local original_executable = vim.fn.executable
      vim.fn.executable = function(cmd)
        return 0
      end
      
      assert.has_error(function()
        claude_code.run("test prompt")
      end, "Claude CLI not found. Please install from https://claude.ai/code")
      
      vim.fn.executable = original_executable
    end)
    
    it("should include tool options in command", function()
      -- Setup with tool restrictions
      claude_code.setup({
        allowed_tools = "Bash,Edit",
        disallowed_tools = {"Write", "Delete"}
      })
      
      -- Mock executable
      local original_executable = vim.fn.executable
      vim.fn.executable = function() return 1 end
      
      -- Mock vim.system to capture the command
      local captured_cmd = nil
      local original_system = vim.system
      if vim.system then
        vim.system = function(cmd, opts)
          captured_cmd = cmd
          return {
            wait = function()
              return {
                code = 0,
                stdout = vim.json.encode({
                  type = "result",
                  subtype = "success",
                  result = "Test",
                  session_id = "test"
                })
              }
            end
          }
        end
      else
        -- Mock vim.fn.system for older Neovim
        local original_fn_system = vim.fn.system
        vim.fn.system = function(cmd_str)
          -- Extract command from string (basic parsing)
          captured_cmd = {"claude"}
          for part in cmd_str:gmatch("%S+") do
            table.insert(captured_cmd, part:gsub("^'(.+)'$", "%1"))
          end
          return vim.json.encode({
            type = "result",
            subtype = "success",
            result = "Test",
            session_id = "test"
          })
        end
        vim.fn.system = original_fn_system
      end
      
      -- Run command
      claude_code.run("test")
      
      -- Verify command includes tool options
      if captured_cmd then
        local found_allowed = false
        local found_disallowed = false
        for i, arg in ipairs(captured_cmd) do
          if arg == "--allowedTools" then
            found_allowed = true
            assert.equals("Bash,Edit", captured_cmd[i + 1])
          elseif arg == "--disallowedTools" then
            found_disallowed = true
            assert.equals("Write,Delete", captured_cmd[i + 1])
          end
        end
        assert.is_true(found_allowed, "Should include --allowedTools")
        assert.is_true(found_disallowed, "Should include --disallowedTools")
      end
      
      -- Cleanup
      vim.fn.executable = original_executable
      if original_system then
        vim.system = original_system
      end
    end)
  end)
end)