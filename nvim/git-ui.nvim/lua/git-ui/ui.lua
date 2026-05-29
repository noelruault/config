local M = {}

local ns_diff = vim.api.nvim_create_namespace("git-ui-diff")
local ns_status = vim.api.nvim_create_namespace("git-ui-status")
local ns_scrollbar = vim.api.nvim_create_namespace("git-ui-scrollbar")
local ns_ts = vim.api.nvim_create_namespace("git-ui-ts")

local ns_diff_right = vim.api.nvim_create_namespace("git-ui-diff-right")
local ns_ts_right = vim.api.nvim_create_namespace("git-ui-ts-right")

local state = {
  status_buf = nil,
  status_win = nil,
  help_buf = nil,
  help_win = nil,
  diff_buf = nil,       -- left pane (or unified)
  diff_win = nil,
  diff_right_buf = nil, -- right pane (SBS only)
  diff_right_win = nil,
  divider_buf = nil,
  divider_win = nil,
  diffbar_buf = nil,
  diffbar_win = nil,
  scrollbar_buf = nil,
  scrollbar_win = nil,
  sbs_mode = false,
  sbs_left_ratio = 0.5, -- fraction of diff area for left pane
  is_open = false,
  prev_win = nil,
  prev_laststatus = nil,
  change_starts = {},
  change_idx = 0, -- current index into change_starts
  change_lines_set = {}, -- line_nr -> "add" | "del"
  raw_diff_lines = {},
  last_diff_opts = nil,
  display_to_hunk_idx = {},
  display_to_conflict_idx = {}, -- display_line_nr -> conflict_idx (1-based)
  conflict_count = 0,
  help_height = 12, -- lines reserved for the fixed help footer
}

function M.get_state()
  return state
end

function M.is_open()
  return state.is_open
end

local function buf_valid(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function win_valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function make_nofile_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  return buf
end

local function set_win_opts(win, opts)
  for k, v in pairs(opts) do vim.wo[win][k] = v end
end

local minimal_opts = {
  number = false, relativenumber = false, signcolumn = "no",
  wrap = false, cursorline = false, spell = false, list = false,
  winfixwidth = true, foldcolumn = "0",
}

local diff_win_opts = {
  number = true, relativenumber = false, signcolumn = "yes:1",
  wrap = false, cursorline = false, spell = false, list = false,
}

function M.open(status_width)
  if state.is_open then return end
  state.prev_win = vim.api.nvim_get_current_win()

  -- Hide background statusline
  state.prev_laststatus = vim.o.laststatus
  vim.o.laststatus = 0

  local cfg = require("git-ui.config")
  local editor_width = vim.o.columns
  -- vim.o.lines = total rows. Subtract tabline (1 if visible) and cmdheight.
  -- We set laststatus=0 so no statusline row to subtract.
  local tabline = (vim.o.showtabline == 0) and 0
    or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") == 1) and 0
    or 1
  local editor_height = vim.o.lines - tabline - vim.o.cmdheight
  local scrollbar_width = 2
  local diff_width = math.max(1, editor_width - status_width - scrollbar_width)
  local diffbar_height = 1
  local diff_content_height = editor_height - diffbar_height
  local status_height = editor_height - state.help_height

  -- Determine side-by-side mode
  local sbs_min = cfg.options.layout.side_by_side_min_width
  state.sbs_mode = diff_width >= sbs_min

  -- Create core buffers
  state.status_buf = make_nofile_buf()
  vim.bo[state.status_buf].filetype = "git-ui-status"
  state.diff_buf = make_nofile_buf()
  vim.bo[state.diff_buf].filetype = "git-ui-diff"
  state.scrollbar_buf = make_nofile_buf()
  state.help_buf = make_nofile_buf()
  state.diffbar_buf = make_nofile_buf()

  -- Status panel
  state.status_win = vim.api.nvim_open_win(state.status_buf, true, {
    relative = "editor", row = 0, col = 0,
    width = status_width, height = status_height,
    style = "minimal", border = "none", zindex = 40,
  })
  set_win_opts(state.status_win, vim.tbl_extend("force", minimal_opts, {
    cursorline = true,
    winhighlight = "Normal:GitUIStatusBg,CursorLine:GitUIStatusCursorLine",
  }))

  -- Help footer
  state.help_win = vim.api.nvim_open_win(state.help_buf, false, {
    relative = "editor", row = status_height, col = 0,
    width = status_width, height = state.help_height,
    style = "minimal", border = "none", zindex = 40,
  })
  set_win_opts(state.help_win, vim.tbl_extend("force", minimal_opts, {
    winhighlight = "Normal:GitUIStatusBg",
  }))

  if state.sbs_mode then
    -- Side-by-side: left pane (old/del) + divider + right pane (new/add)
    local divider_width = 1
    local left_width = math.floor((diff_width - divider_width) * state.sbs_left_ratio)
    local right_width = diff_width - divider_width - left_width

    state.diff_win = vim.api.nvim_open_win(state.diff_buf, false, {
      relative = "editor", row = 0, col = status_width,
      width = left_width, height = diff_content_height,
      style = "minimal", border = "none", zindex = 40,
    })
    set_win_opts(state.diff_win, diff_win_opts)

    -- Divider
    state.divider_buf = make_nofile_buf()
    local div_lines = {}
    for _ = 1, diff_content_height do table.insert(div_lines, "│") end
    vim.api.nvim_buf_set_lines(state.divider_buf, 0, -1, false, div_lines)
    vim.bo[state.divider_buf].modifiable = false

    state.divider_win = vim.api.nvim_open_win(state.divider_buf, false, {
      relative = "editor", row = 0, col = status_width + left_width,
      width = divider_width, height = diff_content_height,
      style = "minimal", border = "none", zindex = 40,
    })
    set_win_opts(state.divider_win, vim.tbl_extend("force", minimal_opts, {
      winhighlight = "Normal:GitUIDiffDivider",
    }))

    -- Right pane
    state.diff_right_buf = make_nofile_buf()
    vim.bo[state.diff_right_buf].filetype = "git-ui-diff"

    state.diff_right_win = vim.api.nvim_open_win(state.diff_right_buf, false, {
      relative = "editor", row = 0, col = status_width + left_width + divider_width,
      width = right_width, height = diff_content_height,
      style = "minimal", border = "none", zindex = 40,
    })
    set_win_opts(state.diff_right_win, diff_win_opts)
  else
    -- Unified mode: single diff pane
    state.diff_win = vim.api.nvim_open_win(state.diff_buf, false, {
      relative = "editor", row = 0, col = status_width,
      width = diff_width, height = diff_content_height,
      style = "minimal", border = "none", zindex = 40,
    })
    set_win_opts(state.diff_win, diff_win_opts)
  end

  -- Diffbar (filepath)
  state.diffbar_win = vim.api.nvim_open_win(state.diffbar_buf, false, {
    relative = "editor", row = diff_content_height, col = status_width,
    width = diff_width + scrollbar_width, height = diffbar_height,
    style = "minimal", border = "none", zindex = 40,
  })
  set_win_opts(state.diffbar_win, vim.tbl_extend("force", minimal_opts, {
    winhighlight = "Normal:GitUIStatusBg",
  }))

  -- Scrollbar
  state.scrollbar_win = vim.api.nvim_open_win(state.scrollbar_buf, false, {
    relative = "editor", row = 0, col = status_width + diff_width,
    width = scrollbar_width, height = diff_content_height,
    style = "minimal", border = "none", zindex = 40,
  })
  set_win_opts(state.scrollbar_win, minimal_opts)

  state.is_open = true

  -- Auto-cleanup when any buffer is wiped
  local cleanup_bufs = { state.status_buf, state.help_buf, state.diff_buf, state.diffbar_buf, state.scrollbar_buf }
  if state.diff_right_buf then table.insert(cleanup_bufs, state.diff_right_buf) end
  if state.divider_buf then table.insert(cleanup_bufs, state.divider_buf) end
  for _, buf in ipairs(cleanup_bufs) do
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = buf, once = true,
      callback = function() vim.schedule(function() M.close() end) end,
    })
  end

  -- Focus the status panel
  vim.api.nvim_set_current_win(state.status_win)
