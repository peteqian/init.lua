return {
  {
    dir = vim.fn.stdpath("config") .. "/lua/custom/vscode-launch",
    name = "vscode-launch",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "mfussenegger/nvim-dap",
    },
    config = function()
      require("custom.vscode-launch").setup()
    end,
  },
}
