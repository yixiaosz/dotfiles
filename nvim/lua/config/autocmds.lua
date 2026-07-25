-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Highlight characters past column 80 (except markdown)
-- Original dark-theme color: #592929; light-theme color: #FCE1DC
local function set_overlength_hl()
  local bg = vim.o.background == "light" and "#FCE1DC" or "#592929"
  vim.api.nvim_set_hl(0, "OverLength", { bg = bg })
end
set_overlength_hl()

local column_limit = vim.api.nvim_create_augroup("ColumnLimit", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FileType" }, {
  group = column_limit,
  callback = function()
    if vim.bo.filetype == "markdown" then
      vim.cmd([[match OverLength /none/]])
    else
      vim.cmd([[match OverLength /\%81v.*/]])
    end
  end,
})

-- Re-apply the highlight after a colorscheme change (also re-evaluates light/dark)
vim.api.nvim_create_autocmd("ColorScheme", {
  group = column_limit,
  callback = set_overlength_hl,
})

-- Skeleton file for new Java programs, with class name substituted
vim.api.nvim_create_autocmd("BufNewFile", {
  group = vim.api.nvim_create_augroup("JavaSkeleton", { clear = true }),
  pattern = "*.java",
  callback = function()
    vim.cmd("0r ~/dotfiles/java.skeleton")
    vim.cmd([[%s/ClassName/\=expand('%:t:r')/g]])
  end,
})
