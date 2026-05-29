local M = {}

M.defaults = {
  keymaps = {
    open = "<leader>gg",
    stage = "s",
    unstage = "u",
    discard = "d",
    resolve_ours = "o",
    resolve_theirs = "i",
    resolve_both = "B",
    mark_resolved = "m",
    stage_hunk = "hs",
    unstage_hunk = "hu",
    commit = "c",
    push = "P",
    pull = "L",
    branch = "b",
    new_branch = "n",
    refresh = "r",
    close = "q",
    toggle_section = "<CR>",
    focus_diff = "<Tab>",
    conflict_undo = "u",
    conflict_redo = "<C-r>",
    log = "l",
    drill_out = "<BS>",
  },
  log = {
    limit = 300,
    show_all_branches = false,
  },
  layout = {
    status_width = 32,
    side_by_side_min_width = 120, -- min diff area width to activate SBS
  },
  icons = {
    staged = "✓",
    modified = "~",
    added = "+",
    deleted = "-",
    untracked = "?",
    renamed = "→",
    conflict = "!",
    branch = "",
    section_open = "▼",
    section_closed = "▶",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
