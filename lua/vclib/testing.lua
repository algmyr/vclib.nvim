local M = {}

---@return boolean
local function is_headless()
  return #vim.api.nvim_list_uis() == 0
end

local function color(description)
  local words = vim.split(description, " ", { plain = true })
  local colors = {
    reset = -1,
    black = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,
  }
  local base = 30
  local color = nil
  for _, word in ipairs(words) do
    if word == "bright" then
      base = 90
    else
      local c = colors[word]
      if not c then
        error("Unknown color: " .. word)
      end
      color = c
    end
  end
  if not color then
    error("No color specified in description: " .. description)
  end
  if color ~= -1 then
    return string.format("\27[%dm", base + color)
  end
  return "\27[0m"
end

FAIL = color "bright red"
PASS = color "bright green"
NOTE = color "bright black"
RESET = color "reset"

---@param text string
---@param color string
---@return string
local function colorize(text, color)
  if not is_headless() then
    -- Interactive session: do not use colors.
    return text
  end
  return color .. text .. RESET
end

--- Output text using the appropriate method for current mode.
---@param text string|string[]
local function output(text)
  if type(text) == "table" then
    text = table.concat(text, " ")
  end
  if is_headless() then
    io.stdout:write(text .. "\n")
    io.stdout:flush()
  else
    print(text)
  end
end

--- Helper to parse multiline strings into lines, stripping common indentation.
---@param s string
---@return string[]
function M.dedent_into_lines(s)
  local l = 1
  while s:sub(l, l) == "\n" do
    l = l + 1
  end
  local r = #s
  while true do
    local c = s:sub(r, r)
    if c ~= "\n" and c ~= " " then
      break
    end
    r = r - 1
  end
  local stripped = s:sub(l, r)
  local lines = vim.split(stripped, "\n", { plain = true })
  local min_indent = math.huge
  for _, line in ipairs(lines) do
    local indent = #line - #line:gsub("^%s*", "")
    if #line > 0 and indent < min_indent then
      min_indent = indent
    end
  end
  if min_indent == math.huge then
    min_indent = 0
  end
  for i, line in ipairs(lines) do
    lines[i] = line:sub(min_indent + 1)
  end
  return lines
end

--- Helper to parse multiline strings into lines, stripping common indentation.
---@param s string
---@return string
function M.dedent(s)
  local lines = M.dedent_into_lines(s)
  return table.concat(lines, "\n") .. "\n"
end

local function _run_test_suite(
  module_name,
  suite_name,
  test_suite,
  should_run_test
)
  local suite_start_time = vim.uv.hrtime()
  local suite_failed = 0
  local suite_total = 0
  local suite_skipped = 0
  local test_cases = test_suite.test_cases
  local test_function = test_suite.test
  for case_name, case in pairs(test_cases) do
    local full_test_name =
      string.format("%s::%s__%s", module_name, suite_name, case_name)
    if should_run_test(full_test_name) then
      local status, err = pcall(function()
        test_function(case)
      end)
      if not status then
        suite_failed = suite_failed + 1
        output(colorize("✗ FAIL", FAIL) .. " " .. full_test_name)
        if err then
          -- Massage errors into a more readable format.
          err = err:gsub(":(%s)", ":\n", 1)
          err = "  " .. err:gsub("\n", "\n  ")
          output(err)
        end
      end
      suite_total = suite_total + 1
    else
      suite_skipped = suite_skipped + 1
    end
  end

  local duration_ms = (vim.uv.hrtime() - suite_start_time) / 1e6

  local symbol
  local outcome
  local timing = string.format("(%.1fms)", duration_ms)
  if suite_failed == 0 then
    symbol = colorize("✓", PASS)
    outcome = string.format("(all %d passed)", suite_total)
  else
    symbol = colorize("✗", FAIL)
    outcome = string.format("(%d/%d failed)", suite_failed, suite_total)
  end
  output { symbol, suite_name, outcome, timing }
  if suite_skipped > 0 then
    output {
      " ",
      string.format(
        colorize("%d tests were skipped due to filtering", NOTE),
        suite_skipped
      ),
    }
  end
  return suite_failed, suite_total, suite_skipped
end

function M.run_tests(test_modules, options)
  options = options or {}
  local function should_run_test(name)
    if not options.filter then
      return true
    end

    -- Very magic for convenience.
    local pattern = "\\v" .. options.filter
    local ok, regex = pcall(vim.regex, pattern)
    if not ok then
      error("Invalid filter regex: " .. options.filter)
    end
    return regex:match_str(name) ~= nil
  end

  local start_time = vim.uv.hrtime()
  local failed = 0
  local total = 0
  local skipped = 0
  for _, test_module_name in ipairs(test_modules) do
    local test_module = require(test_module_name)
    -- Slightly less verbose name for the test module, removing first component.
    local file_name = test_module_name:match "^[^.]+%.(.+)$" or test_module_name
    output(string.format("=== Running tests in %s ===", file_name))
    for suite_name, test_suite in pairs(test_module) do
      local suite_failed, suite_total, suite_skipped =
        _run_test_suite(file_name, suite_name, test_suite, should_run_test)
      failed = failed + suite_failed
      total = total + suite_total
      skipped = skipped + suite_skipped
    end
  end

  local total_duration_ms = (vim.uv.hrtime() - start_time) / 1e6
  output "--------------------------------"
  local timing = string.format("(%.1fms)", total_duration_ms)
  local msg
  if failed == 0 then
    msg = colorize("All tests passed", PASS)
  else
    msg = colorize(string.format("%d/%d tests failed", failed, total), FAIL)
  end
  if skipped > 0 then
    msg = msg .. colorize(string.format(" (%d skipped)", skipped), NOTE)
  end

  output { msg, timing }
  if failed > 0 then
    vim.cmd "cq"
  end
end

function M.assert_list_eq(actual, expected, msg_prefix)
  msg_prefix = msg_prefix or ""
  assert(
    #actual == #expected,
    string.format(
      msg_prefix .. "Lists have different lengths: %d vs %d",
      #actual,
      #expected
    )
  )
  local diff = ""
  for i = 1, #expected do
    if actual[i] ~= expected[i] then
      diff = diff
        .. string.format("\n[%d]: %s ~= %s", i, actual[i], expected[i])
    end
  end
  if diff ~= "" then
    error(msg_prefix .. "Lists differ:" .. diff)
  end
end

return M
