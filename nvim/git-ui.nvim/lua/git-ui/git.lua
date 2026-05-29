local M = {}

--- Run a git command asynchronously.
---@param args string[] git subcommand and arguments
---@param callback fun(ok: boolean, stdout: string, stderr: string)
local function run(args, callback)
  local cwd = vim.fn.getcwd()
  vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      callback(result.code == 0, result.stdout or "", result.stderr or "")
    end)
  end)
end

--- Run a git command synchronously.
---@param args string[] git subcommand and arguments
---@return boolean ok, string stdout, string stderr
local function run_sync(args)
  local cwd = vim.fn.getcwd()
  local result = vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
  return result.code == 0, result.stdout or "", result.stderr or ""
end

function M.is_repo()
  local ok = run_sync({ "rev-parse", "--is-inside-work-tree" })
  return ok
end

function M.status(callback)
  run({ "status", "--porcelain=v1", "-uall" }, function(ok, stdout)
    if not ok then
      callback({ staged = {}, changed = {}, untracked = {}, conflicted = {} })
      return
    end
    local files = { staged = {}, changed = {}, untracked = {}, conflicted = {} }
    for line in stdout:gmatch("[^\n]+") do
      local x = line:sub(1, 1)
      local y = line:sub(2, 2)
      local path = line:sub(4)

      -- Extract actual path for operations (handle renames: "old -> new")
      local actual_path = path
      if path:find(" -> ") then
        actual_path = path:match(" -> (.+)$")
      end

      local is_conflicted = x == "U"
        or y == "U"
        or (x == "A" and y == "A")
        or (x == "D" and y == "D")

      if is_conflicted then
        table.insert(files.conflicted, {
          path = path,
          actual_path = actual_path,
          status = x .. y,
        })
      -- Untracked
      elseif x == "?" and y == "?" then
        table.insert(files.untracked, { path = path, actual_path = actual_path, status = "?" })
      else
        -- Staged changes (index)
        if x == "M" or x == "A" or x == "D" or x == "R" or x == "C" then
          table.insert(files.staged, { path = path, actual_path = actual_path, status = x })
        end
        -- Working tree changes
        if y == "M" or y == "D" then
          table.insert(files.changed, { path = path, actual_path = actual_path, status = y })
        end
      end
    end
    callback(files)
  end)
end

function M.branch_info(callback)
  run({ "branch", "--show-current" }, function(ok, stdout)
    local name = ok and vim.trim(stdout) or "HEAD (detached)"
    if name == "" then name = "HEAD (detached)" end
    run({ "rev-list", "--left-right", "--count", "HEAD...@{upstream}" }, function(ok2, stdout2)
      local ahead, behind = 0, 0
      if ok2 then
        local a, b = stdout2:match("(%d+)%s+(%d+)")
        ahead = tonumber(a) or 0
        behind = tonumber(b) or 0
      end
      callback({ name = name, ahead = ahead, behind = behind })
    end)
  end)
end

function M.branches(callback)
  run({ "branch", "--format=%(HEAD) %(refname:short)" }, function(ok, stdout)
    if not ok then
      callback({})
      return
    end
    local branches = {}
    for line in stdout:gmatch("[^\n]+") do
      local head = line:sub(1, 1)
      local name = vim.trim(line:sub(3))
      if name ~= "" then
        table.insert(branches, { name = name, current = head == "*" })
      end
    end
    callback(branches)
  end)
end

function M.diff(path, staged, callback)
  local args = { "diff", "--no-color", "-U999999" }
  if staged then table.insert(args, "--cached") end
  table.insert(args, "--")
  table.insert(args, path)
  run(args, function(ok, stdout)
    callback(ok and stdout or "")
  end)
end

