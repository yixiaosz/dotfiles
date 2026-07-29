return {
  -- add flexoki
  { "kepano/flexoki-neovim", name = "flexoki" },

  -- add everforest (light variant selected via 'background' option, medium contrast)
  {
    "neanias/everforest-nvim",
    opts = {
      background = "medium",
    },
  },

  -- configure LazyVim to load everforest light (medium contrast)
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "everforest",
    },
  },
}
