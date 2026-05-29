local M = {}

function M.setup()
  local hl = vim.api.nvim_set_hl

  -- Panel backgrounds (Monokai Pro)
  hl(0, "GitUIStatusBg", { bg = "#221f22" })
  hl(0, "GitUIStatusCursorLine", { bg = "#403e41" })

  -- Git status colors
  hl(0, "GitUIStaged", { fg = "#a9dc76", bold = true })
  hl(0, "GitUIModified", { fg = "#ffd866", bold = true })
  hl(0, "GitUIUntracked", { fg = "#78dce8" })
  hl(0, "GitUIDeleted", { fg = "#ff6188", bold = true })
  hl(0, "GitUIRenamed", { fg = "#ab9df2" })
  hl(0, "GitUIConflict", { fg = "#fc9867", bold = true })

  -- Branch and headers
  hl(0, "GitUIBranch", { fg = "#ab9df2", bold = true })
  hl(0, "GitUISectionHeader", { fg = "#727072", bold = true })
  hl(0, "GitUISectionCount", { fg = "#5b595c" })
  hl(0, "GitUIHeader", { fg = "#fcfcfa", bold = true })

  -- File paths
  hl(0, "GitUIFilePath", { fg = "#727072" })
  hl(0, "GitUIFileName", { fg = "#fcfcfa" })

  -- Help footer
  hl(0, "GitUIHelpKey", { fg = "#ffd866", bold = true })
  hl(0, "GitUIHelpText", { fg = "#5b595c" })

  -- Diff
  hl(0, "GitUIDiffAdd", { bg = "#2a3a2a" })
  hl(0, "GitUIDiffAddInline", { bg = "#304d30" })
  hl(0, "GitUIDiffDelete", { bg = "#3a2228" })
  hl(0, "GitUIDiffDelInline", { bg = "#4d2538" })
  hl(0, "GitUIDiffAddSign", { fg = "#a9dc76" })
  hl(0, "GitUIDiffDelSign", { fg = "#ff6188" })
  hl(0, "GitUIDiffHeader", { fg = "#78dce8", bold = true })
  hl(0, "GitUIDiffFile", { fg = "#fcfcfa", bold = true })
  hl(0, "GitUIDiffHunk", { fg = "#ab9df2" })
  hl(0, "GitUIDiffFiller", { bg = "#2d2a2e" })
  hl(0, "GitUIDiffDivider", { fg = "#403e41", bg = "#221f22" })
  hl(0, "GitUIConflictMarker", { bg = "#3a2e1e", fg = "#fc9867", bold = true })
  hl(0, "GitUIConflictMarkerSign", { fg = "#fc9867" })
  hl(0, "GitUIConflictOurs", { bg = "#2a3530" })
  hl(0, "GitUIConflictTheirs", { bg = "#352a38" })
  hl(0, "GitUIConflictHint", { fg = "#78dce8" })

  -- Misc
  hl(0, "GitUIClean", { fg = "#727072", italic = true })
  hl(0, "GitUISeparator", { fg = "#403e41" })

  -- Diff filepath bar
  hl(0, "GitUIDiffBarSep", { fg = "#403e41", bg = "#221f22" })
  hl(0, "GitUIDiffBarIcon", { fg = "#78dce8", bg = "#221f22" })
  hl(0, "GitUIDiffBarDir", { fg = "#727072", bg = "#221f22" })
  hl(0, "GitUIDiffBarFile", { fg = "#fcfcfa", bg = "#221f22", bold = true })
  hl(0, "GitUIDiffBarHint", { fg = "#5b595c", bg = "#221f22", italic = true })

  -- Commit modal
  hl(0, "GitUICommitBorder", { fg = "#403e41", bg = "#221f22" })
  hl(0, "GitUICommitNormal", { fg = "#fcfcfa", bg = "#221f22" })
  hl(0, "GitUICommitTitle", { fg = "#ab9df2", bg = "#221f22", bold = true })
  hl(0, "GitUICommitPrompt", { fg = "#ffd866" })
  hl(0, "GitUICommitCounter", { fg = "#727072" })
  hl(0, "GitUICommitCounterWarn", { fg = "#fc9867" })
  hl(0, "GitUICommitCounterOver", { fg = "#ff6188", bold = true })

  -- Log view
  hl(0, "GitUILogGraph",   { fg = "#727072" })
  hl(0, "GitUILogHash",    { fg = "#ffd866" })
  hl(0, "GitUILogSubject", { fg = "#fcfcfa" })
  hl(0, "GitUILogAuthor",  { fg = "#ab9df2" })
  hl(0, "GitUILogDate",    { fg = "#5b595c", italic = true })
  hl(0, "GitUILogRefs",    { fg = "#78dce8", bold = true })
  hl(0, "GitUILogHead",    { fg = "#a9dc76", bold = true })
  hl(0, "GitUILogModeBar", { fg = "#ab9df2", bold = true })

  -- Scrollbar
  hl(0, "GitUIScrollTrack", { bg = "#221f22" })
  hl(0, "GitUIScrollVP", { bg = "#403e41" })
  hl(0, "GitUIScrollAdd", { bg = "#2a3a2a" })
  hl(0, "GitUIScrollDel", { bg = "#3a2228" })
  hl(0, "GitUIScrollAddVP", { bg = "#3a5a3a" })
  hl(0, "GitUIScrollDelVP", { bg = "#5a3040" })
  hl(0, "GitUIScrollConflict", { bg = "#4a3820" })
  hl(0, "GitUIScrollConflictVP", { bg = "#6a5030" })
end

return M
