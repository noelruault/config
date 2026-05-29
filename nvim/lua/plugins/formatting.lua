return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = { "ConformInfo", "Format" },
  keys = {
    {
      "<leader>cf",
      function() require("conform").format() end,
      desc = "Format buffer (conform)",
    },
  },
  opts = {
    default_format_opts = { lsp_format = "never" },
    formatters_by_ft = {
      rust = { "rustfmt" },
      go = { "gofmt" },
      cs = { "csharpier" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      json = { "prettier" },
    },
  },
}
