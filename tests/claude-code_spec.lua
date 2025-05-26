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
        debug = true
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
      
      claude_code.claude_command("")
      
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
      
      claude_code.claude_command("   ")
      
      assert.equals(1, #messages)
      assert.equals("Usage: :Claude <prompt>", messages[1].msg)
      assert.equals(vim.log.levels.ERROR, messages[1].level)
      
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
  end)
end)