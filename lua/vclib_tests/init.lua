local M = {}

local testing = require "vclib.testing"

function M.run()
  local test_modules = {
    "vclib_tests.fold",
    "vclib_tests.patch",
  }
  testing.run_tests(test_modules)
end

return M
