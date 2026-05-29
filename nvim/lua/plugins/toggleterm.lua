return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermExec" },
  keys = {
    { [[<c-\>]], desc = "Toggle terminal" },
    { "<leader>ta", desc = "Claude Code" },
    { "<leader>t1", desc = "Vertical terminal" },
    { "<leader>t2", desc = "Horizontal terminal" },
    { "<leader>tf", desc = "Floating terminal" },
  },
  opts = {
    open_mapping = [[<c-\>]],
    direction = "vertical",
    persist_mode = true,
    persist_size = true,
    size = function(term)
      if term.direction == "vertical" then
        return math.floor(vim.o.columns * 0.35)
      end
      return 20
    end,
  },
  config = function(_, opts)
    require("toggleterm").setup(opts)

    -- Terminal-only keymaps (robust on macOS)
    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "term://*toggleterm#*",
      callback = function()
        local opts = { buffer = 0, silent = true }

        -- Exit terminal mode
        vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)

        -- Safe split navigation from terminal buffers
        vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], opts)
        vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], opts)
        vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], opts)
        vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], opts)
      end,
    })

    local Terminal = require("toggleterm.terminal").Terminal

    -- Claude Code (persistent vertical terminal)
    local claude = Terminal:new({
      cmd = "claude",
      direction = "vertical",
      hidden = true,
    })

    -- Vertical shell
    local term1 = Terminal:new({
      direction = "vertical",
      hidden = true,
    })

    -- Horizontal shell
    local term2 = Terminal:new({
      direction = "horizontal",
      hidden = true,
    })

    -- Floating shell
    local floating = Terminal:new({
      direction = "float",
      hidden = true,
    })

    -- Explicit, predictable keymaps
    vim.keymap.set("n", "<leader>ta", function()
      claude:toggle()
    end, { desc = "Claude Code" })

    vim.keymap.set("n", "<leader>t1", function()
      term1:toggle()
    end, { desc = "Vertical terminal" })

    vim.keymap.set("n", "<leader>t2", function()
      term2:toggle()
    end, { desc = "Horizontal terminal" })

    vim.keymap.set("n", "<leader>tf", function()
      floating:toggle()
    end, { desc = "Floating terminal" })
  end,
}
