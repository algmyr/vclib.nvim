local M = {}

function M.verbose_logger(namespace)
  --- Print a message to the user if verbose mode is enabled.
  ---@param msg string|table The message to print.
  ---@param label string|nil An optional label to include in the message.
  local function verbose(msg, label)
    label = label or debug.getinfo(3, "n").name

    vim.schedule(function()
      if vim.o.verbose ~= 0 then
        local l = label and ":" .. label or ""
        if type(msg) == "string" then
          print("[" .. namespace .. l .. "] " .. msg)
        else
          print("[" .. namespace .. l .. "] " .. vim.inspect(msg))
        end
      end
    end)
  end
  return verbose
end

M.vclib_verbose = M.verbose_logger "vclib"

return M
