local M = {}

---@class Interval
---@field l integer
---@field r integer
---@field data any
local Interval = {}

---@param intervals Interval[]
---@param point integer
local function _partition(intervals, point)
  local before = {}
  local on = nil
  local after = {}

  for _, interval in ipairs(intervals) do
    if interval.l <= point and point < interval.r then
      on = interval
      goto continue
    end
    if interval.l < point then
      table.insert(before, interval)
    end
    if interval.l > point then
      table.insert(after, interval)
    end
    ::continue::
  end

  return before, on, after
end

---@class Intervals
---@field intervals Interval[]
local Intervals = {}

---@generic T
---@param elements T[]
---@param make_interval fun(element: T): Interval
---@return Intervals
function Intervals:new(elements, make_interval)
  local obj = setmetatable({}, { __index = self })
  obj.intervals = vim.iter(elements):map(make_interval):totable()
  return obj
end

---@generic T
---@param elements T[]
---@param make_interval fun(element: T): Interval
function M.from_list(elements, make_interval)
  return Intervals:new(elements, make_interval)
end

---@param interval Interval?
local function _data(interval)
  if interval then
    return interval.data
  end
  return nil
end

--- Get intervals around a point.
---@param point integer
---@param offset integer
function Intervals:find(point, offset)
  local before, on, after = _partition(self.intervals, point)
  if offset == 0 then
    return _data(on)
  elseif offset < 0 then
    offset = -offset
    return _data(before[#before - (offset - 1)] or before[1])
  else
    return _data(after[offset] or after[#after])
  end
end

return M
