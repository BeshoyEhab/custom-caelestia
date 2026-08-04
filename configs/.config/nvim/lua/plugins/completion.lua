return {
  {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },

  {
    "zbirenbaum/copilot.lua",
    cmd   = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        panel      = { enabled = false },
        filetypes  = {
          python     = true,
          lua        = true,
          bash       = true,
          javascript = true,
          typescript = true,
          html       = true,
          css        = true,
          markdown   = true,
        },
      })
    end,
  },

  {
    "zbirenbaum/copilot-cmp",
    dependencies = { "zbirenbaum/copilot.lua" },
    event        = "InsertEnter",
    build        = function()
      local f = vim.fn.stdpath("data") .. "/lazy/copilot-cmp/lua/copilot_cmp/source.lua"
      local content = vim.fn.readfile(f)
      for i, line in ipairs(content) do
        content[i] = line:gsub("self%.client%.is_stopped%(%)", "self.client:is_stopped()")
      end
      vim.fn.writefile(content, f)
    end,
    config       = function()
      require("copilot_cmp").setup()
      vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })
        end,
      })
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    event        = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
      "L3MON4D3/LuaSnip",
      "zbirenbaum/copilot-cmp",
      "onsails/lspkind.nvim",
    },
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },

        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },

        formatting = {
          format = lspkind.cmp_format({
            mode          = "symbol_text",
            maxwidth      = 50,
            ellipsis_char = "...",
            symbol_map    = { Copilot = "" },
            before = function(entry, item)
              if entry.source.name == "copilot" then
                item.kind_hl_group = "CmpItemKindCopilot"
              end
              return item
            end,
          }),
        },

        sources = cmp.config.sources({
          { name = "copilot",  priority = 1000 },
          { name = "nvim_lsp", priority = 750 },
          { name = "luasnip",  priority = 500 },
        }, {
          { name = "buffer", priority = 250 },
          { name = "path",   priority = 200 },
        }),

        sorting = {
          priority_weight = 2,
          comparators = {
            require("copilot_cmp.comparators").prioritize,
            cmp.config.compare.offset,
            cmp.config.compare.exact,
            cmp.config.compare.score,
            cmp.config.compare.recently_used,
            cmp.config.compare.locality,
            cmp.config.compare.kind,
            cmp.config.compare.length,
            cmp.config.compare.order,
          },
        },

        mapping = cmp.mapping.preset.insert({
          ["<C-p>"]     = cmp.mapping.select_prev_item(),
          ["<C-n>"]     = cmp.mapping.select_next_item(),
          ["<C-d>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.close(),
          ["<CR>"]      = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Insert,
            select   = false,
          }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = true })
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),

        experimental = { ghost_text = false },
      })
    end,
  },
}
