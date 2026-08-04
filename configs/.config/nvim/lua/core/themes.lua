local M = {}

M.themes = {
  { name = "Catppuccin Mocha",     cmd = "catppuccin-mocha" },
  { name = "Catppuccin Macchiato", cmd = "catppuccin-macchiato" },
  { name = "Catppuccin Frappe",    cmd = "catppuccin-frappe" },
  { name = "Catppuccin Latte",     cmd = "catppuccin-latte" },
  { name = "Tokyo Night",          cmd = "tokyonight-night" },
  { name = "Tokyo Night Storm",    cmd = "tokyonight-storm" },
  { name = "Tokyo Night Moon",     cmd = "tokyonight-moon" },
  { name = "Tokyo Night Day",      cmd = "tokyonight-day" },
  { name = "Rose Pine",            cmd = "rose-pine" },
  { name = "Rose Pine Dawn",       cmd = "rose-pine-dawn" },
  { name = "Everforest Dark",      cmd = "everforest" },
  { name = "Gruvbox Dark",         cmd = "gruvbox" },
  { name = "Nord",                 cmd = "nord" },
}

-- Telescope's own highlight groups (same defaults as its plugin file), re-applied
-- after a theme change because themes run `:hi clear` which wipes them.
local telescope_highlights = {
  TelescopeSelection            = { default = true, link = "Visual" },
  TelescopeSelectionCaret       = { default = true, link = "TelescopeSelection" },
  TelescopeMultiSelection       = { default = true, link = "Type" },
  TelescopeMultiIcon            = { default = true, link = "Identifier" },
  TelescopeNormal               = { default = true, link = "Normal" },
  TelescopePreviewNormal        = { default = true, link = "TelescopeNormal" },
  TelescopePromptNormal         = { default = true, link = "TelescopeNormal" },
  TelescopeResultsNormal        = { default = true, link = "TelescopeNormal" },
  TelescopeBorder               = { default = true, link = "TelescopeNormal" },
  TelescopePromptBorder         = { default = true, link = "TelescopeBorder" },
  TelescopeResultsBorder        = { default = true, link = "TelescopeBorder" },
  TelescopePreviewBorder        = { default = true, link = "TelescopeBorder" },
  TelescopeTitle                = { default = true, link = "TelescopeBorder" },
  TelescopePromptTitle          = { default = true, link = "TelescopeTitle" },
  TelescopeResultsTitle         = { default = true, link = "TelescopeTitle" },
  TelescopePreviewTitle         = { default = true, link = "TelescopeTitle" },
  TelescopePromptCounter        = { default = true, link = "NonText" },
  TelescopeMatching             = { default = true, link = "Special" },
  TelescopePromptPrefix         = { default = true, link = "Identifier" },
  TelescopePreviewLine          = { default = true, link = "Visual" },
  TelescopePreviewMatch         = { default = true, link = "Search" },
  TelescopePreviewMessage       = { default = true, link = "TelescopePreviewNormal" },
  TelescopePreviewMessageFillchar = { default = true, link = "TelescopePreviewMessage" },
}

local function restore_telescope_highlights()
  for name, opts in pairs(telescope_highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

-- Refresh plugins that cache the active colorscheme
local function refresh()
  local ok, _ = pcall(require, "lualine")
  if ok then require("lualine").setup() end
  local ok2, _ = pcall(require, "bufferline")
  if ok2 then require("bufferline").setup() end
  vim.cmd("redrawtabline")
end

function M.apply(cmd)
  local ok, err = pcall(vim.cmd, "colorscheme " .. cmd)
  if not ok then
    print("Could not load theme: " .. err)
    return
  end
  restore_telescope_highlights()
  refresh()
end

-- Render a buffer previewing the active theme: name + color palette swatches
local function preview_theme(buf, title)
  local ns = vim.api.nvim_create_namespace("theme_preview")

  local lines = {
    "",
    string.rep(" ", math.floor((80 - #title) / 2)) .. title .. string.rep(" ", 80 - #title - math.floor((80 - #title) / 2)),
    "",
    "  Palette (real theme colors)",
    "",
  }
  for i, g in ipairs({ "String", "Number", "Function", "Keyword", "Type", "Operator", "Identifier", "Comment" }) do
    table.insert(lines, ("  %-12s %s"):format(g, ""))
    table.insert(lines, "")
  end
  table.insert(lines, "")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_add_highlight(buf, ns, "Title", 1, 0, -1)

  -- fill each swatch's fg row with the theme color, bg row with Normal bg
  for i, g in ipairs({ "String", "Number", "Function", "Keyword", "Type", "Operator", "Identifier", "Comment" }) do
    local row = 4 + (i - 1) * 2
    vim.api.nvim_buf_add_highlight(buf, ns, g, row, 2, 14)
    vim.api.nvim_buf_add_highlight(buf, ns, g, row + 1, 2, 14)
    local fg = vim.api.nvim_get_hl(0, { name = g }).fg
    local code = fg and ("#%06x"):format(fg) or "default"
    local name_row = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { name_row .. " " .. code })
    vim.api.nvim_buf_add_highlight(buf, ns, "Comment", row, 15, -1)
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function M.pick()
  local pickers   = require("telescope.pickers")
  local finders   = require("telescope.finders")
  local conf      = require("telescope.config").values
  local actions   = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local entry_maker = function(t)
    return { value = t, ordinal = t.name, display = t.name }
  end

  local original   = vim.g.colors_name or "catppuccin-mocha"
  local keep       = false

  local picker = pickers.new({}, {
    prompt_title     = "Themes",
    selection_caret  = "  ",
    entry_prefix     = "  ",
    finder           = finders.new_table({ results = M.themes, entry_maker = entry_maker }),
    sorter           = conf.generic_sorter({}),
    previewer        = require("telescope.previewers").new_buffer_previewer({
      define_preview = function(self, entry)
        M.apply(entry.value.cmd)
        local buf = self.state.bufnr
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
        preview_theme(buf, entry.value.name)
        vim.api.nvim_buf_set_option(buf, "filetype", "text")
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection then
          keep = true
          actions.close(prompt_bufnr)
          M.apply(selection.value.cmd)
        end
      end)
      return true
    end,
  })

  -- Preview on every selection change (up/down)
  local set_selection = picker.set_selection
  picker.set_selection = function(self, row)
    set_selection(self, row)
    local selection = action_state.get_selected_entry()
    if selection then
      M.apply(selection.value.cmd)
    end
  end

  -- Restore the previous theme unless one was selected
  local close_windows = picker.close_windows
  picker.close_windows = function(status)
    close_windows(status)
    if not keep then
      M.apply(original)
    end
  end

  picker:find()
end

return M