end

function M.close()
  if not state.is_open then return end
  state.is_open = false

  -- Restore background statusline
  if state.prev_laststatus then
    vim.o.laststatus = state.prev_laststatus
    state.prev_laststatus = nil
  end

  -- Close all floating windows (bufhidden=wipe handles buffer cleanup)
  for _, win in ipairs({
    state.scrollbar_win, state.diffbar_win, state.diff_right_win,
    state.divider_win, state.diff_win, state.help_win, state.status_win,
  }) do
    if win_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
  end

  -- Restore focus to previous window
  if state.prev_win and win_valid(state.prev_win) then
    pcall(vim.api.nvim_set_current_win, state.prev_win)
  end

  state.status_buf = nil
  state.status_win = nil
  state.help_buf = nil
  state.help_win = nil
  state.diff_buf = nil
  state.diff_win = nil
  state.diff_right_buf = nil
  state.diff_right_win = nil
  state.divider_buf = nil
  state.divider_win = nil
  state.diffbar_buf = nil
  state.diffbar_win = nil
  state.scrollbar_buf = nil
  state.scrollbar_win = nil
  state.sbs_mode = false
  state.sbs_left_ratio = 0.5
  pcall(vim.api.nvim_del_augroup_by_name, "git-ui-sbs-sync")
end

function M.set_status_lines(lines, highlights)
  if not buf_valid(state.status_buf) then return end
  vim.bo[state.status_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.status_buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.status_buf, ns_status, 0, -1)
  if highlights then
    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(
        state.status_buf,
        ns_status,
        hl.group,
        hl.line,
        hl.col_start or 0,
        hl.col_end or -1
      )
    end
  end
  vim.bo[state.status_buf].modifiable = false
end

local ns_help = vim.api.nvim_create_namespace("git-ui-help")

function M.set_help_lines(lines, highlights)
  if not buf_valid(state.help_buf) then return end
  vim.bo[state.help_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.help_buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.help_buf, ns_help, 0, -1)
  if highlights then
    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(
        state.help_buf,
        ns_help,
        hl.group,
        hl.line,
        hl.col_start or 0,
        hl.col_end or -1
      )
    end
  end
  vim.bo[state.help_buf].modifiable = false
end

local ns_diffbar = vim.api.nvim_create_namespace("git-ui-diffbar")

