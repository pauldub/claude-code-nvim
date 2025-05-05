-- Claude Code templates for different AI operations
-- This module provides templates that can be customized by users

local M = {}

-- Get user config directory for optional custom templates
local function get_user_template_dir()
	local config_dir = vim.fn.stdpath("config")
	return vim.fn.expand(config_dir .. "/templates/claude-code")
end

-- Load a custom template if it exists, otherwise return the default
local function load_template(template_name, default_template)
	local template_dir = get_user_template_dir()
	local template_file = template_dir .. "/" .. template_name .. ".tpl"

	-- Try to read custom template
	local f = io.open(template_file, "r")
	if f then
		local content = f:read("*all")
		f:close()
		return content
	end

	-- Return default template if no custom one exists
	return default_template
end

-- Default templates
local default_templates = {}

default_templates.commit = [[
I'd like you to generate a high-quality git commit message for the provided code and `git diff`. Analyze the open tabs and the terminal output to understand the purpose and functionality.

The git commit should adhere to these points:

1. Concise Subject: Short and informative subject line, less than 50 characters.
2. Descriptive Body: Optional summary of 1 to 2 sentences, wrapping at 72 characters.
3. Use Imperative Mood: For example, "Fix bug" instead of "Fixed bug" or "Fixes bug."
4. Capitalize the Subject: First letter of the subject should be capitalized.
5. No Period at the End: Subject line does not end with a period.
7. Separate Subject From Body With a Blank Line: If using a body, leave one blank line after the subject.
8. Follow lightly conventional commit conventions with the tags `feat/fix/chore/refactor/spec`.

Write the content in Markdown format. Use your analysis of the diff to generate a short, accurate and helpful commit message.

Feel free to infer reasonable details if needed, but try to stick to what can be determined from the diff itself. Let me know if you have any other questions as you're writing!

Git diff:

{{diff}}
]]

default_templates.pr = [[
Write a PR description for these changes, following this template:

Template

  # Title of the pull request
  
  ## Description
  
  Describe the changes that were introduced and why they were introduced in one or two simple phrases. Do not invent things like "improving the overall performance" and such bullshit.

  ## Changes
  
  List the most relevant changes in a bullet point list. Do not list small irrelevant changes. Ignore this section if its fully redundant with the description.

  ## Tests
  
  Describe how the changes are tested in a simple phrase. If there are many tests introduced, you can list the main one as a bullet point list. Ignore this section if no specific tests are required.
   
Changes:
  {{changes}}

Output a single markdown codeblock properly escaping the codeblocks it contains.
]]

default_templates.review = [[
You are a senior developer. Your job is to do a thorough code review of this code.
You should write it up and output markdown. Include line numbers, and contextual info.
Your code review will be passed to another teammate, so be thorough.
Think deeply before writing the code review. Review every part, and don't hallucinate.

File path: {{filepath}}
File type: {{filetype}}

Code to review:
{{code}}
]]

default_templates.debug = [[
Analyze the following code and error message. Identify the likely cause of the error and suggest solutions to fix it.

File path: {{filepath}}
File type: {{filetype}}

Code:
{{code}}

Error:
{{error}}
]]

default_templates.explain = [[
Explain what this code does, including its purpose, functionality, and any notable patterns or techniques used.
Be thorough but concise, focusing on what's most important for a developer to understand:

File path: {{filepath}}
File type: {{filetype}}

{{code}}
]]

default_templates.refactor = [[
Refactor this code to improve its readability, efficiency, and maintainability.
Keep the same functionality but make it better. Present the refactored version and explain your key changes:

File path: {{filepath}}
File type: {{filetype}}

{{code}}
]]

default_templates.test = [[
Generate comprehensive test cases for the following code. Cover edge cases, error conditions, and normal operation:

File path: {{filepath}}
File type: {{filetype}}

{{code}}
]]

