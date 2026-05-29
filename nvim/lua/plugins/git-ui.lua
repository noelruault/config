return {
  dir = vim.fn.stdpath("config") .. "/git-ui.nvim",
  name = "git-ui",
  keys = {
    { "<leader>gg", function() require("git-ui").toggle() end, desc = "Git UI" },
  },
  opts = {
    -- Override defaults here, e.g.:
    -- layout = { status_width = 50 },
    -- keymaps = { open = "<leader>gs" },
  },
  config = function(_, opts)
    require("git-ui").setup(opts)
  end,
}
