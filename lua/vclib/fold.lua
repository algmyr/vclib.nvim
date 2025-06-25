local M = {}

---@param context integer[]
---@param intervals Intervals
---@param last_line integer
---@return integer[]
function M.compute_levels(intervals, context, last_line)
  local max_level = #context

  local levels = {}
  for line = 1, last_line do
    levels[line] = max_level
  end

  local function f(margin, value)
    for _, interval in ipairs(intervals.intervals) do
      local start = interval.l
      local count = interval.r - start
      for i = start - margin, start + count - 1 + margin do
        if i >= 1 and i <= last_line then
          levels[i] = value
        end
      end
    end
  end

  -- Sort in descending order to apply larger margins first.
  table.sort(context, function(a, b)
    return a > b
  end)
  for i, margin in ipairs(context) do
    f(margin, max_level - i)
  end

  -- Clean up of plateaus of length 1 that are pointless to fold.
  for line = 1, last_line do
    local prev = levels[line - 1] or levels[line + 1]
    local next = levels[line + 1] or levels[line - 1]
    if prev == next and levels[line] > next then
      levels[line] = prev
    end
  end

  return levels
end

local function _enable(foldexpr)
  vim.wo.foldexpr = foldexpr
  vim.wo.foldmethod = "expr"
  vim.wo.foldlevel = 0
end

local function _disable(bufnr)
  vim.wo.foldmethod = vim.b[bufnr].vclib_folded.method
  vim.wo.foldtext = vim.b[bufnr].vclib_folded.text
  vim.cmd "normal! zv"
end

function M.maybe_update_levels(intervals, context)
  if vim.b.vclib_fold_changedtick ~= vim.b.changedtick then
    vim.b.vclib_fold_changedtick = vim.b.changedtick
    -- Update cached fold levels.
    local last_line = vim.fn.line "$"
    vim.b.levels = M.compute_levels(intervals, context, last_line)
  end
end

---@param bufnr integer
---@param foldexpr string
function M.toggle(bufnr, foldexpr)
  if vim.b[bufnr].vclib_folded then
    _disable(bufnr)
    if vim.b[bufnr].vclib_folded.method == "manual" then
      vim.cmd "loadview"
    end
    vim.b[bufnr].vclib_folded = nil
  else
    vim.b[bufnr].vclib_folded =
      { method = vim.wo.foldmethod, text = vim.wo.foldtext }
    if vim.wo.foldmethod == "manual" then
      local old_vop = vim.o.viewoptions
      vim.cmd "mkview"
      vim.o.viewoptions = old_vop
    end
    _enable(foldexpr)
  end
end

return M
