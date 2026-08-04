return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition" })
      vim.fn.sign_define("DapStopped", { text = "→", texthl = "DapStopped" })
    end,
  },
  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-python").setup("python")
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dapui").setup()
      local dap = require("dap")
      local dapui = require("dapui")
      dap.listeners.after.event_initialized["dapui"] = dapui.open
      dap.listeners.after.event_terminated["dapui"] = dapui.close
      dap.listeners.after.event_exited["dapui"] = dapui.close
    end,
  },
}