function M.diff_untracked(path, callback)
  local cwd = vim.fn.getcwd()
  local full_path = cwd .. "/" .. path
  local ok_read, content_lines = pcall(vim.fn.readfile, full_path)
  if not ok_read then
    callback("")
    return
  end
  local lines = {
    "diff --git a/" .. path .. " b/" .. path,
    "new file",
    "--- /dev/null",
    "+++ b/" .. path,
    string.format("@@ -0,0 +1,%d @@", #content_lines),
  }
  for _, l in ipairs(content_lines) do
    table.insert(lines, "+" .. l)
  end
  callback(table.concat(lines, "\n"))
end

function M.stage(path, callback)
  run({ "add", "--", path }, function(ok, _, stderr)
    callback(ok, stderr)
  end)
end

function M.unstage(path, callback)
  run({ "reset", "HEAD", "--", path }, function(ok, _, stderr)
    callback(ok, stderr)
  end)
end

function M.discard(path, untracked, callback)
  local args
  if untracked then
    args = { "clean", "-f", "--", path }
  else
    args = { "restore", "--worktree", "--", path }
  end

  run(args, function(ok, _, stderr)
    callback(ok, stderr)
  end)
end

function M.read_file(path, callback)
  local cwd = vim.fn.getcwd()
  local full_path = cwd .. "/" .. path
  local ok_read, lines_or_err = pcall(vim.fn.readfile, full_path)
  if not ok_read then
    callback(false, {}, tostring(lines_or_err))
    return
  end
  callback(true, lines_or_err, "")
end

function M.resolve_conflict(path, strategy, callback)
  local mode
  if strategy == "ours" then
    mode = "--ours"
  elseif strategy == "theirs" then
    mode = "--theirs"
  else
    callback(false, "Invalid conflict strategy: " .. tostring(strategy))
    return
  end

  run({ "checkout", mode, "--", path }, function(ok, _, stderr)
    callback(ok, stderr)
  end)
end

function M.resolve_conflict_both(path, callback)
  M.read_file(path, function(ok, lines, err)
    if not ok then
      callback(false, err)
      return
    end

    local out = {}
    local i = 1
    local found = false

    while i <= #lines do
      local line = lines[i]
      if line:match("^<<<<<<<") then
        found = true
        i = i + 1

        local ours = {}
        while i <= #lines and not lines[i]:match("^=======$") do
          -- Skip diff3 base section: ||||||| ... (until =======)
          if lines[i]:match("^|||||||") then
            i = i + 1
            while i <= #lines and not lines[i]:match("^=======$") do
              i = i + 1
            end
            break
          end
          table.insert(ours, lines[i])
          i = i + 1
        end
        if i > #lines then
          callback(false, "Malformed conflict markers")
          return
        end

        i = i + 1
        local theirs = {}
        while i <= #lines and not lines[i]:match("^>>>>>>>") do
          table.insert(theirs, lines[i])
          i = i + 1
        end
        if i > #lines then
          callback(false, "Malformed conflict markers")
          return
        end

        i = i + 1 -- skip >>>>>>>

        vim.list_extend(out, ours)
        vim.list_extend(out, theirs)
      else
        table.insert(out, line)
        i = i + 1
      end
    end

    if not found then
      callback(false, "No conflict markers found")
      return
    end

    local cwd = vim.fn.getcwd()
    local full_path = cwd .. "/" .. path
    local ok_write, write_err = pcall(vim.fn.writefile, out, full_path)
    if not ok_write then
      callback(false, tostring(write_err))
      return
    end

    callback(true, "")
  end)
end

function M.resolve_single_conflict(path, conflict_idx, strategy, callback)
  M.read_file(path, function(ok, lines, err)
    if not ok then
      callback(false, err)
      return
    end

    local out = {}
    local current_idx = 0
    local i = 1

    while i <= #lines do
      local line = lines[i]
      if line:match("^<<<<<<<") then
        current_idx = current_idx + 1
        if current_idx == conflict_idx then
          -- Target conflict: apply strategy
          i = i + 1 -- skip <<<<<<<

          local ours = {}
          while i <= #lines and not lines[i]:match("^=======$") do
            if lines[i]:match("^|||||||") then
              i = i + 1
              while i <= #lines and not lines[i]:match("^=======$") do
                i = i + 1
              end
              break
            end
            table.insert(ours, lines[i])
            i = i + 1
          end
          if i > #lines then
            callback(false, "Malformed conflict markers")
            return
          end

          i = i + 1 -- skip =======
          local theirs = {}
          while i <= #lines and not lines[i]:match("^>>>>>>>") do
            table.insert(theirs, lines[i])
            i = i + 1
          end
          if i > #lines then
            callback(false, "Malformed conflict markers")
            return
          end
          i = i + 1 -- skip >>>>>>>

          if strategy == "ours" then
            vim.list_extend(out, ours)
          elseif strategy == "theirs" then
            vim.list_extend(out, theirs)
          elseif strategy == "both" then
            vim.list_extend(out, ours)
            vim.list_extend(out, theirs)
          end
        else
          -- Not the target conflict, keep markers intact
          table.insert(out, line)
          i = i + 1
        end
      else
        table.insert(out, line)
        i = i + 1
      end
    end

    if current_idx < conflict_idx then
      callback(false, "Conflict #" .. conflict_idx .. " not found")
      return
    end

    local cwd = vim.fn.getcwd()
    local full_path = cwd .. "/" .. path
    local ok_write, write_err = pcall(vim.fn.writefile, out, full_path)
    if not ok_write then
      callback(false, tostring(write_err))
      return
    end

    callback(true, "")
  end)
end

function M.stage_all(callback)
  run({ "add", "-A" }, function(ok, _, stderr)
    callback(ok, stderr)
  end)
end

function M.unstage_all(callback)
  run({ "reset", "HEAD" }, function(ok, _, stderr)
    callback(ok, stderr)
  end)
end

function M.commit(message, callback)
  run({ "commit", "-m", message }, function(ok, stdout, stderr)
    callback(ok, ok and stdout or stderr)
  end)
end

function M.push(callback)
  run({ "push" }, function(ok, stdout, stderr)
    callback(ok, ok and stdout or stderr)
  end)
end

function M.pull(callback)
  run({ "pull" }, function(ok, stdout, stderr)
    callback(ok, ok and stdout or stderr)
  end)
end

function M.checkout(branch, callback)
  run({ "checkout", branch }, function(ok, stdout, stderr)
    callback(ok, ok and stdout or stderr)
  end)
end

function M.create_branch(name, callback)
  run({ "checkout", "-b", name }, function(ok, stdout, stderr)
    callback(ok, ok and stdout or stderr)
  end)
end

--- Fetch commit log with graph.
---@param opts table { limit = number, all = boolean }
---@param callback fun(commits: table[]) each: { graph, hash, short, subject, author, date, refs }
function M.log(opts, callback)
  opts = opts or {}
  local args = {
    "log",
    "--graph",
    "--date-order",
    "--pretty=format:%H%x00%h%x00%s%x00%an%x00%ar%x00%D",
    "-n", tostring(opts.limit or 300),
  }
  if opts.all then table.insert(args, "--all") end

  run(args, function(ok, stdout)
    if not ok then callback({}); return end
    local commits = {}
    for line in stdout:gmatch("[^\n]+") do
      local nul_pos = line:find("\0", 1, true)
      if nul_pos then
        local prefix_hash = line:sub(1, nul_pos - 1)
        local rest = line:sub(nul_pos + 1)
        local fields = vim.split(rest, "\0", { plain = true })
        local graph, full_hash = prefix_hash:match("^(.-)([0-9a-f]+)$")
        table.insert(commits, {
          graph = graph or "",
          hash = full_hash or "",
          short = fields[1] or "",
          subject = fields[2] or "",
          author = fields[3] or "",
          date = fields[4] or "",
          refs = fields[5] or "",
        })
      else
        -- Pure graph line (merge connectors with no commit)
        table.insert(commits, { graph = line, hash = nil })
      end
    end
    callback(commits)
  end)
end

--- Files changed in a commit.
function M.commit_files(hash, callback)
  run({ "show", "--name-status", "--pretty=format:", "--no-color", hash }, function(ok, stdout)
    if not ok then callback({}); return end
    local files = {}
    for line in stdout:gmatch("[^\n]+") do
      local parts = vim.split(line, "\t", { plain = true })
      if #parts >= 2 then
        local s = parts[1]:sub(1, 1) -- M, A, D, R, C, T, U
        -- Renames/copies have 3 fields: STATUS<tab>old_path<tab>new_path
        local p = parts[#parts]
        table.insert(files, { status = s, path = p, raw = parts[1] })
      end
    end
    callback(files)
  end)
end

--- Full commit diff (stat + patch).
function M.commit_show(hash, callback)
  run({ "show", "--no-color", "--stat", hash }, function(ok, stdout)
    callback(ok and stdout or "")
  end)
end

--- Commit metadata (header block).
function M.commit_meta(hash, callback)
  run({ "show", "--no-patch", "--pretty=format:%H%n%an <%ae>%n%ad%n%n%s%n%n%b", "--date=iso", hash }, function(ok, stdout)
    callback(ok and stdout or "")
  end)
end

--- Per-file diff inside a commit.
function M.commit_file_diff(hash, path, callback)
  run({ "show", "--no-color", "-U999999", hash, "--", path }, function(ok, stdout)
    callback(ok and stdout or "")
  end)
end

function M.stage_hunk(patch, callback)
  local cwd = vim.fn.getcwd()
  vim.system(
    { "git", "apply", "--cached", "--unidiff-zero", "-" },
    { cwd = cwd, text = true, stdin = patch },
    function(result)
      vim.schedule(function()
        callback(result.code == 0, result.stderr or "")
      end)
    end
  )
end

function M.unstage_hunk(patch, callback)
  local cwd = vim.fn.getcwd()
  vim.system(
    { "git", "apply", "--cached", "--reverse", "--unidiff-zero", "-" },
    { cwd = cwd, text = true, stdin = patch },
    function(result)
      vim.schedule(function()
        callback(result.code == 0, result.stderr or "")
      end)
    end
  )
end

return M
