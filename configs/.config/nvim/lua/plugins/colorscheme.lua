return {
  {
    "catppuccin/nvim",
    name     = "catppuccin",
    priority = 1000,
    config   = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = false,
        integrations = {
          nvimtree   = true,
          telescope  = { enabled = true },
          gitsigns   = true,
          cmp        = true,
          which_key  = true,
          treesitter = true,
          bufferline = true,
          indent_blankline = { enabled = true },
          native_lsp = {
            enabled = true,
            underlines = {
              errors      = { "undercurl" },
              hints       = { "undercurl" },
              warnings    = { "undercurl" },
              information = { "undercurl" },
            },
          },
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "folke/tokyonight.nvim",
    priority = 999,
    config   = function()
      require("tokyonight").setup({
        transparent = false,
      })
    end,
  },

  {
    "rose-pine/neovim",
    name = "rose-pine",
    priority = 998,
    config = function()
      require("rose-pine").setup({ variant = "auto" })
    end,
  },

  {
    "sainnhe/everforest",
    priority = 998,
    config = function()
      vim.g.everforest_background = "hard"
    end,
  },

  {
    "ellisonleao/gruvbox.nvim",
    priority = 998,
    config = function()
      require("gruvbox").setup({
        contrast = "hard",
        transparent = false,
      })
    end,
  },

  {
    "shaunsingh/nord.nvim",
    priority = 998,
  },
}
