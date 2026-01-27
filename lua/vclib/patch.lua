--- Utilities for working with git-format patches.
local M = {}

---@class PatchLine
---@field type "context"|"add"|"remove" The type of line in the patch.
---@field content string The actual line content (without the leading +/- marker).

---@class Hunk
---@field old_start integer Starting line number in the old file.
---@field old_count integer Number of lines in the old file.
---@field new_start integer Starting line number in the new file.
---@field new_count integer Number of lines in the new file.
---@field lines PatchLine[] The lines in this hunk.

---@class Patch
---@field hunks Hunk[] The hunks in this patch.

--- Parse a single file git-format diff into a structured patch.
--- (single file to keep things simple, and was sufficient for our use cases)
---@param patch_text string The git diff output.
---@return Patch|nil The parsed patch, or nil if no hunks found.
function M.parse_single_file_patch(patch_text)
  local lines = vim.split(patch_text, "\n", { plain = true })

  -- Skip metadata until we hit the first @@.
  local i = 1
  while i <= #lines and not lines[i]:match "^@@" do
    i = i + 1
  end

  if i > #lines then
    -- No hunks found.
    return nil
  end

  local hunks = {}
  local current_hunk = nil

  while i <= #lines do
    local line = lines[i]

    if line:match "^@@" then
      -- Save previous hunk if any.
      if current_hunk then
        table.insert(hunks, current_hunk)
      end

      -- Parse hunk header: @@ -old_start,old_count +new_start,new_count @@.
      local old_start, old_count, new_start, new_count =
        line:match "^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@"

      if old_start and new_start then
        current_hunk = {
          old_start = tonumber(old_start),
          old_count = tonumber(old_count) or 1,
          new_start = tonumber(new_start),
          new_count = tonumber(new_count) or 1,
          lines = {},
        }
      end
      i = i + 1
    else
      local first_char = line:sub(1, 1)
      if first_char == " " then
        -- Context line.
        if current_hunk then
          table.insert(current_hunk.lines, {
            type = "context",
            content = line:sub(2),
          })
        end
        i = i + 1
      elseif first_char == "-" then
        -- Removed line.
        if current_hunk then
          table.insert(current_hunk.lines, {
            type = "remove",
            content = line:sub(2),
          })
        end
        i = i + 1
      elseif first_char == "+" then
        -- Added line.
        if current_hunk then
          table.insert(current_hunk.lines, {
            type = "add",
            content = line:sub(2),
          })
        end
        i = i + 1
      elseif first_char == "\\" then
        -- "\ No newline at end of file" marker - ignore for now.
        i = i + 1
      else
        -- End of hunks or unknown line.
        break
      end
    end
  end

  -- Save last hunk.
  if current_hunk then
    table.insert(hunks, current_hunk)
  end

  if #hunks == 0 then
    return nil
  end

  return { hunks = hunks }
end

--- Invert a patch (swap add/remove operations and old/new positions).
---@param patch Patch The patch to invert.
---@return Patch The inverted patch.
function M.invert_patch(patch)
  local inverted_hunks = {}

  for _, hunk in ipairs(patch.hunks) do
    local inverted_lines = {}

    for _, line in ipairs(hunk.lines) do
      local inverted_type = line.type
      if line.type == "add" then
        inverted_type = "remove"
      elseif line.type == "remove" then
        inverted_type = "add"
      end

      table.insert(inverted_lines, {
        type = inverted_type,
        content = line.content,
      })
    end

    -- Swap old and new positions.
    table.insert(inverted_hunks, {
      old_start = hunk.new_start,
      old_count = hunk.new_count,
      new_start = hunk.old_start,
      new_count = hunk.old_count,
      lines = inverted_lines,
    })
  end

  return { hunks = inverted_hunks }
end

--- Apply a patch to file contents.
---@param file_lines string[] The current file contents.
---@param patch Patch The patch to apply.
---@return string[] The file contents after applying the patch.
function M.apply_patch(file_lines, patch)
  local result = {}
  local i = 1

  for _, hunk in ipairs(patch.hunks) do
    -- Copy unchanged lines before this hunk.
    while i < hunk.old_start do
      table.insert(result, file_lines[i])
      i = i + 1
    end

    -- Process hunk lines.
    for _, line in ipairs(hunk.lines) do
      if line.type == "context" then
        -- Context line - should match current file.
        table.insert(result, line.content)
        i = i + 1
      elseif line.type == "remove" then
        -- Line removed - skip it in the result, advance in current file.
        i = i + 1
      elseif line.type == "add" then
        -- Line added - add to result, don't advance in current file.
        table.insert(result, line.content)
      end
    end
  end

  -- Copy any remaining unchanged lines.
  while i <= #file_lines do
    table.insert(result, file_lines[i])
    i = i + 1
  end

  return result
end

return M
