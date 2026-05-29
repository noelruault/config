return {
  "petertriho/nvim-scrollbar",
  event = "VeryLazy",
  dependencies = { "kevinhwang91/nvim-hlslens", "lewis6991/gitsigns.nvim" },
  config = function()
    require("scrollbar").setup({
      show = true,
      hide_if_all_visible = true,
    })
    require("scrollbar.handlers.diagnostic").setup()
    require("scrollbar.handlers.search").setup()
    require("scrollbar.handlers.gitsigns").setup()
  end,
}
