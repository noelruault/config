return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = { theme = "monokai-pro" },
    sections = {
      lualine_c = { { "filename", path = 1 } },
    },
    inactive_sections = {
      lualine_c = { { "filename", path = 1 } },
    },
  },
}
