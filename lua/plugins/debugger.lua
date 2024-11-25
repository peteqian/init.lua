return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" })

      dap.adapters.node2 = {
        type = "executable",
        command = "node",
        args = { vim.fn.stdpath("data") .. "/mason/packages/node-debug2-adapter/out/src/nodeDebug.js" },
      }

      dap.configurations.typescript = {
        {
          name = "Launch TypeScript",
          type = "node2",
          request = "launch",
          program = "${file}",
          cwd = vim.fn.getcwd(),
          sourceMaps = true,
          protocol = "inspector",
          outFiles = { vim.fn.getcwd() .. "/dist/**/*.js" },
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          runtimeExecutable = "node",
          runtimeArgs = {
            "--require",
            "ts-node/register",
            "--require",
            "tsconfig-paths/register",
          },
          console = "integratedTerminal",
        },
      }

      -- Setup UI in bottom split
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "dap-repl",
        callback = function()
          vim.api.nvim_command("wincmd J") -- Move to bottom split
          vim.api.nvim_win_set_height(0, 10) -- Set height to 10 lines
        end,
      })
    end,
  },
}
