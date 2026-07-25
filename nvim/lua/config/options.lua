-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Indent with 4 spaces (LazyVim defaults to 2)
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4

-- Plain line numbers (LazyVim defaults to relativenumber)
vim.opt.relativenumber = false

-- Disable auto format on save (toggle at runtime with <leader>uf)
vim.g.autoformat = false

-- Blinking cursor
vim.opt.guicursor:append("a:blinkon500-blinkoff500")
