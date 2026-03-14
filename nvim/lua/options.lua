local opt = vim.opt

-- Line numbers
opt.number = true
-- opt.relativenumber = true  -- shows relative line numbers,

-- Search
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Indentation 
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true     -- auto-indent on new lines

-- Performance
opt.updatetime = 500

opt.termguicolors = true   -- enables full RGB color support in the terminal
opt.signcolumn = "yes"     -- always show the sign column 
opt.wrap = false           -- disable line wrapping