function M.set_diff_statusline(filepath)
  if not buf_valid(state.diffbar_buf) then return end
  vim.bo[state.diffbar_buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(state.diffbar_buf, ns_diffbar, 0, -1)

  if filepath then
    -- Split into dir/ and filename
    local dir, fname = filepath:match("^(.+/)([^/]+)$")
    if not dir then fname = filepath end

    local sep = "─"
    local icon = "  "
    local text = sep .. icon
    local hls = {}

    -- separator tick
    table.insert(hls, { "GitUIDiffBarSep", 0, 0, #sep })
    -- icon
    table.insert(hls, { "GitUIDiffBarIcon", 0, #sep, #sep + #icon })

    if dir then
      text = text .. dir .. fname
      local dir_start = #sep + #icon
      table.insert(hls, { "GitUIDiffBarDir", 0, dir_start, dir_start + #dir })
      table.insert(hls, { "GitUIDiffBarFile", 0, dir_start + #dir, dir_start + #dir + #fname })
    else
      text = text .. fname
      local fname_start = #sep + #icon
      table.insert(hls, { "GitUIDiffBarFile", 0, fname_start, fname_start + #fname })
    end

    vim.api.nvim_buf_set_lines(state.diffbar_buf, 0, -1, false, { text })
    for _, h in ipairs(hls) do
      vim.api.nvim_buf_add_highlight(state.diffbar_buf, ns_diffbar, h[1], h[2], h[3], h[4])
    end
  else
    local text = "─  Diff Preview"
    vim.api.nvim_buf_set_lines(state.diffbar_buf, 0, -1, false, { text })
    vim.api.nvim_buf_add_highlight(state.diffbar_buf, ns_diffbar, "GitUIDiffBarSep", 0, 0, 3)
    vim.api.nvim_buf_add_highlight(state.diffbar_buf, ns_diffbar, "GitUIDiffBarHint", 0, 3, -1)
  end

  vim.bo[state.diffbar_buf].modifiable = false
end

function M.resize_status(delta)
  if not state.is_open then return end
  local cfg = require("git-ui.config")
  local editor_width = vim.o.columns
  -- vim.o.lines = total rows. Subtract tabline (1 if visible) and cmdheight.
  -- We set laststatus=0 so no statusline row to subtract.
  local tabline = (vim.o.showtabline == 0) and 0
    or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") == 1) and 0
    or 1
  local editor_height = vim.o.lines - tabline - vim.o.cmdheight
  local scrollbar_width = 2
  local diffbar_height = 1
  local diff_content_height = editor_height - diffbar_height
  local min_w = 20
  local max_w = math.floor(editor_width * 0.6)
  local cur_w = cfg.options.layout.status_width
  local new_w = math.max(min_w, math.min(max_w, cur_w + delta))
  if new_w == cur_w then return end
  cfg.options.layout.status_width = new_w
  local diff_w = math.max(1, editor_width - new_w - scrollbar_width)
  local status_height = editor_height - state.help_height

  pcall(vim.api.nvim_win_set_config, state.status_win, {
    relative = "editor", row = 0, col = 0, width = new_w, height = status_height,
  })
  pcall(vim.api.nvim_win_set_config, state.help_win, {
    relative = "editor", row = status_height, col = 0, width = new_w, height = state.help_height,
  })

  if state.sbs_mode then
    local divider_width = 1
    local left_w = math.floor((diff_w - divider_width) * state.sbs_left_ratio)
    local right_w = diff_w - divider_width - left_w
    if win_valid(state.diff_win) then
      pcall(vim.api.nvim_win_set_config, state.diff_win, {
        relative = "editor", row = 0, col = new_w, width = left_w, height = diff_content_height,
      })
    end
    if win_valid(state.divider_win) then
      pcall(vim.api.nvim_win_set_config, state.divider_win, {
        relative = "editor", row = 0, col = new_w + left_w, width = divider_width, height = diff_content_height,
      })
    end
    if win_valid(state.diff_right_win) then
      pcall(vim.api.nvim_win_set_config, state.diff_right_win, {
        relative = "editor", row = 0, col = new_w + left_w + divider_width, width = right_w, height = diff_content_height,
      })
    end
  else
    if win_valid(state.diff_win) then
      pcall(vim.api.nvim_win_set_config, state.diff_win, {
        relative = "editor", row = 0, col = new_w, width = diff_w, height = diff_content_height,
      })
    end
  end

  if win_valid(state.diffbar_win) then
    pcall(vim.api.nvim_win_set_config, state.diffbar_win, {
      relative = "editor", row = diff_content_height, col = new_w, width = diff_w + scrollbar_width, height = diffbar_height,
    })
  end
  if win_valid(state.scrollbar_win) then
    pcall(vim.api.nvim_win_set_config, state.scrollbar_win, {
      relative = "editor", row = 0, col = new_w + diff_w, width = scrollbar_width, height = diff_content_height,
    })
  end
end

---------------------------------------------------------------------------
-- Mouse drag resize
---------------------------------------------------------------------------

function M.setup_mouse_resize()
  local panel = require("git-ui.panel")

  -- Sidebar drag: left-drag anywhere on the divider column or nearby
  -- We use a global mouse handler that checks the column position
  local dragging = nil -- "sidebar" | "sbs_divider" | nil

  local function get_sidebar_col()
    return require("git-ui.config").options.layout.status_width
  end

  local function get_divider_col()
    if not state.sbs_mode then return nil end
    local cfg = require("git-ui.config")
    local sw = cfg.options.layout.status_width
    local editor_width = vim.o.columns
    local scrollbar_width = 2
    local diff_w = math.max(1, editor_width - sw - scrollbar_width)
    local divider_width = 1
    local left_w = math.floor((diff_w - divider_width) * state.sbs_left_ratio)
    return sw + left_w
  end

  -- On mouse click, determine if we're on a resize handle
  vim.keymap.set("n", "<LeftMouse>", function()
    -- Execute default click first to position cursor
    vim.cmd("normal! \\<LeftMouse>")
    local mouse_col = vim.fn.getmousepos().screencol
    local sidebar_col = get_sidebar_col()

    if math.abs(mouse_col - sidebar_col) <= 1 then
      dragging = "sidebar"
    elseif state.sbs_mode then
      local div_col = get_divider_col()
      if div_col and math.abs(mouse_col - div_col) <= 1 then
        dragging = "sbs_divider"
      end
    end
  end, { silent = true })

  vim.keymap.set("n", "<LeftDrag>", function()
    if not dragging or not state.is_open then return end
    local mouse_col = vim.fn.getmousepos().screencol
    local cfg = require("git-ui.config")

    if dragging == "sidebar" then
      local min_w = 20
      local max_w = math.floor(vim.o.columns * 0.6)
      local new_w = math.max(min_w, math.min(max_w, mouse_col))
      local cur_w = cfg.options.layout.status_width
      if new_w ~= cur_w then
        local delta = new_w - cur_w
        M.resize_status(delta)
        panel.render()
        panel.render_help()
      end
    elseif dragging == "sbs_divider" and state.sbs_mode then
      -- Resize left/right diff split
      local sw = cfg.options.layout.status_width
      local editor_width = vim.o.columns
      local scrollbar_width = 2
      local diff_w = math.max(1, editor_width - sw - scrollbar_width)
      local divider_width = 1

      -- mouse_col relative to diff area start
      local rel_col = mouse_col - sw
      local usable = diff_w - divider_width
      local min_pane = 10
      local left_w = math.max(min_pane, math.min(usable - min_pane, rel_col))
      local right_w = usable - left_w

      -- Store ratio so future re-layouts preserve it
      state.sbs_left_ratio = left_w / usable

      local tabline = (vim.o.showtabline == 0) and 0
        or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") == 1) and 0
        or 1
      local editor_height = vim.o.lines - tabline - vim.o.cmdheight
      local diff_content_height = editor_height - 1 -- diffbar

      if win_valid(state.diff_win) then
        pcall(vim.api.nvim_win_set_config, state.diff_win, {
          relative = "editor", row = 0, col = sw, width = left_w, height = diff_content_height,
        })
      end
      if win_valid(state.divider_win) then
        pcall(vim.api.nvim_win_set_config, state.divider_win, {
          relative = "editor", row = 0, col = sw + left_w, width = divider_width, height = diff_content_height,
        })
      end
      if win_valid(state.diff_right_win) then
        pcall(vim.api.nvim_win_set_config, state.diff_right_win, {
          relative = "editor", row = 0, col = sw + left_w + divider_width, width = right_w, height = diff_content_height,
        })
      end
    end
  end, { silent = true })

  vim.keymap.set("n", "<LeftRelease>", function()
    dragging = nil
    vim.cmd("normal! \\<LeftRelease>")
  end, { silent = true })
end

---------------------------------------------------------------------------
-- Treesitter syntax highlighting for diff buffers
---------------------------------------------------------------------------

--- Parse valid source lines with treesitter (via a temp buffer) and apply
--- token highlights to the display buffer. `line_map` maps 1-based source
--- line indices to 1-based display line indices.
local function apply_ts_highlights(buf, source_lines, line_map, lang, display_lines)
  local tmp_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(tmp_buf, 0, -1, false, source_lines)

  local ok, parser = pcall(vim.treesitter.get_parser, tmp_buf, lang)
  if not ok or not parser then
    vim.api.nvim_buf_delete(tmp_buf, { force = true })
    return
  end

  local trees = parser:parse()
  if not trees or not trees[1] then
    vim.api.nvim_buf_delete(tmp_buf, { force = true })
    return
  end

  local ok2, query = pcall(vim.treesitter.query.get, lang, "highlights")
  if not ok2 or not query then
    vim.api.nvim_buf_delete(tmp_buf, { force = true })
    return
  end

  for id, node in query:iter_captures(trees[1]:root(), tmp_buf) do
    local hl_group = "@" .. query.captures[id] .. "." .. lang
    local sr, sc, er, ec = node:range()

    if sr == er then
      local disp_row = line_map[sr + 1]
      if disp_row then
        pcall(vim.api.nvim_buf_set_extmark, buf, ns_ts, disp_row - 1, sc, {
          end_col = ec,
          hl_group = hl_group,
          priority = 100,
        })
      end
    else
      for row = sr, er do
        local disp_row = line_map[row + 1]
        if disp_row then
          local c_start = (row == sr) and sc or 0
          local c_end = (row == er) and ec or #(display_lines[disp_row] or "")
          pcall(vim.api.nvim_buf_set_extmark, buf, ns_ts, disp_row - 1, c_start, {
            end_col = c_end,
            hl_group = hl_group,
            priority = 100,
          })
        end
      end
    end
  end

  vim.api.nvim_buf_delete(tmp_buf, { force = true })
end

---------------------------------------------------------------------------
-- Diff rendering
---------------------------------------------------------------------------

--- Tokenize a string into word/non-word segments for inline diff.
local function tokenize(str)
  local tokens = {}
  local pos = 1
  while pos <= #str do
    local s, e = str:find("[%w_]+", pos)
    if s == pos then
      table.insert(tokens, { text = str:sub(s, e), byte_start = s - 1, byte_end = e })
      pos = e + 1
    else
      table.insert(tokens, { text = str:sub(pos, pos), byte_start = pos - 1, byte_end = pos })
      pos = pos + 1
    end
  end
  return tokens
end

--- Compute token-level inline diff between two strings.
--- Returns two lists of {start, end} byte ranges (0-based, exclusive end)
--- for the changed segments in each string.
local function compute_inline_ranges(old_str, new_str)
  local old_tok = tokenize(old_str)
  local new_tok = tokenize(new_str)
  local m, n = #old_tok, #new_tok

  -- LCS dynamic programming
  local dp = {}
  for i = 0, m do dp[i] = {} end
  for i = 0, m do for j = 0, n do dp[i][j] = 0 end end
  for i = 1, m do
    for j = 1, n do
      if old_tok[i].text == new_tok[j].text then
        dp[i][j] = dp[i - 1][j - 1] + 1
      else
        dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
      end
    end
  end

  -- Backtrack to mark matched tokens
  local old_matched, new_matched = {}, {}
  local i, j = m, n
  while i > 0 and j > 0 do
    if old_tok[i].text == new_tok[j].text then
      old_matched[i] = true; new_matched[j] = true
      i = i - 1; j = j - 1
    elseif dp[i - 1][j] > dp[i][j - 1] then
      i = i - 1
    else
      j = j - 1
    end
  end

  -- Build byte ranges from unmatched tokens, merging adjacent
  local function get_ranges(tokens, matched)
    local ranges = {}
    for idx, tok in ipairs(tokens) do
      if not matched[idx] then
        if #ranges > 0 and ranges[#ranges][2] == tok.byte_start then
          ranges[#ranges][2] = tok.byte_end
        else
          table.insert(ranges, { tok.byte_start, tok.byte_end })
        end
      end
    end
    return ranges
  end

  return get_ranges(old_tok, old_matched), get_ranges(new_tok, new_matched)
end

--- Split unified display/line_types into left (old) and right (new) side arrays.
--- Both sides have the same number of rows for scrollbind alignment.
--- Also returns `pairs`: list of {left_row, right_row} for paired del/add lines.
local function split_diff_to_sides(display, line_types, hunk_idx_map)
  local left_lines, left_types = {}, {}
  local right_lines, right_types = {}, {}
  local row_hunk_idx = {}
  local pairs_list = {} -- { {left_row, right_row}, ... } for inline diff

  local i = 1
  local n = #display
  while i <= n do
    local lt = line_types[i]
    if lt == "context" or lt == "separator" or lt == "blank" then
      table.insert(left_lines, display[i])
      table.insert(left_types, lt)
      table.insert(right_lines, display[i])
      table.insert(right_types, lt)
      row_hunk_idx[#left_lines] = hunk_idx_map[i]
      i = i + 1
    elseif lt == "del" then
      -- Collect contiguous del block
      local del_start = i
      while i <= n and line_types[i] == "del" do i = i + 1 end
      -- Collect immediately following add block
      local add_start = i
      while i <= n and line_types[i] == "add" do i = i + 1 end
      local del_count = add_start - del_start
      local add_count = i - add_start
      local max_count = math.max(del_count, add_count)
      for j = 0, max_count - 1 do
        if j < del_count then
          table.insert(left_lines, display[del_start + j])
          table.insert(left_types, "del")
        else
          table.insert(left_lines, "")
          table.insert(left_types, "filler")
        end
        if j < add_count then
          table.insert(right_lines, display[add_start + j])
          table.insert(right_types, "add")
        else
          table.insert(right_lines, "")
          table.insert(right_types, "filler")
        end
        -- Track paired lines for inline diff
        if j < del_count and j < add_count then
          table.insert(pairs_list, { #left_lines, #right_lines })
        end
        row_hunk_idx[#left_lines] = hunk_idx_map[del_start]
      end
    elseif lt == "add" then
      -- Standalone add (not preceded by del)
      table.insert(left_lines, "")
      table.insert(left_types, "filler")
      table.insert(right_lines, display[i])
      table.insert(right_types, "add")
      row_hunk_idx[#left_lines] = hunk_idx_map[i]
      i = i + 1
    else
      -- Unknown type, pass through to both
      table.insert(left_lines, display[i])
      table.insert(left_types, lt)
      table.insert(right_lines, display[i])
      table.insert(right_types, lt)
      row_hunk_idx[#left_lines] = hunk_idx_map[i]
      i = i + 1
    end
  end
  return left_lines, left_types, right_lines, right_types, row_hunk_idx, pairs_list
end

--- Apply diff extmarks (line highlight + sign) to a buffer given its line types.
--- Uses hl_group + hl_eol (not line_hl_group) so inline highlights can override via priority.
local function apply_diff_extmarks(buf, ns, lines, types)
  for i, lt in ipairs(types) do
    if lt == "add" then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        end_row = i - 1, end_col = #lines[i],
        hl_group = "GitUIDiffAdd", hl_eol = true,
        sign_text = "▎", sign_hl_group = "GitUIDiffAddSign",
        priority = 10,
      })
    elseif lt == "del" then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        end_row = i - 1, end_col = #lines[i],
        hl_group = "GitUIDiffDelete", hl_eol = true,
        sign_text = "▎", sign_hl_group = "GitUIDiffDelSign",
        priority = 10,
      })
    elseif lt == "filler" then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        end_row = i - 1, end_col = #lines[i],
        hl_group = "GitUIDiffFiller", hl_eol = true,
        priority = 10,
      })
    elseif lt == "separator" then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        end_col = #lines[i],
        hl_group = "GitUISeparator",
        priority = 100,
      })
    end
  end
end

function M.set_diff_lines(lines, opts)
  opts = opts or {}
  if not buf_valid(state.diff_buf) then return end

  -- Store for re-render on resize
  state.raw_diff_lines = lines
  state.last_diff_opts = opts
  state.display_to_hunk_idx = {}
  state.display_to_conflict_idx = {}
  state.conflict_count = 0

  -- Stop any previous treesitter highlighting
  pcall(vim.treesitter.stop, state.diff_buf)
  if buf_valid(state.diff_right_buf) then
    pcall(vim.treesitter.stop, state.diff_right_buf)
  end

  vim.bo[state.diff_buf].modifiable = true
  if buf_valid(state.diff_right_buf) then
    vim.bo[state.diff_right_buf].modifiable = true
  end

  -- Process raw diff lines: strip prefixes
  local display = {}
  local line_types = {}
  -- Temporary hunk index map (unified display row -> hunk idx)
  local unified_hunk_map = {}

  if opts.raw then
    display = lines
    for i = 1, #display do line_types[i] = "context" end
  elseif opts.conflict then
    display = lines
    local hint_lines = opts.hint_lines or 0
    local block = nil
    local conflict_idx = 0
    for i, line in ipairs(display) do
      if i <= hint_lines then
        line_types[i] = "hint"
      elseif line:match("^<<<<<<<") then
        conflict_idx = conflict_idx + 1
        line_types[i] = "conflict_marker"; block = "ours"
        state.display_to_conflict_idx[i] = conflict_idx
      elseif line:match("^=======$") then
        line_types[i] = "conflict_separator"; block = "theirs"
        state.display_to_conflict_idx[i] = conflict_idx
      elseif line:match("^>>>>>>>") then
        line_types[i] = "conflict_marker"; block = nil
        state.display_to_conflict_idx[i] = conflict_idx
      elseif block == "ours" then
        line_types[i] = "conflict_ours"
        state.display_to_conflict_idx[i] = conflict_idx
      elseif block == "theirs" then
        line_types[i] = "conflict_theirs"
        state.display_to_conflict_idx[i] = conflict_idx
      else
        line_types[i] = "context"
      end
    end
    state.conflict_count = conflict_idx
  else
    local hunk_idx = 0
    local is_first_hunk = true

    for _, line in ipairs(lines) do
      if line:match("^diff ") or line:match("^index ") or line:match("^%-%-%- ")
        or line:match("^%+%+%+ ") or line:match("^new file") or line:match("^deleted file") then
        -- skip metadata
      elseif line:match("^@@") then
        hunk_idx = hunk_idx + 1
        if not is_first_hunk then
          table.insert(display, "")
          table.insert(line_types, "blank")
          unified_hunk_map[#display] = hunk_idx
          table.insert(display, string.rep("╌", 60))
          table.insert(line_types, "separator")
          unified_hunk_map[#display] = hunk_idx
          table.insert(display, "")
          table.insert(line_types, "blank")
          unified_hunk_map[#display] = hunk_idx
        end
        is_first_hunk = false
      elseif hunk_idx > 0 then
        local first = line:sub(1, 1)
        if first == "+" then
          table.insert(display, line:sub(2)); table.insert(line_types, "add")
        elseif first == "-" then
          table.insert(display, line:sub(2)); table.insert(line_types, "del")
        elseif first == " " then
          table.insert(display, line:sub(2)); table.insert(line_types, "context")
        else
          table.insert(display, line); table.insert(line_types, "context")
        end
        unified_hunk_map[#display] = hunk_idx
      end
    end

    if #display == 0 and #lines > 0 then display = lines end
  end

  -- Detect language for syntax highlighting
  local filepath = opts.filepath
  if not filepath then
    for _, line in ipairs(lines) do
      local match = line:match("^%+%+%+ b/(.+)$")
      if match then filepath = match; break end
    end
  end

  -- Use SBS for non-conflict diffs when mode is active
  local use_sbs = state.sbs_mode and not opts.conflict and #line_types > 0

  if use_sbs and buf_valid(state.diff_right_buf) then
    -----------------------------------------------------------------------
    -- Side-by-side rendering
    -----------------------------------------------------------------------
    local left, lt_left, right, lt_right, sbs_hunk_map, sbs_pairs =
      split_diff_to_sides(display, line_types, unified_hunk_map)

    state.display_to_hunk_idx = sbs_hunk_map

    -- Set buffer contents
    vim.api.nvim_buf_set_lines(state.diff_buf, 0, -1, false, left)
    vim.api.nvim_buf_set_lines(state.diff_right_buf, 0, -1, false, right)

    -- Clear extmarks
    vim.api.nvim_buf_clear_namespace(state.diff_buf, ns_ts, 0, -1)
    vim.api.nvim_buf_clear_namespace(state.diff_buf, ns_diff, 0, -1)
    vim.api.nvim_buf_clear_namespace(state.diff_right_buf, ns_ts_right, 0, -1)
    vim.api.nvim_buf_clear_namespace(state.diff_right_buf, ns_diff_right, 0, -1)

    -- Apply diff extmarks (line highlights, signs)
    apply_diff_extmarks(state.diff_buf, ns_diff, left, lt_left)
    apply_diff_extmarks(state.diff_right_buf, ns_diff_right, right, lt_right)

    -- Inline word-level diff highlights for paired del/add lines
    for _, pair in ipairs(sbs_pairs) do
      local lr, rr = pair[1], pair[2]
      local old_str = left[lr] or ""
      local new_str = right[rr] or ""
      if old_str ~= new_str and #old_str > 0 and #new_str > 0 then
        local old_ranges, new_ranges = compute_inline_ranges(old_str, new_str)
        for _, r in ipairs(old_ranges) do
          pcall(vim.api.nvim_buf_set_extmark, state.diff_buf, ns_diff, lr - 1, r[1], {
            end_col = r[2], hl_group = "GitUIDiffDelInline", priority = 20,
          })
        end
        for _, r in ipairs(new_ranges) do
          pcall(vim.api.nvim_buf_set_extmark, state.diff_right_buf, ns_diff_right, rr - 1, r[1], {
            end_col = r[2], hl_group = "GitUIDiffAddInline", priority = 20,
          })
        end
      end
    end

    -- Syntax highlighting
    if filepath then
      local ft = vim.filetype.match({ filename = filepath })
      if ft then
        pcall(vim.treesitter.stop, state.diff_buf)
        pcall(vim.treesitter.stop, state.diff_right_buf)
        vim.bo[state.diff_buf].syntax = ft
        vim.bo[state.diff_right_buf].syntax = ft

        pcall(function()
          local lang = vim.treesitter.language.get_lang(ft) or ft
          -- Left pane: old source (context + del lines)
          local old_src, old_map = {}, {}
          for i, lt in ipairs(lt_left) do
            if lt == "context" or lt == "del" then
              table.insert(old_src, left[i])
              old_map[#old_src] = i
            end
          end
          if #old_src > 0 then
            apply_ts_highlights(state.diff_buf, old_src, old_map, lang, left)
          end
          -- Right pane: new source (context + add lines)
          local new_src, new_map = {}, {}
          for i, lt in ipairs(lt_right) do
            if lt == "context" or lt == "add" then
              table.insert(new_src, right[i])
              new_map[#new_src] = i
            end
          end
          if #new_src > 0 then
            apply_ts_highlights(state.diff_right_buf, new_src, new_map, lang, right)
          end
        end)
      end
    end

    -- Track changes for scrollbar + navigation (use left pane rows)
    state.change_starts = {}
    state.change_idx = 0
    state.change_lines_set = {}
    for i, lt in ipairs(lt_left) do
      if lt == "del" then state.change_lines_set[i] = "del" end
    end
    for i, lt in ipairs(lt_right) do
      if lt == "add" then state.change_lines_set[i] = "add" end
    end
    for i = 1, #lt_left do
      local l = lt_left[i]
      local r = lt_right[i]
      if l == "del" or r == "add" then
        local prev_l = i > 1 and lt_left[i - 1] or "context"
        local prev_r = i > 1 and lt_right[i - 1] or "context"
        if prev_l ~= "del" and prev_l ~= "filler" and prev_r ~= "add" and prev_r ~= "filler" then
          table.insert(state.change_starts, i)
        end
      end
    end

    vim.bo[state.diff_buf].modifiable = false
    vim.bo[state.diff_right_buf].modifiable = false

    -- Auto-scroll to first change and sync scrollbind
    if #state.change_starts > 0 then
      local first = state.change_starts[1]
      if win_valid(state.diff_win) then
        pcall(vim.api.nvim_win_set_cursor, state.diff_win, { first, 0 })
        pcall(vim.api.nvim_win_call, state.diff_win, function() vim.cmd("normal! zz") end)
      end
      if win_valid(state.diff_right_win) then
        pcall(vim.api.nvim_win_set_cursor, state.diff_right_win, { first, 0 })
        pcall(vim.api.nvim_win_call, state.diff_right_win, function() vim.cmd("normal! zz") end)
      end
    end

  else
    -----------------------------------------------------------------------
    -- Unified rendering (existing path)
    -----------------------------------------------------------------------
    if not opts.conflict then
      state.display_to_hunk_idx = unified_hunk_map
    end

    vim.api.nvim_buf_set_lines(state.diff_buf, 0, -1, false, display)

    vim.api.nvim_buf_clear_namespace(state.diff_buf, ns_ts, 0, -1)
    vim.api.nvim_buf_clear_namespace(state.diff_buf, ns_diff, 0, -1)

    -- Clear right pane if it exists (conflict fallback in SBS mode)
    if buf_valid(state.diff_right_buf) then
      vim.api.nvim_buf_set_lines(state.diff_right_buf, 0, -1, false, { "" })
      vim.api.nvim_buf_clear_namespace(state.diff_right_buf, ns_ts_right, 0, -1)
      vim.api.nvim_buf_clear_namespace(state.diff_right_buf, ns_diff_right, 0, -1)
      vim.bo[state.diff_right_buf].modifiable = false
    end

    -- Syntax highlighting
    if filepath then
      local ft = vim.filetype.match({ filename = filepath })
      if ft then
        pcall(vim.treesitter.stop, state.diff_buf)
        if opts.conflict then
          vim.bo[state.diff_buf].syntax = ft
          local lang = vim.treesitter.language.get_lang(ft) or ft
          pcall(vim.treesitter.start, state.diff_buf, lang)
        else
          vim.bo[state.diff_buf].syntax = ft
          pcall(function()
            local lang = vim.treesitter.language.get_lang(ft) or ft
            local new_lines, new_map = {}, {}
            local has_dels = false
            for i, lt in ipairs(line_types) do
              if lt == "context" or lt == "add" then
                table.insert(new_lines, display[i]); new_map[#new_lines] = i
              elseif lt == "del" then has_dels = true end
            end
            if #new_lines > 0 then
              apply_ts_highlights(state.diff_buf, new_lines, new_map, lang, display)
            end
            if has_dels then
              local old_lines, old_map = {}, {}
              for i, lt in ipairs(line_types) do
                if lt == "context" or lt == "del" then
                  table.insert(old_lines, display[i]); old_map[#old_lines] = i
                end
              end
              if #old_lines > 0 then
                apply_ts_highlights(state.diff_buf, old_lines, old_map, lang, display)
              end
            end
          end)
        end
      end
    end

    -- Track changes + apply extmarks
    state.change_starts = {}
    state.change_idx = 0
    state.change_lines_set = {}

    for i, lt in ipairs(line_types) do
      if lt == "add" then
        vim.api.nvim_buf_set_extmark(state.diff_buf, ns_diff, i - 1, 0, {
          line_hl_group = "GitUIDiffAdd", sign_text = "▎",
          sign_hl_group = "GitUIDiffAddSign", priority = 10,
        })
        state.change_lines_set[i] = "add"
      elseif lt == "del" then
        vim.api.nvim_buf_set_extmark(state.diff_buf, ns_diff, i - 1, 0, {
          line_hl_group = "GitUIDiffDelete", sign_text = "▎",
          sign_hl_group = "GitUIDiffDelSign", priority = 10,
        })
        state.change_lines_set[i] = "del"
      elseif lt == "separator" then
        vim.api.nvim_buf_set_extmark(state.diff_buf, ns_diff, i - 1, 0, {
          end_col = #display[i], hl_group = "GitUISeparator", priority = 100,
        })
      elseif lt == "conflict_marker" or lt == "conflict_separator" then
        vim.api.nvim_buf_set_extmark(state.diff_buf, ns_diff, i - 1, 0, {
          line_hl_group = "GitUIConflictMarker", sign_text = "▎",
          sign_hl_group = "GitUIConflictMarkerSign", priority = 12,
        })
        state.change_lines_set[i] = "conflict"
        if display[i] and display[i]:match("^<<<<<<<") then
          table.insert(state.change_starts, i)
        end
      elseif lt == "conflict_ours" then
        vim.api.nvim_buf_set_extmark(state.diff_buf, ns_diff, i - 1, 0, {
          line_hl_group = "GitUIConflictOurs", priority = 11,
        })
        state.change_lines_set[i] = "conflict"
      elseif lt == "conflict_theirs" then
        vim.api.nvim_buf_set_extmark(state.diff_buf, ns_diff, i - 1, 0, {
          line_hl_group = "GitUIConflictTheirs", priority = 11,
        })
        state.change_lines_set[i] = "conflict"
      elseif lt == "hint" then
        vim.api.nvim_buf_set_extmark(state.diff_buf, ns_diff, i - 1, 0, {
          end_col = #display[i], hl_group = "GitUIConflictHint", priority = 100,
        })
      end

      if lt == "add" or lt == "del" then
        local prev_lt = i > 1 and line_types[i - 1] or "context"
        if prev_lt ~= "add" and prev_lt ~= "del" then
          table.insert(state.change_starts, i)
        end
      end
    end

    vim.bo[state.diff_buf].modifiable = false

    -- Auto-scroll to first change
    if #state.change_starts > 0 and win_valid(state.diff_win) then
      pcall(vim.api.nvim_win_set_cursor, state.diff_win, { state.change_starts[1], 0 })
      pcall(vim.api.nvim_win_call, state.diff_win, function() vim.cmd("normal! zz") end)
    end
  end

  M.update_scrollbar()
end

---------------------------------------------------------------------------
-- Scrollbar
---------------------------------------------------------------------------

function M.update_scrollbar()
  if not buf_valid(state.scrollbar_buf) or not win_valid(state.scrollbar_win) then return end
  if not buf_valid(state.diff_buf) or not win_valid(state.diff_win) then return end

  local total_lines = vim.api.nvim_buf_line_count(state.diff_buf)
  local win_height = vim.api.nvim_win_get_height(state.scrollbar_win)
  if total_lines == 0 or win_height == 0 then return end

  -- Current viewport in diff panel
  local top_line = vim.fn.line("w0", state.diff_win)
  local bot_line = vim.fn.line("w$", state.diff_win)

  -- Map each change to a scrollbar position
  local sb_changes = {} -- sb_pos -> "add" | "del" | "conflict"
  for line_nr, change_type in pairs(state.change_lines_set) do
    local sb_pos = math.ceil(line_nr / total_lines * win_height)
    sb_pos = math.max(1, math.min(sb_pos, win_height))
    if not sb_changes[sb_pos] then
      sb_changes[sb_pos] = change_type
    end
  end

  -- Map viewport to scrollbar positions
  local vp_start = math.ceil(top_line / total_lines * win_height)
  local vp_end = math.ceil(bot_line / total_lines * win_height)
  vp_start = math.max(1, math.min(vp_start, win_height))
  vp_end = math.max(1, math.min(vp_end, win_height))

  -- Build scrollbar
  local sb_lines = {}
  local sb_hls = {}

  for i = 1, win_height do
    table.insert(sb_lines, "  ")
    local in_vp = i >= vp_start and i <= vp_end
    local change = sb_changes[i]
    local hl
    if change == "add" then
      hl = in_vp and "GitUIScrollAddVP" or "GitUIScrollAdd"
    elseif change == "del" then
      hl = in_vp and "GitUIScrollDelVP" or "GitUIScrollDel"
    elseif change == "conflict" then
      hl = in_vp and "GitUIScrollConflictVP" or "GitUIScrollConflict"
    else
      hl = in_vp and "GitUIScrollVP" or "GitUIScrollTrack"
    end
    table.insert(sb_hls, { group = hl, line = i - 1 })
  end

  vim.bo[state.scrollbar_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.scrollbar_buf, 0, -1, false, sb_lines)
  vim.api.nvim_buf_clear_namespace(state.scrollbar_buf, ns_scrollbar, 0, -1)
  for _, hl in ipairs(sb_hls) do
    vim.api.nvim_buf_add_highlight(state.scrollbar_buf, ns_scrollbar, hl.group, hl.line, 0, -1)
  end
  vim.bo[state.scrollbar_buf].modifiable = false
end

---------------------------------------------------------------------------
-- Side-by-side scroll sync
---------------------------------------------------------------------------

local syncing_scroll = false

local function sync_win_to(src_win, dst_win)
  if not win_valid(src_win) or not win_valid(dst_win) then return end
  local top = vim.fn.line("w0", src_win)
  local src_cursor = vim.api.nvim_win_get_cursor(src_win)
  -- Clamp cursor row to dst buffer line count
  local dst_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(dst_win))
  local row = math.min(src_cursor[1], dst_count)
  pcall(vim.api.nvim_win_set_cursor, dst_win, { row, src_cursor[2] })
  pcall(vim.api.nvim_win_call, dst_win, function()
    vim.cmd("normal! " .. top .. "zt")
  end)
end

--- Set up autocmds for scroll sync on both diff panes.
function M.setup_scroll_sync()
  if not state.sbs_mode then return end
  local group = vim.api.nvim_create_augroup("git-ui-sbs-sync", { clear = true })

  -- WinScrolled fires for ANY window scroll (including mouse on unfocused pane)
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function(ev)
      if syncing_scroll then return end
      if not state.sbs_mode then return end
      -- ev.match is the scrolled window id as a string
      local scrolled = tonumber(ev.match)
      local src_win, dst_win
      if scrolled == state.diff_win then
        src_win, dst_win = state.diff_win, state.diff_right_win
      elseif scrolled == state.diff_right_win then
        src_win, dst_win = state.diff_right_win, state.diff_win
      else
        return
      end
      syncing_scroll = true
      sync_win_to(src_win, dst_win)
      syncing_scroll = false
    end,
  })

  -- CursorMoved for keyboard navigation sync
  for _, buf in ipairs({ state.diff_buf, state.diff_right_buf }) do
    if buf_valid(buf) then
      vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        buffer = buf,
        callback = function()
          if syncing_scroll then return end
          if not state.sbs_mode then return end
          local cur = vim.api.nvim_get_current_win()
          local src_win, dst_win
          if cur == state.diff_win then
            src_win, dst_win = state.diff_win, state.diff_right_win
          elseif cur == state.diff_right_win then
            src_win, dst_win = state.diff_right_win, state.diff_win
          else
            return
          end
          syncing_scroll = true
          sync_win_to(src_win, dst_win)
          syncing_scroll = false
        end,
      })
    end
  end
end

---------------------------------------------------------------------------
-- Focus & navigation
---------------------------------------------------------------------------

function M.focus_status()
  if win_valid(state.status_win) then
    vim.api.nvim_set_current_win(state.status_win)
  end
end

function M.focus_diff()
  -- In SBS mode, focus the left pane by default
  if win_valid(state.diff_win) then
    vim.api.nvim_set_current_win(state.diff_win)
  end
end

--- Check if the given window is one of the diff panes.
function M.is_diff_win(win)
  return win == state.diff_win or win == state.diff_right_win
end

--- Get the active diff window (whichever diff pane has focus, or left pane as fallback).
local function active_diff_win()
  local cur = vim.api.nvim_get_current_win()
  if cur == state.diff_right_win and win_valid(state.diff_right_win) then
    return state.diff_right_win
  end
  -- Fallback to left pane regardless of current focus (e.g. from status panel)
  if win_valid(state.diff_win) then return state.diff_win end
  if win_valid(state.diff_right_win) then return state.diff_right_win end
  return nil
end

--- Jump both SBS panes to the given line.
local function jump_diff_to(line_nr)
  -- Guard against scroll sync interfering during the jump
  syncing_scroll = true
  if win_valid(state.diff_win) then
    pcall(vim.api.nvim_win_set_cursor, state.diff_win, { line_nr, 0 })
    pcall(vim.api.nvim_win_call, state.diff_win, function() vim.cmd("normal! zz") end)
  end
  if state.sbs_mode and win_valid(state.diff_right_win) then
    pcall(vim.api.nvim_win_set_cursor, state.diff_right_win, { line_nr, 0 })
    pcall(vim.api.nvim_win_call, state.diff_right_win, function() vim.cmd("normal! zz") end)
  end
  syncing_scroll = false
  M.update_scrollbar()
end

function M.next_change()
  if #state.change_starts == 0 then return end
  state.change_idx = state.change_idx + 1
  if state.change_idx > #state.change_starts then
    state.change_idx = 1
  end
  jump_diff_to(state.change_starts[state.change_idx])
end

function M.prev_change()
  if #state.change_starts == 0 then return end
  state.change_idx = state.change_idx - 1
  if state.change_idx < 1 then
    state.change_idx = #state.change_starts
  end
  jump_diff_to(state.change_starts[state.change_idx])
end

return M
