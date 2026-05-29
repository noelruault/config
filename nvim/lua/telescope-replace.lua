local M = {}

local ns = vim.api.nvim_create_namespace("telescope_replace")

local function setup_highlights()
  vim.api.nvim_set_hl(0, "TRFocusOld", { underline = true, sp = "#cdd6f4" })
  vim.api.nvim_set_hl(0, "TRFocusNew", { underline = true, sp = "#cdd6f4" })
  vim.api.nvim_set_hl(0, "TRFocusSearch", { underline = true, sp = "#cdd6f4" })
end

local function escape_lua_pattern(s)
  return (s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

local function escape_lua_replacement(s)
  return (s:gsub("%%", "%%%%"))
end

local function collect_matches(search_term)
  local matches = {}
  local output = vim.fn.systemlist({ "rg", "--vimgrep", "--fixed-strings", "--no-heading", search_term })
  for _, line in ipairs(output) do
    local filename, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
    if filename then
      table.insert(matches, {
        filename = filename,
        lnum = tonumber(lnum),
        col = tonumber(col),
        text = text,
      })
    end
  end
  return matches
end

local function apply_replacements(matches_to_replace, search_term, replacement)
  local by_file = {}
  for _, match in ipairs(matches_to_replace) do
    by_file[match.filename] = by_file[match.filename] or {}
    table.insert(by_file[match.filename], match)
  end

  local search_len = #search_term
  local count = 0

  for filename, file_matches in pairs(by_file) do
    table.sort(file_matches, function(a, b)
      if a.lnum == b.lnum then return a.col > b.col end
      return a.lnum > b.lnum
    end)

    local bufnr = vim.fn.bufnr(filename)
    local lines
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    else
      lines = vim.fn.readfile(filename)
    end

    for _, match in ipairs(file_matches) do
      local line = lines[match.lnum]
      if line then
        lines[match.lnum] = line:sub(1, match.col - 1) .. replacement .. line:sub(match.col + search_len)
        count = count + 1
      end
    end

    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("silent write")
      end)
    else
      vim.fn.writefile(lines, filename)
    end
  end

  return count
end

