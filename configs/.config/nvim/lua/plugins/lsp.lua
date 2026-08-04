return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({ ui = { border = "rounded" } })
    end,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "pyright",
          "lua_ls",
          "ts_ls",
          "html",
          "cssls",
          "bashls",
        },
        automatic_installation = true,
      })
    end,
  },

  -- LSP configs using new vim.lsp.config API (nvim 0.11+)
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Python
      vim.lsp.config("pyright", { capabilities = capabilities })

      -- Lua
      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace   = { checkThirdParty = false },
            telemetry   = { enable = false },
          },
        },
      })

      -- Web / shell
      vim.lsp.config("ts_ls", { capabilities = capabilities })
      vim.lsp.config("html", { capabilities = capabilities })
      vim.lsp.config("cssls", { capabilities = capabilities })
      vim.lsp.config("bashls", { capabilities = capabilities })

      -- Enable all configured servers
      vim.lsp.enable({ "pyright", "lua_ls", "ts_ls", "html", "cssls", "bashls" })

      -- Diagnostics appearance
      vim.diagnostic.config({
        virtual_text     = true,
        signs            = true,
        underline        = true,
        update_in_insert = false,
        float            = { border = "rounded" },
      })
    end,
  },

  {
    "stevearc/conform.nvim",
    event  = "BufWritePre",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          python     = { "black", "isort" },
          lua        = { "stylua" },
          javascript = { "prettier" },
          typescript = { "prettier" },
          html       = { "prettier" },
          css        = { "prettier" },
          json       = { "prettier" },
          yaml       = { "prettier" },
          bash       = { "shfmt" },
        },
        format_on_save = {
          timeout_ms   = 500,
          lsp_fallback = true,
        },
      })
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event  = { "BufReadPost", "BufNewFile" },
    config = function()
      require("lint").linters_by_ft = {
        python = { "ruff" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
        callback = function()
          require("lint").try_lint()
        end,
      })
    end,
  },
}
