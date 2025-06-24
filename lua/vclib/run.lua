local M = {}

local logging = require("vclib.logging")

function M.run_with_timeout(cmd, opts, callback)
  logging.vclib_verbose("Running command: " .. table.concat(cmd, " "))
  local merged_opts = vim.tbl_deep_extend("force", { timeout = 2000 }, opts)
  if callback == nil then
    return vim.system(cmd, merged_opts)
  end

  return vim.system(cmd, merged_opts, function(out)
    if out.code == 124 then
      logging.vclib_verbose("Command timed out: " .. table.concat(cmd, " "))
      return
    end
    vim.schedule(function()
      callback(out)
    end)
  end)
end

return M