function M.open(search_term)
  if not search_term or search_term == "" then return end

  setup_highlights()

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local sorters = require("telescope.sorters")
  local previewers = require("telescope.previewers")
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local matches = collect_matches(search_term)
  if #matches == 0 then
    vim.notify("No matches found for: " .. search_term, vim.log.levels.INFO)
    return
  end

  local escaped = escape_lua_pattern(search_term)
  local current_replacement = ""
  local preview_ref = {}
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")

  -- Render the file preview with git-diff style
  local function render_preview(entry)
    local bufnr = preview_ref.bufnr
    local winid = preview_ref.winid
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

    local lines = vim.fn.readfile(entry.filename)
    local replacement = current_replacement
    local lnum = math.min(entry.lnum, #lines)
    if lnum < 1 then lnum = 1 end

    -- Track where the diff lines are inserted so we can highlight them
    local diff_old_lnum = nil -- 0-indexed line of the red (old) line
    local diff_new_lnum = nil -- 0-indexed line of the green (new) line
    local original_line = lines[lnum]
    local scroll_lnum = lnum

    if replacement ~= "" and original_line then
      local replaced_line = original_line:gsub(escaped, escape_lua_replacement(replacement))
      -- Insert old (red) and new (green) lines, replacing the original
      table.remove(lines, lnum)
      table.insert(lines, lnum, replaced_line)
      table.insert(lines, lnum, original_line)
      -- Now: lines[lnum] = original (red), lines[lnum+1] = replaced (green)
      diff_old_lnum = lnum - 1 -- 0-indexed
      diff_new_lnum = lnum     -- 0-indexed
      scroll_lnum = lnum       -- scroll to the old line
    end

    -- Set lines
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    -- Set filetype for syntax highlighting
    pcall(function()
      local ft = vim.filetype.match({ filename = entry.filename, buf = bufnr })
      if ft then vim.bo[bufnr].filetype = ft end
    end)
    vim.bo[bufnr].modifiable = false

    local saved_lines = lines
    local search_len = #search_term
    local focused_col = entry.col -- 1-indexed column of the focused occurrence

    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      if not winid or not vim.api.nvim_win_is_valid(winid) then return end

      -- Scroll to match and center
      pcall(function()
        vim.api.nvim_win_set_cursor(winid, { scroll_lnum, math.max(0, (entry.col or 1) - 1) })
        vim.api.nvim_win_call(winid, function()
          vim.cmd("normal! zz")
        end)
      end)

      -- Use matchaddpos (window-level) instead of extmarks — much more reliable
      vim.api.nvim_win_call(winid, function()
        vim.fn.clearmatches()

        if replacement ~= "" and diff_old_lnum and diff_new_lnum then
          -- Red/green line backgrounds
          vim.fn.matchaddpos("DiffDelete", { diff_old_lnum + 1 }, 10)
          vim.fn.matchaddpos("DiffAdd", { diff_new_lnum + 1 }, 10)

          -- Highlight occurrences on the red line
          local old_line = saved_lines[diff_old_lnum + 1]
          if old_line then
            local start = 1
            while true do
              local s, e = old_line:find(search_term, start, true)
              if not s then break end
              if s == focused_col then
                vim.fn.matchaddpos("TRFocusOld", { { diff_old_lnum + 1, s, e - s + 1 } }, 1000)
              end
              start = e + 1
            end
          end

          -- Calculate focused column on the replaced line
          local col_offset = 0
          local check = 1
          while true do
            local s, e = original_line:find(search_term, check, true)
            if not s or s >= focused_col then break end
            col_offset = col_offset + (#replacement - search_len)
            check = e + 1
          end
          local focused_new_col = focused_col + col_offset

          -- Highlight occurrences on the green line
          local new_line = saved_lines[diff_new_lnum + 1]
          if new_line then
            local start = 1
            while true do
              local s, e = new_line:find(replacement, start, true)
              if not s then break end
              if s == focused_new_col then
                vim.fn.matchaddpos("TRFocusNew", { { diff_new_lnum + 1, s, e - s + 1 } }, 1000)
              end
              start = e + 1
            end
          end
        else
          -- No replacement: line background + search term highlights
          vim.fn.matchaddpos("CursorLine", { lnum }, 10)

          local line = saved_lines[lnum]
          if line then
            local start = 1
            while true do
              local s, e = line:find(search_term, start, true)
              if not s then break end
              if s == focused_col then
                vim.fn.matchaddpos("TRFocusSearch", { { lnum, s, e - s + 1 } }, 1000)
              else
                vim.fn.matchaddpos("Search", { { lnum, s, e - s + 1 } }, 100)
              end
              start = e + 1
            end
          end
        end
      end)
    end, 10)
  end

  -- Build finder with current replacement applied
  local function make_finder(replacement)
    return finders.new_table({
      results = matches,
      entry_maker = function(match)
        local text = vim.fn.trim(match.text)

        return {
          value = match,
          display = function()
            local display_text = text
            if replacement and replacement ~= "" then
              display_text = text:gsub(escaped, escape_lua_replacement(replacement))
            end

            local icon, icon_hl = "", nil
            if has_devicons then
              local i, h = devicons.get_icon(match.filename, nil, { default = true })
              if i then icon, icon_hl = i .. " ", h end
            end

            local loc = match.filename .. ":" .. match.lnum .. " "
            local display_str = icon .. loc .. display_text
            local highlights = {}
            local offset = 0

            if icon ~= "" and icon_hl then
              table.insert(highlights, { { 0, #icon - 1 }, icon_hl })
              offset = #icon
            end

            table.insert(highlights, { { offset, offset + #loc - 1 }, "TelescopeResultsIdentifier" })
            offset = offset + #loc

            -- Highlight the replacement portions
            if replacement and replacement ~= "" then
              local s_start = 1
              while true do
                local s, e = display_text:find(replacement, s_start, true)
                if not s then break end
                table.insert(highlights, { { offset + s - 1, offset + e }, "TelescopeMatching" })
                s_start = e + 1
              end
            end

            return display_str, highlights
          end,
          ordinal = match.filename .. ":" .. tostring(match.lnum),
          filename = match.filename,
          lnum = match.lnum,
          col = match.col,
        }
      end,
    })
  end

  local previewer = previewers.new_buffer_previewer({
    title = "Replace Preview",
    define_preview = function(self, entry)
      preview_ref.bufnr = self.state.bufnr
      preview_ref.winid = self.state.winid
      render_preview(entry)
    end,
  })

  local title = string.format("Replace '%s' (%d matches) │ <CR> one  <C-a> all", search_term, #matches)

  pickers.new({
    layout_strategy = "horizontal",
    layout_config = {
      width = 0.95,
      height = 0.85,
      preview_width = 0.5,
    },
  }, {
    prompt_title = title,
    finder = make_finder(""),
    sorter = sorters.empty(),
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, map)
      vim.api.nvim_buf_attach(prompt_bufnr, false, {
        on_lines = function()
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end
            local pk = action_state.get_current_picker(prompt_bufnr)
            if not pk then return end

            current_replacement = action_state.get_current_line()
            pk:refresh(make_finder(current_replacement), { reset_prompt = false })

            local entry = action_state.get_selected_entry()
            if entry then render_preview(entry) end
          end)
        end,
      })

      actions.select_default:replace(function()
        local replacement = action_state.get_current_line()
        if replacement == "" then return end
        local entry = action_state.get_selected_entry()
        if not entry then return end

        apply_replacements({ entry.value }, search_term, replacement)
        matches = collect_matches(search_term)

        if #matches == 0 then
          actions.close(prompt_bufnr)
          vim.notify("All occurrences replaced!", vim.log.levels.INFO)
        else
          local pk = action_state.get_current_picker(prompt_bufnr)
          pk:refresh(make_finder(replacement), { reset_prompt = false })
        end
      end)

      local function replace_all()
        local replacement = action_state.get_current_line()
        if replacement == "" then return end
        local count = apply_replacements(matches, search_term, replacement)
        actions.close(prompt_bufnr)
        vim.notify("Replaced " .. count .. " occurrences!", vim.log.levels.INFO)
      end

      map("i", "<C-a>", replace_all)
      map("n", "<C-a>", replace_all)

      return true
    end,
  }):find()
end

return M
