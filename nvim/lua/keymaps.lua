vim.g.mapleader = " "      -- Set Space as leader key before any mappings

local map = vim.keymap.set

map("n", "<C-h>", "<C-w><C-h>", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move to down window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move to up window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move to right window" })
