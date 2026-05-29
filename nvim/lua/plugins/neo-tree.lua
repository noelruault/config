return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  cmd = "Neotree",
  keys = {
    { "<C-n>", "<cmd>Neotree filesystem reveal left<CR>", desc = "NeoTree" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  init = function()
    -- Disable netrw entirely; neo-tree's debounced hijack races with file open.
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    -- When nvim is launched with a directory argument, open neo-tree explicitly
    -- (replaces the netrw hijack path, which was creating phantom buffers).
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        local arg = vim.fn.argv(0)
        if type(arg) == "string" and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
          vim.schedule(function()
            vim.cmd("Neotree filesystem reveal left dir=" .. vim.fn.fnameescape(arg))
          end)
        end
      end,
    })
  end,
  opts = {
    filesystem = {
      hijack_netrw_behavior = "disabled",
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_by_name = {},
        never_show = {},
      },
    },
  },
}
