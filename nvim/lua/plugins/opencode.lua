return {
  "NickvanDyke/opencode.nvim",
  keys = {
    { "<C-a>", function() require("opencode").ask("@this: ", { submit = true }) end, mode = { "n", "x" }, desc = "Ask opencode…" },
    { "<C-x>", function() require("opencode").select() end, mode = { "n", "x" }, desc = "Execute opencode action…" },
    { "<leader>ot", function() require("opencode").toggle() end, mode = { "n", "t" }, desc = "Toggle opencode" },
    { "go", function() return require("opencode").operator("@this ") end, mode = { "n", "x" }, expr = true, desc = "Add range to opencode" },
    { "goo", function() return require("opencode").operator("@this ") .. "_" end, mode = "n", expr = true, desc = "Add line to opencode" },
    { "<S-C-u>", function() require("opencode").command("session.half.page.up") end, desc = "Scroll opencode up" },
    { "<S-C-d>", function() require("opencode").command("session.half.page.down") end, desc = "Scroll opencode down" },
  },
  dependencies = {
    {
      "folke/snacks.nvim",
      lazy = true,
      opts = { input = {}, picker = {}, terminal = {} },
    },
  },
  init = function()
    -- opencode integration relies on autoread to refresh changed buffers.
    vim.o.autoread = true
    -- Keep the user's "+/-" rebinds out of the lazy-load path.
    vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor", noremap = true })
    vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement under cursor", noremap = true })
  end,
  config = function()
    vim.g.opencode_opts = {}
  end,
}
