local M = {}

local config = require("git-ui.config")
local highlights = require("git-ui.highlights")
local ui = require("git-ui.ui")
local panel = require("git-ui.panel")

function M.setup(opts)
  config.setup(opts)
  highlights.setup()

  -- Re-apply highlights on colorscheme change
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      highlights.setup()
    end,
  })
end

--- Set up buffer-local keymaps for the status panel.
local function setup_keymaps()
  local ui_state = ui.get_state()
  local buf = ui_state.status_buf
  if not buf then return end

  local km = config.options.keymaps
  local function map(key, fn, desc)
    vim.keymap.set("n", key, fn, { buffer = buf, desc = desc, silent = true, nowait = true })
  end

  map(km.stage, panel.stage_file, "Stage file")
  map(km.unstage, panel.unstage_file, "Unstage file")
  map(km.discard, panel.discard_file, "Discard file changes")
  map(km.resolve_ours, panel.resolve_conflict_ours, "Accept current changes")
  map(km.resolve_theirs, panel.resolve_conflict_theirs, "Accept incoming changes")
  map(km.resolve_both, panel.resolve_conflict_both, "Accept both changes")
  map(km.mark_resolved, panel.mark_conflict_resolved, "Mark conflict resolved")
  map(km.stage_hunk, panel.stage_hunk, "Stage hunk")
  map(km.unstage_hunk, panel.unstage_hunk, "Unstage hunk")
  map(km.commit, panel.do_commit, "Commit")
  map(km.push, panel.do_push, "Push")
  map(km.pull, panel.do_pull, "Pull")
  map(km.branch, panel.show_branches, "Switch branch")
  map(km.new_branch, panel.create_branch, "Create branch")
  map(km.refresh, function() panel.refresh_current() end, "Refresh")
  map(km.close, function() M.close() end, "Close")
  map("<Esc>", function() M.close() end, "Close")
  map(km.toggle_section, function() panel.on_enter() end, "Enter / toggle / drill")
  map(km.log, function() panel.show_log() end, "History (commit log)")
  map(km.drill_out, function() panel.drill_out() end, "Back")

  -- Stage all / Unstage all
  map("S", function()
    require("git-ui.git").stage_all(function(ok)
      if ok then panel.refresh() end
    end)
  end, "Stage all")
  map("U", function()
    require("git-ui.git").unstage_all(function(ok)
      if ok then panel.refresh() end
    end)
  end, "Unstage all")

  -- Change navigation (works from any panel)
  map("]c", function() ui.next_change() end, "Next change")
  map("[c", function() ui.prev_change() end, "Previous change")

  -- Sidebar resize
  map("<", function()
    ui.resize_status(-3)
    panel.render()
  end, "Shrink sidebar")
  map(">", function()
    ui.resize_status(3)
    panel.render()
  end, "Grow sidebar")

  -- Tab to jump to diff panel
  map(km.focus_diff, function()
    ui.focus_diff()
  end, "Focus diff")

  -- Debounced diff preview on cursor movement
  local timer = nil
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if timer then
        pcall(vim.fn.timer_stop, timer)
      end
      timer = vim.fn.timer_start(50, function()
        vim.schedule(function()
          timer = nil
          panel.update_diff_dispatcher()
        end)
      end)
    end,
  })
end

--- Set up keymaps for a diff buffer.
local function setup_diff_buf_keymaps(buf)
  if not buf then return end

  local km = config.options.keymaps
  local function map(key, fn, desc)
    vim.keymap.set("n", key, fn, { buffer = buf, desc = desc, silent = true, nowait = true })
  end

  map(km.close, function() M.close() end, "Close")
  map("<Esc>", function() M.close() end, "Close")
  map(km.focus_diff, function() ui.focus_status() end, "Back to status")
  map(km.resolve_ours, panel.resolve_conflict_ours, "Accept current changes")
  map(km.resolve_theirs, panel.resolve_conflict_theirs, "Accept incoming changes")
  map(km.resolve_both, panel.resolve_conflict_both, "Accept both changes")
  map(km.mark_resolved, panel.mark_conflict_resolved, "Mark conflict resolved")
  map(km.conflict_undo, panel.undo_conflict, "Undo conflict resolution")
  map(km.conflict_redo, panel.redo_conflict, "Redo conflict resolution")
  map(km.stage_hunk, panel.stage_hunk, "Stage hunk")
  map(km.unstage_hunk, panel.unstage_hunk, "Unstage hunk")
  map("]c", function() ui.next_change() end, "Next change")
  map("[c", function() ui.prev_change() end, "Previous change")

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function() ui.update_scrollbar() end,
  })
end

--- Set up keymaps for all diff panels.
local function setup_diff_keymaps()
  local ui_state = ui.get_state()
  setup_diff_buf_keymaps(ui_state.diff_buf)
  if ui_state.diff_right_buf then
    setup_diff_buf_keymaps(ui_state.diff_right_buf)
  end
end

function M.open()
  if ui.is_open() then return end

  if not require("git-ui.git").is_repo() then
    vim.notify("Not a git repository", vim.log.levels.ERROR)
    return
  end

  ui.open(config.options.layout.status_width)
  setup_keymaps()
  setup_diff_keymaps()
  ui.setup_scroll_sync()
  ui.setup_mouse_resize()

  -- Global scroll tracking for scrollbar (cleaned up on close)
  local augroup = vim.api.nvim_create_augroup("git-ui-scroll", { clear = true })
  vim.api.nvim_create_autocmd({ "WinScrolled", "VimResized" }, {
    group = augroup,
    callback = function()
      if ui.is_open() then
        ui.update_scrollbar()
      end
    end,
  })

  panel.refresh(function()
    panel.cursor_to_first_file()
  end)
end

function M.close()
  pcall(vim.api.nvim_del_augroup_by_name, "git-ui-scroll")
  -- Remove global mouse resize keymaps
  pcall(vim.keymap.del, "n", "<LeftMouse>")
  pcall(vim.keymap.del, "n", "<LeftDrag>")
  pcall(vim.keymap.del, "n", "<LeftRelease>")
  ui.close()
end

function M.toggle()
  if ui.is_open() then
    M.close()
  else
    M.open()
  end
end

return M
