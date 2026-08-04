return {
  {
    "nvim-treesitter/nvim-treesitter",
    build  = ":TSUpdate",
    event  = { "BufReadPost", "BufNewFile" },
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc",
        "python", "bash",
        "html", "css", "javascript", "typescript", "tsx",
        "json", "yaml", "toml",
        "c", "cpp", "rust", "go",
        "markdown", "markdown_inline",
      },
      highlight    = { enable = true },
      indent       = { enable = true },
      auto_install = true,
    },
  },
}
