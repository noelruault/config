return {
  "edmondop/cedar.nvim",
  ft = { "cedar", "cedarschema" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("cedar").setup()
  end,
}
