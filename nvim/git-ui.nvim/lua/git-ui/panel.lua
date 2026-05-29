local M = {}

local git = require("git-ui.git")
local ui = require("git-ui.ui")
local config = require("git-ui.config")

--- Notify that works with cmdheight=0 by temporarily showing the cmdline.
local function notify(msg, level)
  level = level or vim.log.levels.INFO
  local hl = "Normal"
  if level == vim.log.levels.ERROR then hl = "ErrorMsg"
  elseif level == vim.log.levels.WARN then hl = "WarningMsg" end
  -- Temporarily set cmdheight=1 so the message is visible
  local prev = vim.o.cmdheight
  if prev == 0 then vim.o.cmdheight = 1 end
  vim.api.nvim_echo({{ msg, hl }}, true, {})
  if prev == 0 then
    vim.defer_fn(function() vim.o.cmdheight = 0 end, 2000)
  end
end

local state = {
  mode = "status", -- "status" | "log" | "log_files"
  files = { conflicted = {}, staged = {}, changed = {}, untracked = {} },
  branch = { name = "", ahead = 0, behind = 0 },
  sections = {
    conflicted = { collapsed = false },
    staged = { collapsed = false },
    changed = { collapsed = false },
    untracked = { collapsed = false },
  },
  line_map = {},
  loading = false,
  conflict_history = {}, -- { [path] = { undo = {lines, ...}, redo = {lines, ...} } }
  log = {
    commits = {},        -- { graph, hash, short, subject, author, date, refs }
    selected = nil,      -- index of commit drilled into (log_files mode)
    files = {},          -- files of selected commit
    loading = false,
  },
}

function M.get_state()
  return state
end

local function get_status_icon(status)
  local icons = config.options.icons
  local map = {
    UU = icons.conflict,
    AA = icons.conflict,
    DD = icons.conflict,
    AU = icons.conflict,
    UA = icons.conflict,
    DU = icons.conflict,
    UD = icons.conflict,
    M = icons.modified,
    A = icons.added,
    D = icons.deleted,
    R = icons.renamed,
    ["?"] = icons.untracked,
  }
  return map[status] or status
end

local function get_status_hl(status, section)
  if section == "conflicted" then return "GitUIConflict" end
  if section == "staged" then return "GitUIStaged" end
  local map = {
    M = "GitUIModified",
    D = "GitUIDeleted",
    A = "GitUIStaged",
    R = "GitUIRenamed",
    ["?"] = "GitUIUntracked",
  }
  return map[status] or "Normal"
end

