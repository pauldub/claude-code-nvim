-- Minimal init for testing

-- Add current plugin to runtimepath
vim.opt.rtp:append('.')

-- Set up plenary (assumed to be installed)
vim.cmd [[runtime! plugin/plenary.vim]]