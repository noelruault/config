return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    indent = {
      enabled = true,
      indent = {
        char = "▏",
        hl = "SnacksIndentDim",
        only_scope = false,
        only_current = false,
      },
      scope = {
        enabled = true,
        char = "▏",
        hl = "SnacksIndentScopeLight",
        underline = false,
        only_current = false,
      },
      chunk = { enabled = false },
      animate = { enabled = false },
    },
  },
  init = function()
    local function set_hl()
      vim.api.nvim_set_hl(0, "SnacksIndentDim",        { fg = "#3a3a3a" })
      vim.api.nvim_set_hl(0, "SnacksIndentScopeLight", { fg = "#6a6a6a" })
    end
    set_hl()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
  end,
}
