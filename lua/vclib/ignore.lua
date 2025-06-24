local M = {}

local run = require "vclib.run"

---@diagnostic disable-next-line: undefined-field
local stat = vim.uv.fs_stat

-- This is probably way overkill.
local vcs_root_cache = {}

---@param path string
---@return {type: string, root: string}|nil
local function _get_vcs_root(path)
  if vcs_root_cache[path] then
    return vcs_root_cache[path]
  end
  if stat(path .. "/.git") then
    vcs_root_cache[path] = {
      type = "git",
      root = path,
    }
    return vcs_root_cache[path]
  end
  if stat(path .. "/.jj") then
    vcs_root_cache[path] = {
      type = "jj",
      root = path,
    }
    return vcs_root_cache[path]
  end
  -- Could add more, but this is a good start.
  if vim.fs.dirname(path) == path then
    -- Reached the root directory without finding a VCS directory.
    return nil
  end
  -- Recursively check the parent directory.
  return _get_vcs_root(vim.fs.dirname(path))
end

local is_ignored_cache = {}

-- Check if file should be ignored as per gitignore rules.
function M.is_ignored(path)
  if is_ignored_cache[path] ~= nil then
    return is_ignored_cache[path]
  end

  local absolute_path = vim.fs.normalize(vim.fs.abspath(path))

  local vcs_root = _get_vcs_root(vim.fs.dirname(absolute_path))
  if vcs_root then
    local gitdir
    if vcs_root.type == "git" then
      gitdir = vcs_root.root .. "/.git"
    elseif vcs_root.type == "jj" then
      -- I should really read `git_target`, but let's keep this simple...
      gitdir = vcs_root.root .. "/.jj/repo/store/git"
    else
      error("Unknown VCS type: " .. vim.inspect(vcs_root.type))
    end

    local out = run
      .run_with_timeout({
        "git",
        "--git-dir",
        gitdir,
        "--work-tree",
        vcs_root.root,
        "check-ignore",
        "--no-index",
        absolute_path,
      }, {})
      :wait()
    if out.code == 0 then
      is_ignored_cache[path] = true
      return true
    end
  end

  return false
end

function M.clear_ignored_cache()
  is_ignored_cache = {}
end

return M
