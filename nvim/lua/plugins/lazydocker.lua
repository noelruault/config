return {
  "crnvl96/lazydocker.nvim",
  keys = {
    {
      "<leader>ld",
      function() require("lazydocker").toggle({ engine = "docker" }) end,
      mode = { "n", "t" },
      desc = "LazyDocker",
    },
  },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    window = {
      settings = {
        width = 0.8,
        height = 0.8,
        border = "rounded",
        relative = "editor",
      },
    },
  },
}
