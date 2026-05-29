return {
  -- In-buffer markdown rendering (headings, code blocks, tables, checkboxes).
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
  },

  -- Live browser preview with :MarkdownPreviewToggle.
  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    -- Load the plugin onto rtp before building so its autoload functions exist
    -- (otherwise E117: Unknown function: mkdp#util#install). install() pulls a
    -- prebuilt server binary via node, so yarn is not required.
    build = function()
      vim.cmd([[Lazy load markdown-preview.nvim]])
      vim.fn["mkdp#util#install"]()
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview", ft = "markdown" },
    },
  },
}