default_templates.codebase = [[
I'm looking at a codebase and want you to give me a high-level overview.

Please analyze:
1. The main architecture patterns
2. Key components and their relationships
3. The overall organization of files and directories

Start by looking at the project structure and key files like package.json, Cargo.toml, 
or other dependency management files to understand the tech stack.

Be concise but thorough, focusing on what's most important for a developer to understand quickly.
]]

-- Create metatable for lazy-loading templates and supporting custom templates
local mt = {
	__index = function(t, k)
		-- Check if we have a default template
		if default_templates[k] then
			-- Load template (possibly custom)
			local template = load_template(k, default_templates[k])

			-- Cache the template
			rawset(t, k, template)

			return template
		end
		return nil
	end,
}

setmetatable(M, mt)

-- Function to create custom template directory if it doesn't exist
function M.ensure_template_dir()
	local template_dir = get_user_template_dir()

	-- Check if directory exists
	if vim.fn.isdirectory(template_dir) == 0 then
		-- Create directory
		local ok, err = pcall(vim.fn.mkdir, template_dir, "p")
		if not ok then
			vim.notify("Failed to create template directory: " .. err, vim.log.levels.ERROR)
			return false
		end
		return true
	end

	return true
end

-- Function to save a custom template
function M.save_custom_template(name, content)
	-- Ensure template directory exists
	if not M.ensure_template_dir() then
		return false
	end

	local template_dir = get_user_template_dir()
	local template_file = template_dir .. "/" .. name .. ".tpl"

	-- Write template to file
	local f = io.open(template_file, "w")
	if not f then
		vim.notify("Failed to create custom template file", vim.log.levels.ERROR)
		return false
	end

	f:write(content)
	f:close()

	-- Clear cached template to load the new one
	rawset(M, name, nil)

	vim.notify("Saved custom template: " .. name, vim.log.levels.INFO)
	return true
end

-- Function to edit a template
function M.edit_template(name)
	-- Check if template exists
	if not default_templates[name] then
		vim.notify("Template not found: " .. name, vim.log.levels.ERROR)
		return
	end

	-- Ensure template directory exists
	M.ensure_template_dir()

	local template_dir = get_user_template_dir()
	local template_file = template_dir .. "/" .. name .. ".tpl"

	-- If custom template doesn't exist, create it from default
	local f = io.open(template_file, "r")
	if not f then
		f = io.open(template_file, "w")
		if f then
			f:write(default_templates[name])
			f:close()
		else
			vim.notify("Failed to create template file", vim.log.levels.ERROR)
			return
		end
	else
		f:close()
	end

	-- Open template for editing
	vim.cmd("edit " .. vim.fn.fnameescape(template_file))
end

-- List all available templates
function M.list_templates()
	local templates = {}

	-- Add default templates
	for name, _ in pairs(default_templates) do
		table.insert(templates, name)
	end

	-- Add any custom templates not in defaults
	local template_dir = get_user_template_dir()
	if vim.fn.isdirectory(template_dir) == 1 then
		local custom_templates = vim.fn.glob(template_dir .. "/*.tpl")
		for _, file in ipairs(vim.fn.split(custom_templates, "\n")) do
			local name = vim.fn.fnamemodify(file, ":t:r")
			if not vim.tbl_contains(templates, name) then
				table.insert(templates, name)
			end
		end
	end

	return templates
end

-- Reset a custom template to default
function M.reset_template(name)
	-- Check if template exists in defaults
	if not default_templates[name] then
		vim.notify("Default template not found: " .. name, vim.log.levels.ERROR)
		return false
	end

	local template_dir = get_user_template_dir()
	local template_file = template_dir .. "/" .. name .. ".tpl"

	-- Remove custom template if it exists
	os.remove(template_file)

	-- Clear cached template
	rawset(M, name, nil)

	vim.notify("Reset template to default: " .. name, vim.log.levels.INFO)
	return true
end

return M
