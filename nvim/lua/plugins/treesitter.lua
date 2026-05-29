return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  lazy = false,
  build = ":TSUpdate",
  main = "nvim-treesitter.configs",
  opts = {
    ensure_installed = {
      "html", "css",
      "javascript", "typescript", "tsx", "json",
      "rust", "go", "gomod", "gosum", "zig", "lua", "c_sharp", "python",
      "markdown", "markdown_inline", "yaml", "toml",
      "bash", "dockerfile",
      "vim", "vimdoc", "regex", "query",
    },
    sync_install = false,
    auto_install = false,
    highlight = { enable = true },
    indent = { enable = true },
  },
}