--- Render the status panel contents.
function M.render()
  local lines = {}
  local highlights = {}
  local line_map = {}
  local icons = config.options.icons
  local width = config.options.layout.status_width

  -- Top padding
  table.insert(lines, "")
  line_map[#lines] = { type = "blank" }

  -- Branch header
  local branch = state.branch
  local branch_line = string.format("  %s %s", icons.branch, branch.name)
  if branch.ahead > 0 or branch.behind > 0 then
    branch_line = branch_line .. string.format("  ↑%d ↓%d", branch.ahead, branch.behind)
  end
  table.insert(lines, branch_line)
  table.insert(highlights, { group = "GitUIBranch", line = #lines - 1 })
  line_map[#lines] = { type = "header" }

  table.insert(lines, "")
  line_map[#lines] = { type = "blank" }

  local total_files = #state.files.conflicted + #state.files.staged + #state.files.changed + #state.files.untracked

  if total_files == 0 then
    table.insert(lines, "  Working tree clean")
    table.insert(highlights, { group = "GitUIClean", line = #lines - 1 })
    line_map[#lines] = { type = "info" }
    table.insert(lines, "")
    line_map[#lines] = { type = "blank" }
  else
    local section_order = { "conflicted", "staged", "changed", "untracked" }
    local section_labels = {
      conflicted = "CONFLICTS",
      staged = "STAGED",
      changed = "CHANGES",
      untracked = "UNTRACKED",
    }

    for _, section in ipairs(section_order) do
      local files = state.files[section]
      if #files > 0 then
        local sec = state.sections[section]
        local icon = sec.collapsed and icons.section_closed or icons.section_open
        local label = section_labels[section]
        local count_str = tostring(#files)

        -- "  ▼ STAGED                         3"
        local prefix = string.format("  %s %s", icon, label)
        local padding = math.max(1, width - #prefix - #count_str - 1)
        local header_line = prefix .. string.rep(" ", padding) .. count_str

        table.insert(lines, header_line)
        line_map[#lines] = { type = "section", section = section }
        table.insert(highlights, {
          group = "GitUISectionHeader",
          line = #lines - 1,
          col_start = 0,
          col_end = #prefix,
        })
        table.insert(highlights, {
          group = "GitUISectionCount",
          line = #lines - 1,
          col_start = #header_line - #count_str,
          col_end = #header_line,
        })

        if not sec.collapsed then
          for i, file in ipairs(files) do
            local si
            if section == "staged" then
              si = icons.staged
            elseif section == "conflicted" then
              si = icons.conflict
            else
              si = get_status_icon(file.status)
            end

            -- Split path into directory and filename
            local dir, fname = file.path:match("^(.+/)([^/]+)$")
            if not dir then fname = file.path end

            local detail = ""
            if section == "conflicted" then
              detail = string.format("[%s] ", file.status)
            end

            -- Line 1: icon + detail + filename (always fully visible)
            local line1 = string.format("    %s %s%s", si, detail, fname)
            table.insert(lines, line1)
            line_map[#lines] = { type = "file", section = section, index = i, file = file }

            local icon_start = 4
            local icon_end = icon_start + #si
            table.insert(highlights, {
              group = get_status_hl(file.status, section),
              line = #lines - 1,
              col_start = icon_start,
              col_end = icon_end,
            })

            local detail_start = icon_end + 1
            local fname_start = detail_start + #detail
            if #detail > 0 then
              table.insert(highlights, {
                group = "GitUIConflict",
                line = #lines - 1,
                col_start = detail_start,
                col_end = fname_start,
              })
            end
            table.insert(highlights, {
              group = "GitUIFileName",
              line = #lines - 1,
              col_start = fname_start,
              col_end = -1,
            })

            -- Line 2: directory path, dimmed and left-truncated to fit width
            if dir then
              local dir_display = dir:sub(1, -2) -- strip trailing /
              local prefix = "       "           -- 7 spaces aligns under filename
              local max_w = math.max(4, width - #prefix)

              if #dir_display > max_w then
                -- Remove path components from the left until it fits
                local parts = vim.split(dir_display, "/", { plain = true })
                local truncated = false
                for pi = 2, #parts do
                  local candidate = "…/" .. table.concat(parts, "/", pi)
                  if #candidate <= max_w then
                    dir_display = candidate
                    truncated = true
                    break
                  end
                end
                if not truncated then
                  -- Hard truncate as last resort
                  dir_display = "…" .. dir_display:sub(#dir_display - max_w + 2)
                end
              end

              local line2 = prefix .. dir_display
              table.insert(lines, line2)
              -- Both lines map to same file item so cursor + actions work on either
              line_map[#lines] = { type = "file", section = section, index = i, file = file }
              table.insert(highlights, {
                group = "GitUIFilePath",
                line = #lines - 1,
                col_start = 0,
                col_end = -1,
              })
            end
          end
        end

        table.insert(lines, "")
        line_map[#lines] = { type = "blank" }
      end
    end
  end

  state.line_map = line_map
  ui.set_status_lines(lines, highlights)
end

--- Render the fixed help footer panel.
function M.render_help()
  local width = config.options.layout.status_width
  local lines = {}
  local highlights = {}

  -- Separator
  table.insert(lines, "  " .. string.rep("─", width - 4))
  table.insert(highlights, { group = "GitUISeparator", line = #lines - 1 })

  -- Help footer with key highlighting
  local help_rows = {
    { { "s", "stage" },   { "u", "unstage" },   { "d", "discard" } },
    { { "o", "ours" },    { "i", "incoming" },  { "B", "both" } },
    { { "m", "resolved" }, { "u", "undo" },      { "C-r", "redo" } },
    { { "hs", "hunk+" },  { "hu", "hunk-" } },
    { { "c", "commit" },  { "S", "stage all" }, { "U", "unstage all" } },
    { { "P", "push" },    { "L", "pull" },      { "b", "branch" } },
    { { "n", "new" },     { "r", "refresh" },   { "Tab", "diff" } },
    { { "]c", "next" },   { "[c", "prev" },     { "q/Esc", "close" } },
    { { "<", "shrink" },  { ">", "grow" } },
  }

  local cell_w = math.floor((width - 3) / 3)
  for _, row in ipairs(help_rows) do
    local line_str = "   "
    local key_ranges = {}
    local desc_ranges = {}
    local col = 3

    for _, item in ipairs(row) do
      local key, desc = item[1], item[2]
      local cell = key .. " " .. desc
      local pad = math.max(0, cell_w - #cell)
      line_str = line_str .. cell .. string.rep(" ", pad)

      table.insert(key_ranges, { s = col, e = col + #key })
      table.insert(desc_ranges, { s = col + #key + 1, e = col + #key + 1 + #desc })
      col = col + cell_w
    end

    table.insert(lines, line_str)

    for _, kr in ipairs(key_ranges) do
      table.insert(highlights, {
        group = "GitUIHelpKey",
        line = #lines - 1,
        col_start = kr.s,
        col_end = kr.e,
      })
    end
    for _, dr in ipairs(desc_ranges) do
      table.insert(highlights, {
        group = "GitUIHelpText",
        line = #lines - 1,
        col_start = dr.s,
        col_end = dr.e,
      })
    end
  end

  ui.set_help_lines(lines, highlights)
end

--- Move cursor to the first file line after render.
local function cursor_to_first_file()
  local ui_state = ui.get_state()
  if not ui_state.status_win or not vim.api.nvim_win_is_valid(ui_state.status_win) then return end
  if not ui_state.status_buf or not vim.api.nvim_buf_is_valid(ui_state.status_buf) then return end
  local total = vim.api.nvim_buf_line_count(ui_state.status_buf)
  for line_nr = 1, total do
    if state.line_map[line_nr] and state.line_map[line_nr].type == "file" then
      pcall(vim.api.nvim_win_set_cursor, ui_state.status_win, { line_nr, 0 })
      return
    end
  end
end

--- Refresh git status and branch info, then re-render.
function M.refresh(callback)
  if state.mode ~= "status" then
    -- Don't render status into log buffer; redirect to current mode.
    if state.mode == "log" then M.show_log() end
    if callback then callback() end
    return
  end
  if state.loading then return end
  state.loading = true

  local done = 0
  local total = 2

  local function check()
    done = done + 1
    if done >= total then
      state.loading = false
      M.render()
      M.render_help()
      M.update_diff_for_cursor()
      if callback then callback() end
    end
  end

  git.status(function(files)
    state.files = files
    check()
  end)

  git.branch_info(function(info)
    state.branch = info
    check()
  end)
end

--- Get the line_map item at the current cursor position.
function M.get_item_at_cursor()
  local ui_state = ui.get_state()
  if not ui_state.status_win or not vim.api.nvim_win_is_valid(ui_state.status_win) then
    return nil
  end
  local cursor = vim.api.nvim_win_get_cursor(ui_state.status_win)
  return state.line_map[cursor[1]]
end

--- Update the diff preview panel based on the currently selected file.
function M.update_diff_for_cursor()
  local item = M.get_item_at_cursor()
  if not item or item.type ~= "file" then
    ui.set_diff_lines({ "", "  Select a file to preview its diff" })
    ui.set_diff_statusline(nil)
    return
  end

  local file = item.file
  local staged = item.section == "staged"

  if item.section == "conflicted" then
    ui.set_diff_statusline(file.path .. " [CONFLICT]")
    local km = config.options.keymaps
    local hint = string.format(
      "    [%s] ours   [%s] incoming   [%s] both   [%s] resolved",
      km.resolve_ours,
      km.resolve_theirs,
      km.resolve_both,
      km.mark_resolved
    )

    git.read_file(file.actual_path, function(ok, lines, err)
      if not ok then
        ui.set_diff_lines({ "", "  Failed to read file: " .. err })
        return
      end

      local preview = {
        "  Tab into diff, navigate to a conflict, press o/i/B per block",
        hint,
        "",
      }
      if #lines == 0 then
        table.insert(preview, "  File is empty")
      else
        vim.list_extend(preview, lines)
      end
      ui.set_diff_lines(preview, {
        conflict = true,
        filepath = file.actual_path,
        hint_lines = 3,
      })
    end)
    return
  end

  ui.set_diff_statusline(file.path)

  local function show_diff(diff_text)
    if not diff_text or diff_text == "" then
      ui.set_diff_lines({ "", "  No changes to display" })
      return
    end
    local lines = vim.split(diff_text, "\n")
    ui.set_diff_lines(lines)
  end

  if item.section == "untracked" then
    git.diff_untracked(file.actual_path, show_diff)
  else
    git.diff(file.actual_path, staged, show_diff)
  end
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

function M.stage_file()
  local item = M.get_item_at_cursor()
  if not item or item.type ~= "file" then return end
  if item.section == "staged" then return end
  git.stage(item.file.actual_path, function(ok, err)
    if ok then
      M.refresh()
    else
      notify("Stage failed: " .. err, vim.log.levels.ERROR)
    end
  end)
end

function M.unstage_file()
  local item = M.get_item_at_cursor()
  if not item or item.type ~= "file" then return end
  if item.section ~= "staged" then return end
  git.unstage(item.file.actual_path, function(ok, err)
    if ok then
      M.refresh()
    else
      notify("Unstage failed: " .. err, vim.log.levels.ERROR)
    end
  end)
end

function M.discard_file()
  local item = M.get_item_at_cursor()
  if not item or item.type ~= "file" then return end

  if item.section == "staged" then
    notify("Unstage file before discarding changes", vim.log.levels.WARN)
    return
  end
  if item.section == "conflicted" then
    notify("Use conflict resolve actions (o/i/B/m) for conflicted files", vim.log.levels.WARN)
    return
  end

  local path = item.file.actual_path
  local prompt
  if item.section == "untracked" then
    prompt = "Delete untracked file '" .. path .. "'?"
  else
    prompt = "Discard changes in '" .. path .. "'?"
  end

  if vim.fn.confirm(prompt, "&No\n&Yes", 1) ~= 2 then return end

  git.discard(path, item.section == "untracked", function(ok, err)
    if ok then
      notify("Discarded: " .. path, vim.log.levels.INFO)
      M.refresh()
    else
      notify("Discard failed: " .. err, vim.log.levels.ERROR)
    end
  end)
end

local function get_conflicted_item()
  local item = M.get_item_at_cursor()
  if not item or item.type ~= "file" then return nil end
  if item.section ~= "conflicted" then return nil end
  return item
end

--- Save file content to undo stack before a per-conflict resolve.
local function save_conflict_undo(path)
  local cwd = vim.fn.getcwd()
  local full_path = cwd .. "/" .. path
  local ok, lines = pcall(vim.fn.readfile, full_path)
  if not ok then return end
  if not state.conflict_history[path] then
    state.conflict_history[path] = { undo = {}, redo = {} }
  end
  local hist = state.conflict_history[path]
  table.insert(hist.undo, lines)
  hist.redo = {} -- new action clears redo
end

--- If the diff panel has focus and cursor is on a conflict block, return its index.
---@return number|nil conflict_idx 1-based index of the conflict under cursor
local function get_conflict_at_diff_cursor()
  local ui_state = ui.get_state()
  local cur_win = vim.api.nvim_get_current_win()
  if not ui.is_diff_win(cur_win) then return nil end
  local cursor_line = vim.api.nvim_win_get_cursor(cur_win)[1]
  return ui_state.display_to_conflict_idx and ui_state.display_to_conflict_idx[cursor_line] or nil
end

local function resolve_conflict(strategy, success_msg)
  local item = get_conflicted_item()
  if not item then return end

  local path = item.file.actual_path
  local conflict_idx = get_conflict_at_diff_cursor()

  if conflict_idx then
    -- Per-conflict resolution from diff panel
    save_conflict_undo(path)
    git.resolve_single_conflict(path, conflict_idx, strategy, function(ok, err)
      if ok then
        local total = ui.get_state().conflict_count or 0
        notify(
          string.format("%s (#%d/%d): %s", success_msg, conflict_idx, total, path),
          vim.log.levels.INFO
        )
        M.refresh()
      else
        notify("Resolve failed: " .. err, vim.log.levels.ERROR)
      end
    end)
  else
    -- Whole-file resolution from status panel
    git.resolve_conflict(path, strategy, function(ok, err)
      if ok then
        notify(success_msg .. ": " .. path, vim.log.levels.INFO)
        M.refresh()
      else
        notify("Resolve failed: " .. err, vim.log.levels.ERROR)
      end
    end)
  end
end

function M.resolve_conflict_ours()
  resolve_conflict("ours", "Accepted current changes")
end

function M.resolve_conflict_theirs()
  resolve_conflict("theirs", "Accepted incoming changes")
end

function M.resolve_conflict_both()
  local item = get_conflicted_item()
  if not item then return end

  local path = item.file.actual_path
  local conflict_idx = get_conflict_at_diff_cursor()

  if conflict_idx then
    -- Per-conflict "both" from diff panel
    save_conflict_undo(path)
    git.resolve_single_conflict(path, conflict_idx, "both", function(ok, err)
      if ok then
        local total = ui.get_state().conflict_count or 0
        notify(
          string.format("Accepted both changes (#%d/%d): %s", conflict_idx, total, path),
          vim.log.levels.INFO
        )
        M.refresh()
      else
        notify("Resolve failed: " .. err, vim.log.levels.ERROR)
      end
    end)
  else
    -- Whole-file "both"
    git.resolve_conflict_both(path, function(ok, err)
      if ok then
        notify("Accepted both changes: " .. path, vim.log.levels.INFO)
        M.refresh()
      else
        notify("Resolve both failed: " .. err, vim.log.levels.ERROR)
      end
    end)
  end
end

function M.mark_conflict_resolved()
  local item = get_conflicted_item()
  if not item then return end

  local path = item.file.actual_path
  git.stage(path, function(ok, err)
    if ok then
      notify("Marked resolved: " .. path, vim.log.levels.INFO)
      M.refresh()
    else
      notify("Mark resolved failed: " .. err, vim.log.levels.ERROR)
    end
  end)
end

function M.undo_conflict()
  local item = get_conflicted_item()
  if not item then return end

  local path = item.file.actual_path
  local hist = state.conflict_history[path]
  if not hist or #hist.undo == 0 then
    notify("Nothing to undo", vim.log.levels.WARN)
    return
  end

  local cwd = vim.fn.getcwd()
  local full_path = cwd .. "/" .. path

  -- Save current state to redo
  local ok, current = pcall(vim.fn.readfile, full_path)
  if ok then
    table.insert(hist.redo, current)
  end

  -- Restore previous state
  local prev = table.remove(hist.undo)
  local ok_w, err = pcall(vim.fn.writefile, prev, full_path)
  if not ok_w then
    notify("Undo failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  notify("Undid conflict resolution", vim.log.levels.INFO)
  M.refresh()
end

function M.redo_conflict()
  local item = get_conflicted_item()
  if not item then return end

  local path = item.file.actual_path
  local hist = state.conflict_history[path]
  if not hist or #hist.redo == 0 then
    notify("Nothing to redo", vim.log.levels.WARN)
    return
  end

  local cwd = vim.fn.getcwd()
  local full_path = cwd .. "/" .. path

  -- Save current state to undo
  local ok, current = pcall(vim.fn.readfile, full_path)
  if ok then
    table.insert(hist.undo, current)
  end

  -- Apply redo state
  local next_state = table.remove(hist.redo)
  local ok_w, err = pcall(vim.fn.writefile, next_state, full_path)
  if not ok_w then
    notify("Redo failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  notify("Redid conflict resolution", vim.log.levels.INFO)
  M.refresh()
end

function M.toggle_section()
  local item = M.get_item_at_cursor()
  if not item or item.type ~= "section" then return end
  state.sections[item.section].collapsed = not state.sections[item.section].collapsed
  M.render()
end

function M.do_commit()
  local width = 60
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor(vim.o.lines * 0.35)

  -- Title bar (non-editable)
  local title_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[title_buf].buftype = "nofile"
  vim.bo[title_buf].bufhidden = "wipe"
  local title_text = "  Commit"
  vim.api.nvim_buf_set_lines(title_buf, 0, -1, false, { title_text })
  vim.api.nvim_buf_add_highlight(title_buf, -1, "GitUICommitTitle", 0, 0, -1)

  local title_win = vim.api.nvim_open_win(title_buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = 1,
    style = "minimal",
    border = { "╭", "─", "╮", "│", "", "", "", "│" },
    zindex = 60,
  })
  vim.wo[title_win].winhighlight = "Normal:GitUICommitNormal,FloatBorder:GitUICommitBorder"

  -- Input buffer
  local input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[input_buf].buftype = "nofile"
  vim.bo[input_buf].bufhidden = "wipe"

  local input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor",
    row = row + 2,
    col = col,
    width = width,
    height = 1,
    style = "minimal",
    border = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
    zindex = 60,
  })
  vim.wo[input_win].winhighlight = "Normal:GitUICommitNormal,FloatBorder:GitUICommitBorder"

  -- Character counter namespace
  local ns = vim.api.nvim_create_namespace("git-ui-commit-counter")

  local function update_counter()
    if not vim.api.nvim_buf_is_valid(title_buf) then return end
    local lines = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)
    local len = #(lines[1] or "")
    local counter = string.format("%d/50", len)
    local hl = "GitUICommitCounter"
    if len > 50 then hl = "GitUICommitCounterOver"
    elseif len > 40 then hl = "GitUICommitCounterWarn" end
    vim.bo[title_buf].modifiable = true
    local padded = title_text .. string.rep(" ", width - #title_text - #counter) .. counter
    vim.api.nvim_buf_set_lines(title_buf, 0, -1, false, { padded })
    vim.api.nvim_buf_clear_namespace(title_buf, ns, 0, -1)
    vim.api.nvim_buf_add_highlight(title_buf, ns, "GitUICommitTitle", 0, 0, #title_text)
    vim.api.nvim_buf_add_highlight(title_buf, ns, hl, 0, #padded - #counter, -1)
    vim.bo[title_buf].modifiable = false
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = input_buf,
    callback = update_counter,
  })

  update_counter()
  vim.cmd("startinsert")

  local function close()
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(input_win) then vim.api.nvim_win_close(input_win, true) end
    if vim.api.nvim_win_is_valid(title_win) then vim.api.nvim_win_close(title_win, true) end
  end

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)
    local msg = vim.trim(lines[1] or "")
    close()
    if msg == "" then return end
    git.commit(msg, function(ok, output)
      if ok then
        notify("✓ " .. vim.trim(output):match("[^\n]*$"), vim.log.levels.INFO)
        M.refresh()
      else
        notify("Commit failed: " .. output, vim.log.levels.ERROR)
      end
    end)
  end

  vim.keymap.set({ "n", "i" }, "<CR>", submit, { buffer = input_buf })
  vim.keymap.set({ "n", "i" }, "<Esc>", close, { buffer = input_buf })
  vim.keymap.set("n", "q", close, { buffer = input_buf })
end

function M.do_push()
  notify("Pushing...", vim.log.levels.INFO)
  git.push(function(ok, output)
    if ok then
      notify("✓ Pushed successfully", vim.log.levels.INFO)
      M.refresh()
    else
      notify("Push failed: " .. output, vim.log.levels.ERROR)
    end
  end)
end

function M.do_pull()
  notify("Pulling...", vim.log.levels.INFO)
  git.pull(function(ok, output)
    if ok then
      notify("✓ Pulled successfully", vim.log.levels.INFO)
      M.refresh()
    else
      notify("Pull failed: " .. output, vim.log.levels.ERROR)
    end
  end)
end

function M.show_branches()
  git.branches(function(branches)
    if #branches == 0 then
      notify("No branches found", vim.log.levels.WARN)
      return
    end
    local items = {}
    for _, b in ipairs(branches) do
      table.insert(items, (b.current and "● " or "  ") .. b.name)
    end
    vim.ui.select(items, { prompt = " Switch branch:" }, function(_, idx)
      if not idx then return end
      local branch = branches[idx]
      if branch.current then return end
      git.checkout(branch.name, function(ok, output)
        if ok then
          notify("Switched to " .. branch.name, vim.log.levels.INFO)
          M.refresh()
        else
          notify("Checkout failed: " .. output, vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

function M.create_branch()
  vim.ui.input({ prompt = "  New branch name: " }, function(name)
    if not name or name == "" then return end
    git.create_branch(name, function(ok, output)
      if ok then
        notify("Created branch " .. name, vim.log.levels.INFO)
        M.refresh()
      else
        notify("Failed: " .. output, vim.log.levels.ERROR)
      end
    end)
  end)
end

---------------------------------------------------------------------------
-- Hunk operations
---------------------------------------------------------------------------

--- Extract the diff header and the target hunk from raw diff lines.
--- Uses stored raw_diff_lines (since the buffer no longer has diff prefixes).
---@return string|nil patch, table|nil item
function M.get_current_hunk_patch()
  local item = M.get_item_at_cursor()
  if not item or item.type ~= "file" then return nil, nil end

  local ui_state = ui.get_state()
  local raw_lines = ui_state.raw_diff_lines
  if not raw_lines or #raw_lines == 0 then return nil, nil end

  -- Parse raw diff lines into header + hunks
  local header_lines = {}
  local hunks = {}
  local current_hunk = nil

  for _, line in ipairs(raw_lines) do
    if line:match("^diff ") or line:match("^index ") or line:match("^%-%-%- ") or line:match("^%+%+%+ ") or line:match("^new file") or line:match("^deleted file") then
      table.insert(header_lines, line)
    elseif line:match("^@@") then
      if current_hunk then table.insert(hunks, current_hunk) end
      current_hunk = { line }
    elseif current_hunk then
      table.insert(current_hunk, line)
    end
  end
  if current_hunk then table.insert(hunks, current_hunk) end
  if #hunks == 0 then return nil, nil end

  -- Find which hunk based on cursor position in diff panel
  local target_hunk = hunks[1]
  local cur_win = vim.api.nvim_get_current_win()
  if ui.is_diff_win(cur_win) then
    local cursor_line = vim.api.nvim_win_get_cursor(cur_win)[1]
    local hunk_idx = ui_state.display_to_hunk_idx[cursor_line]
    if hunk_idx and hunks[hunk_idx] then
      target_hunk = hunks[hunk_idx]
    end
  end

  local patch_lines = vim.list_extend({}, header_lines)
  vim.list_extend(patch_lines, target_hunk)
  return table.concat(patch_lines, "\n") .. "\n", item
end

function M.stage_hunk()
  local patch, item = M.get_current_hunk_patch()
  if not patch or not item then
    notify("No hunk to stage", vim.log.levels.WARN)
    return
  end
  if item.section == "staged" then return end
  git.stage_hunk(patch, function(ok, err)
    if ok then
      M.refresh()
    else
      notify("Stage hunk failed: " .. err, vim.log.levels.ERROR)
    end
  end)
end

function M.unstage_hunk()
  local patch, item = M.get_current_hunk_patch()
  if not patch or not item then
    notify("No hunk to unstage", vim.log.levels.WARN)
    return
  end
  if item.section ~= "staged" then return end
  git.unstage_hunk(patch, function(ok, err)
    if ok then
      M.refresh()
    else
      notify("Unstage hunk failed: " .. err, vim.log.levels.ERROR)
    end
  end)
end

---------------------------------------------------------------------------
-- Log view
---------------------------------------------------------------------------

local function render_log()
  local lines = {}
  local highlights = {}
  local line_map = {}
  local width = config.options.layout.status_width

  -- Mode indicator
  table.insert(lines, "")
  line_map[#lines] = { type = "blank" }

  local title = "  HISTORY"
  table.insert(lines, title)
  table.insert(highlights, { group = "GitUILogModeBar", line = #lines - 1 })
  line_map[#lines] = { type = "header" }

  table.insert(lines, "")
  line_map[#lines] = { type = "blank" }

  if state.log.loading then
    table.insert(lines, "  Loading commits...")
    table.insert(highlights, { group = "GitUIClean", line = #lines - 1 })
    line_map[#lines] = { type = "info" }
  elseif #state.log.commits == 0 then
    table.insert(lines, "  No commits")
    table.insert(highlights, { group = "GitUIClean", line = #lines - 1 })
    line_map[#lines] = { type = "info" }
  else
    for i, c in ipairs(state.log.commits) do
      if c.hash then
        local graph = c.graph or ""
        -- Line 1: graph + short hash + subject
        local prefix = "  " .. graph
        local line1 = prefix .. c.short .. " " .. c.subject
        local max_w = math.max(20, width - 2)
        if vim.fn.strdisplaywidth(line1) > max_w then
          line1 = vim.fn.strcharpart(line1, 0, max_w - 1) .. "…"
        end
        table.insert(lines, line1)
        line_map[#lines] = { type = "commit", index = i, commit = c }

        -- Highlight ranges (col counts in bytes; our chars are ASCII here)
        local graph_end = #prefix
        local hash_end = graph_end + #c.short
        if #graph > 0 then
          table.insert(highlights, {
            group = "GitUILogGraph", line = #lines - 1,
            col_start = 2, col_end = graph_end,
          })
        end
        table.insert(highlights, {
          group = "GitUILogHash", line = #lines - 1,
          col_start = graph_end, col_end = hash_end,
        })
        table.insert(highlights, {
          group = "GitUILogSubject", line = #lines - 1,
          col_start = hash_end, col_end = -1,
        })

        -- Line 2: refs + author · date
        local refs_part = ""
        if c.refs and c.refs ~= "" then
          refs_part = c.refs
        end
        local meta = string.format("%s · %s", c.author, c.date)
        local line2_prefix = "       "
        local sub_line
        if refs_part ~= "" then
          sub_line = line2_prefix .. refs_part .. "  " .. meta
        else
          sub_line = line2_prefix .. meta
        end
        local max_w2 = math.max(10, width - #line2_prefix - 1)
        local visible = sub_line:sub(#line2_prefix + 1)
        if vim.fn.strdisplaywidth(visible) > max_w2 then
          visible = vim.fn.strcharpart(visible, 0, max_w2 - 1) .. "…"
          sub_line = line2_prefix .. visible
        end
        table.insert(lines, sub_line)
        line_map[#lines] = { type = "commit", index = i, commit = c }

        if refs_part ~= "" then
          local refs_start = #line2_prefix
          local refs_end = refs_start + #refs_part
          table.insert(highlights, {
            group = "GitUILogRefs", line = #lines - 1,
            col_start = refs_start, col_end = math.min(refs_end, #sub_line),
          })
        end
        table.insert(highlights, {
          group = "GitUILogDate", line = #lines - 1,
          col_start = #sub_line - math.min(#meta, #sub_line - #line2_prefix),
          col_end = -1,
        })
      else
        -- Pure graph connector line (no commit)
        local g = "  " .. (c.graph or "")
        table.insert(lines, g)
        table.insert(highlights, { group = "GitUILogGraph", line = #lines - 1 })
        line_map[#lines] = { type = "blank" }
      end
    end
  end

  state.line_map = line_map
  ui.set_status_lines(lines, highlights)
end

local function render_log_files()
  local lines = {}
  local highlights = {}
  local line_map = {}
  local icons = config.options.icons
  local commit = state.log.commits[state.log.selected]

  table.insert(lines, "")
  line_map[#lines] = { type = "blank" }

  local title = "  COMMIT " .. (commit and commit.short or "")
  table.insert(lines, title)
  table.insert(highlights, { group = "GitUILogModeBar", line = #lines - 1 })
  line_map[#lines] = { type = "header" }

  if commit and commit.subject ~= "" then
    local sub = "  " .. commit.subject
    local max_w = math.max(20, config.options.layout.status_width - 2)
    if vim.fn.strdisplaywidth(sub) > max_w then
      sub = vim.fn.strcharpart(sub, 0, max_w - 1) .. "…"
    end
    table.insert(lines, sub)
    table.insert(highlights, { group = "GitUILogSubject", line = #lines - 1 })
    line_map[#lines] = { type = "info" }
  end

  table.insert(lines, "")
  line_map[#lines] = { type = "blank" }

  if state.log.loading then
    table.insert(lines, "  Loading files...")
    table.insert(highlights, { group = "GitUIClean", line = #lines - 1 })
    line_map[#lines] = { type = "info" }
  elseif #state.log.files == 0 then
    table.insert(lines, "  No files")
    table.insert(highlights, { group = "GitUIClean", line = #lines - 1 })
    line_map[#lines] = { type = "info" }
  else
    local label = "  FILES"
    table.insert(lines, label)
    table.insert(highlights, { group = "GitUISectionHeader", line = #lines - 1 })
    line_map[#lines] = { type = "header" }

    for i, f in ipairs(state.log.files) do
      local si_map = {
        M = icons.modified, A = icons.added, D = icons.deleted,
        R = icons.renamed, C = icons.renamed,
      }
      local si = si_map[f.status] or f.status
      local hl_map = {
        M = "GitUIModified", A = "GitUIStaged", D = "GitUIDeleted",
        R = "GitUIRenamed", C = "GitUIRenamed",
      }
      local dir, fname = f.path:match("^(.+/)([^/]+)$")
      if not dir then fname = f.path end

      local line1 = string.format("    %s %s", si, fname)
      table.insert(lines, line1)
      line_map[#lines] = { type = "log_file", index = i, file = f }
      table.insert(highlights, {
        group = hl_map[f.status] or "Normal", line = #lines - 1,
        col_start = 4, col_end = 4 + #si,
      })
      table.insert(highlights, {
        group = "GitUIFileName", line = #lines - 1,
        col_start = 4 + #si + 1, col_end = -1,
      })

      if dir then
        local dir_disp = dir:sub(1, -2)
        local prefix = "       "
        local max_w = math.max(4, config.options.layout.status_width - #prefix)
        if #dir_disp > max_w then
          local parts = vim.split(dir_disp, "/", { plain = true })
          local ok = false
          for pi = 2, #parts do
            local cand = "…/" .. table.concat(parts, "/", pi)
            if #cand <= max_w then dir_disp = cand; ok = true; break end
          end
          if not ok then dir_disp = "…" .. dir_disp:sub(#dir_disp - max_w + 2) end
        end
        local line2 = prefix .. dir_disp
        table.insert(lines, line2)
        table.insert(highlights, { group = "GitUIFilePath", line = #lines - 1 })
        line_map[#lines] = { type = "log_file", index = i, file = f }
      end
    end
  end

  state.line_map = line_map
  ui.set_status_lines(lines, highlights)
end

local function render_log_help()
  local width = config.options.layout.status_width
  local lines = {}
  local highlights = {}

  table.insert(lines, "  " .. string.rep("─", width - 4))
  table.insert(highlights, { group = "GitUISeparator", line = #lines - 1 })

  local rows
  if state.mode == "log" then
    rows = {
      { { "j/k", "move" },     { "CR", "drill in" } },
      { { "BS", "back" },      { "Tab", "diff" } },
      { { "r", "refresh" },    { "q", "close" } },
    }
  else -- log_files
    rows = {
      { { "j/k", "move" },     { "CR", "view diff" } },
      { { "BS", "back" },      { "Tab", "diff" } },
      { { "q", "close" } },
    }
  end

  local cell_w = math.floor((width - 3) / 3)
  for _, row in ipairs(rows) do
    local line_str = "   "
    local key_ranges, desc_ranges = {}, {}
    local col = 3
    for _, item in ipairs(row) do
      local key, desc = item[1], item[2]
      local cell = key .. " " .. desc
      local pad = math.max(0, cell_w - #cell)
      line_str = line_str .. cell .. string.rep(" ", pad)
      table.insert(key_ranges, { s = col, e = col + #key })
      table.insert(desc_ranges, { s = col + #key + 1, e = col + #key + 1 + #desc })
      col = col + cell_w
    end
    table.insert(lines, line_str)
    for _, kr in ipairs(key_ranges) do
      table.insert(highlights, {
        group = "GitUIHelpKey", line = #lines - 1,
        col_start = kr.s, col_end = kr.e,
      })
    end
    for _, dr in ipairs(desc_ranges) do
      table.insert(highlights, {
        group = "GitUIHelpText", line = #lines - 1,
        col_start = dr.s, col_end = dr.e,
      })
    end
  end

  ui.set_help_lines(lines, highlights)
end

--- Update diff panel based on cursor in log/log_files mode.
function M.update_log_diff_for_cursor()
  local item = M.get_item_at_cursor()
  if not item then
    ui.set_diff_lines({ "", "  Move cursor onto a commit" })
    ui.set_diff_statusline(nil)
    return
  end

  if state.mode == "log" and item.type == "commit" then
    local commit = item.commit
    ui.set_diff_statusline(commit.short .. "  " .. commit.subject)
    git.commit_meta(commit.hash, function(meta)
      git.commit_show(commit.hash, function(diff)
        local out = {}
        if meta and meta ~= "" then
          for ml in (meta .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(out, ml)
          end
          table.insert(out, "")
        end
        if diff and diff ~= "" then
          for dl in (diff .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(out, dl)
          end
        end
        if #out == 0 then out = { "", "  (empty commit)" } end
        ui.set_diff_lines(out, { raw = true })
      end)
    end)
  elseif state.mode == "log_files" and item.type == "log_file" then
    local commit = state.log.commits[state.log.selected]
    if not commit then return end
    ui.set_diff_statusline(commit.short .. "  " .. item.file.path)
    git.commit_file_diff(commit.hash, item.file.path, function(diff)
      if not diff or diff == "" then
        ui.set_diff_lines({ "", "  No diff available" })
        return
      end
      ui.set_diff_lines(vim.split(diff, "\n"))
    end)
  else
    ui.set_diff_lines({ "", "  " })
    ui.set_diff_statusline(nil)
  end
end

--- Switch to log mode and load commits.
function M.show_log()
  state.mode = "log"
  state.log.loading = true
  render_log()
  render_log_help()
  ui.set_diff_lines({ "", "  Loading commits..." })
  ui.set_diff_statusline(nil)

  git.log({
    limit = config.options.log.limit,
    all = config.options.log.show_all_branches,
  }, function(commits)
    state.log.commits = commits
    state.log.loading = false
    render_log()
    render_log_help()

    -- Move cursor to first commit
    local ui_state = ui.get_state()
    if ui_state.status_win and vim.api.nvim_win_is_valid(ui_state.status_win) then
      for line_nr, item in pairs(state.line_map) do
        if item.type == "commit" then
          pcall(vim.api.nvim_win_set_cursor, ui_state.status_win, { line_nr, 0 })
          break
        end
      end
    end
    M.update_log_diff_for_cursor()
  end)
end

--- Switch back to status mode.
function M.show_status()
  state.mode = "status"
  state.log.selected = nil
  state.log.files = {}
  M.refresh(function()
    cursor_to_first_file()
  end)
end

--- Drill into the commit at cursor: load files, show file list.
function M.log_drill_in()
  local item = M.get_item_at_cursor()
  if not item or item.type ~= "commit" then return end
  state.log.selected = item.index
  state.log.loading = true
  state.mode = "log_files"
  render_log_files()
  render_log_help()
  git.commit_files(item.commit.hash, function(files)
    state.log.files = files
    state.log.loading = false
    render_log_files()

    local ui_state = ui.get_state()
    if ui_state.status_win and vim.api.nvim_win_is_valid(ui_state.status_win) then
      for line_nr, lm in pairs(state.line_map) do
        if lm.type == "log_file" then
          pcall(vim.api.nvim_win_set_cursor, ui_state.status_win, { line_nr, 0 })
          break
        end
      end
    end
    M.update_log_diff_for_cursor()
  end)
end

--- Back navigation: log_files → log → status.
function M.drill_out()
  if state.mode == "log_files" then
    state.mode = "log"
    state.log.selected = nil
    state.log.files = {}
    render_log()
    render_log_help()

    -- Restore cursor to the commit we drilled into (best effort)
    local ui_state = ui.get_state()
    if ui_state.status_win and vim.api.nvim_win_is_valid(ui_state.status_win) then
      for line_nr, lm in pairs(state.line_map) do
        if lm.type == "commit" then
          pcall(vim.api.nvim_win_set_cursor, ui_state.status_win, { line_nr, 0 })
          break
        end
      end
    end
    M.update_log_diff_for_cursor()
  elseif state.mode == "log" then
    M.show_status()
  end
end

--- Dispatcher for <CR> based on mode.
function M.on_enter()
  if state.mode == "status" then
    M.toggle_section()
  elseif state.mode == "log" then
    M.log_drill_in()
  elseif state.mode == "log_files" then
    -- Already viewing diff via cursor; <CR> focuses diff panel
    ui.focus_diff()
  end
end

--- Dispatcher for refresh based on mode.
function M.refresh_current()
  if state.mode == "log" then
    M.show_log()
  else
    M.refresh()
  end
end

--- Cursor-move dispatcher: route to status diff or log diff.
function M.update_diff_dispatcher()
  if state.mode == "status" then
    M.update_diff_for_cursor()
  else
    M.update_log_diff_for_cursor()
  end
end

-- expose for init
M.cursor_to_first_file = cursor_to_first_file

return M
