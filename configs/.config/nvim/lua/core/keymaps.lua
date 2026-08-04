local map = vim.keymap.set

map("n", ";",           ":",                                        { desc = "Command mode", noremap = true })
map("n", "<Esc>",       "<cmd>noh<CR>",                             { desc = "Clear search highlight" })
map("n", "<C-s>",       "<cmd>w<CR>",                               { desc = "Save file" })
map("i", "<C-s>",       "<Esc><cmd>w<CR>",                          { desc = "Save file" })
map("n", "<leader>q",   "<cmd>q<CR>",                               { desc = "Quit" })
map("n", "<leader>Q",   "<cmd>qa!<CR>",                             { desc = "Force quit all" })

map("n", "<C-h>",       "<C-w>h",                                   { desc = "Window left" })
map("n", "<C-l>",       "<C-w>l",                                   { desc = "Window right" })
map("n", "<C-j>",       "<C-w>j",                                   { desc = "Window down" })
map("n", "<C-k>",       "<C-w>k",                                   { desc = "Window up" })

map("n", "<Tab>",       "<cmd>bnext<CR>",                           { desc = "Next buffer" })
map("n", "<S-Tab>",     "<cmd>bprev<CR>",                           { desc = "Prev buffer" })
map("n", "<leader>x",   "<cmd>bd<CR>",                              { desc = "Close buffer" })
map("n", "<leader>b",   "<cmd>enew<CR>",                            { desc = "New buffer" })

map("i", "<C-h>",       "<Left>",                                   { desc = "Move left" })
map("i", "<C-l>",       "<Right>",                                  { desc = "Move right" })
map("i", "<C-j>",       "<Down>",                                   { desc = "Move down" })
map("i", "<C-k>",       "<Up>",                                     { desc = "Move up" })

map("v", "J",           ":m '>+1<CR>gv=gv",                        { desc = "Move line down" })
map("v", "K",           ":m '<-2<CR>gv=gv",                        { desc = "Move line up" })

map("n", "<C-d>",       "<C-d>zz",                                  { desc = "Scroll down centered" })
map("n", "<C-u>",       "<C-u>zz",                                  { desc = "Scroll up centered" })

map("n", "<C-n>",       "<cmd>NvimTreeToggle<CR>",                  { desc = "Toggle file tree" })
map("n", "<leader>e",   "<cmd>NvimTreeFocus<CR>",                   { desc = "Focus file tree" })

map("n", "<leader>ff",  "<cmd>Telescope find_files<CR>",            { desc = "Find files" })
map("n", "<leader>fw",  "<cmd>Telescope live_grep<CR>",             { desc = "Live grep" })
map("n", "<leader>fb",  "<cmd>Telescope buffers<CR>",              { desc = "Buffers" })
map("n", "<leader>fh",  "<cmd>Telescope help_tags<CR>",            { desc = "Help tags" })
map("n", "<leader>fo",  "<cmd>Telescope oldfiles<CR>",             { desc = "Recent files" })

map("n", "<leader>gc",  "<cmd>Telescope git_commits<CR>",          { desc = "Git commits" })
map("n", "<leader>gs",  "<cmd>Telescope git_status<CR>",           { desc = "Git status" })

map("n", "<leader>T",  function() require("core.themes").pick() end, { desc = "Switch theme" })

map("n", "<leader>th",  "<cmd>split | terminal<CR>",               { desc = "Horizontal terminal" })
map("n", "<leader>tv",  "<cmd>vsplit | terminal<CR>",              { desc = "Vertical terminal" })
map("t", "<C-x>",       "<C-\\><C-N>",                             { desc = "Exit terminal mode" })

-- Run Python file
map("n", "<leader>rr", function()
  vim.cmd("!python %")
end, { desc = "Run Python file" })
map("n", "<leader>R", function()
  vim.ui.input({ prompt = "Arguments: " }, function(args)
    if args then vim.cmd("!python % " .. args) end
  end)
end, { desc = "Run Python file with args" })

-- LSP keybinds (set per-buffer on attach)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(args)
    local b = args.buf
    local lsp = vim.lsp.buf
    local diag = vim.diagnostic
    local bind = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = b, desc = desc })
    end

    bind("n", "gd",             lsp.definition,         "Go to definition")
    bind("n", "gD",             lsp.declaration,        "Go to declaration")
    bind("n", "gr",             lsp.references,         "Find references")
    bind("n", "gi",             lsp.implementation,     "Go to implementation")
    bind("n", "K",              lsp.hover,              "Hover documentation")
    bind("n", "<leader>ca",     lsp.code_action,        "Code action")
    bind("n", "<leader>rn",     lsp.rename,             "Rename symbol")
    bind("n", "[d",             diag.goto_prev,         "Previous diagnostic")
    bind("n", "]d",             diag.goto_next,         "Next diagnostic")
    bind("n", "<leader>ld",     diag.open_float,        "Line diagnostics")
    bind("n", "<leader>lw",     require("telescope.builtin").lsp_workspace_symbols, "Workspace symbols")
  end,
})

-- Test keybinds (neotest)
local nt = require("neotest")
map("n", "<leader>tf", function() nt.run.run() end,                          { desc = "Run nearest test" })
map("n", "<leader>tl", function() nt.run.run_last() end,                     { desc = "Run last test" })
map("n", "<leader>ts", function() nt.run.run({ suite = true }) end,          { desc = "Run test suite" })
map("n", "<leader>ta", function() nt.run.run(vim.fn.expand("%:p")) end,      { desc = "Run all tests in file" })
map("n", "<leader>to", function() nt.output.open({ enter = true }) end,      { desc = "Toggle test output" })

-- Docstring (neogen)
map("n", "<leader>ng", function() require("neogen").generate() end,          { desc = "Generate docstring" })

-- Debug keybinds (nvim-dap)
local dap = require("dap")
map("n", "<leader>db", dap.toggle_breakpoint,                                 { desc = "Toggle breakpoint" })
map("n", "<leader>dc", dap.continue,                                          { desc = "Continue / start" })
map("n", "<leader>do", dap.step_over,                                         { desc = "Step over" })
map("n", "<leader>di", dap.step_into,                                         { desc = "Step into" })
map("n", "<leader>dt", dap.terminate,                                         { desc = "Terminate" })
map("n", "<leader>du", function() require("dapui").toggle() end,              { desc = "Toggle debug UI" })