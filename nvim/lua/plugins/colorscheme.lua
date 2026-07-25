return {
  -- add flexoki
  { "kepano/flexoki-neovim", name = "flexoki" },

  -- configure LazyVim to load flexoki light
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "flexoki-light",
    },
  },
}
