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

local function _enable(wo, foldexpr)
  wo.foldexpr = foldexpr
  wo.foldmethod = "expr"
  wo.foldlevel = 0
end

local function _disable(wo, bufnr)
  wo.foldmethod = vim.b[bufnr].vclib_folded.method
  wo.foldtext = vim.b[bufnr].vclib_folded.text
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
  -- Use the local window options to avoid weird inheritance issues.
  -- With plain `vim.wo` newly opened buffers in the window would
  -- inherit the option which is undesirable.
  --
  -- See notes about setlocal in: https://neovim.io/doc/user/lua.html#vim.wo
  local winid = vim.api.nvim_get_current_win()
  local local_wo = vim.wo[winid][0]
  if vim.b[bufnr].vclib_folded then
    _disable(local_wo, bufnr)
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
    _enable(local_wo, foldexpr)
  end
end

return M
