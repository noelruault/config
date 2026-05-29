return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth",
  event = "InsertEnter",
  opts = {
    suggestion = {
      enabled = true,
      auto_trigger = true,
      hide_during_completion = false,
      keymap = {
        accept = false, -- bound manually below
        next = "<M-]>",
        prev = "<M-[>",
        dismiss = "<C-x>",
      },
    },
    panel = { enabled = false },
    filetypes = { markdown = true, help = true },
  },
  config = function(_, opts)
    require("copilot").setup(opts)
    local suggestion = require("copilot.suggestion")
    vim.keymap.set("i", "<C-a>", function()
      if suggestion.is_visible() then suggestion.accept() end
    end, { silent = true, desc = "Accept Copilot suggestion" })
    vim.keymap.set("i", "<C-/>", function() suggestion.next() end,
      { silent = true, desc = "Trigger Copilot suggestion" })
  end,
}
