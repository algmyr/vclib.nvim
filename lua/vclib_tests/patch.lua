local M = {}

local patch = require "vclib.patch"
local testing = require "vclib.testing"

-- Helper function to create a git diff output.
local function make_git_diff_from_string(hunks)
  local lines = {
    "diff --git a/test.txt b/test.txt",
    "index abc123..def456 100644",
    "--- a/test.txt",
    "+++ b/test.txt",
  }
  for _, line in ipairs(testing.dedent_into_lines(hunks)) do
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end

-- Helper to compare patch structures.
local function assert_patch_eq(actual, expected)
  assert(actual ~= nil, "actual patch is nil")
  assert(expected ~= nil, "expected patch is nil")
  assert(
    #actual.hunks == #expected.hunks,
    string.format("Expected %d hunks, got %d", #expected.hunks, #actual.hunks)
  )

  for h = 1, #expected.hunks do
    local ah = actual.hunks[h]
    local eh = expected.hunks[h]

    assert(
      ah.old_start == eh.old_start,
      string.format(
        "Hunk %d: old_start mismatch: %d vs %d",
        h,
        ah.old_start,
        eh.old_start
      )
    )
    assert(
      ah.old_count == eh.old_count,
      string.format(
        "Hunk %d: old_count mismatch: %d vs %d",
        h,
        ah.old_count,
        eh.old_count
      )
    )
    assert(
      ah.new_start == eh.new_start,
      string.format(
        "Hunk %d: new_start mismatch: %d vs %d",
        h,
        ah.new_start,
        eh.new_start
      )
    )
    assert(
      ah.new_count == eh.new_count,
      string.format(
        "Hunk %d: new_count mismatch: %d vs %d",
        h,
        ah.new_count,
        eh.new_count
      )
    )
    assert(
      #ah.lines == #eh.lines,
      string.format(
        "Hunk %d: Expected %d lines, got %d",
        h,
        #eh.lines,
        #ah.lines
      )
    )

    for l = 1, #eh.lines do
      local al = ah.lines[l]
      local el = eh.lines[l]
      assert(
        al.type == el.type,
        string.format(
          "Hunk %d, line %d: type mismatch: %s vs %s",
          h,
          l,
          al.type,
          el.type
        )
      )
      assert(
        al.content == el.content,
        string.format(
          "Hunk %d, line %d: content mismatch: '%s' vs '%s'",
          h,
          l,
          al.content,
          el.content
        )
      )
    end
  end
end

M.parse_single_file_patch = {
  test_cases = {
    single_hunk = {
      patch_text = make_git_diff_from_string [[
        @@ -1,3 +1,4 @@
         line1
         line2
        +NEW LINE
         line3
      ]],
      expected = {
        hunks = {
          {
            old_start = 1,
            old_count = 3,
            new_start = 1,
            new_count = 4,
            lines = {
              { type = "context", content = "line1" },
              { type = "context", content = "line2" },
              { type = "add", content = "NEW LINE" },
              { type = "context", content = "line3" },
            },
          },
        },
      },
    },
    multiple_hunks = {
      patch_text = make_git_diff_from_string [[
        @@ -1,2 +1,3 @@
         line1
        +NEW1
         line2
        @@ -5,2 +6,3 @@
         line5
        +NEW2
         line6
      ]],
      expected = {
        hunks = {
          {
            old_start = 1,
            old_count = 2,
            new_start = 1,
            new_count = 3,
            lines = {
              { type = "context", content = "line1" },
              { type = "add", content = "NEW1" },
              { type = "context", content = "line2" },
            },
          },
          {
            old_start = 5,
            old_count = 2,
            new_start = 6,
            new_count = 3,
            lines = {
              { type = "context", content = "line5" },
              { type = "add", content = "NEW2" },
              { type = "context", content = "line6" },
            },
          },
        },
      },
    },
    no_hunks = {
      patch_text = "diff --git a/test.txt b/test.txt\nindex abc123..abc123 100644\n",
      expected = nil,
    },
    file_header_no_hunks = {
      expected = nil,
      patch_text = "diff --git a/test.txt b/test.txt\nindex abc123..abc123 100644\n--- a/test.txt\n+++ b/test.txt",
    },
    mixed_operations = {
      patch_text = make_git_diff_from_string [[
        @@ -1,4 +1,4 @@
         context1
        -removed
        +added
         context2
      ]],
      expected = {
        hunks = {
          {
            old_start = 1,
            old_count = 4,
            new_start = 1,
            new_count = 4,
            lines = {
              { type = "context", content = "context1" },
              { type = "remove", content = "removed" },
              { type = "add", content = "added" },
              { type = "context", content = "context2" },
            },
          },
        },
      },
    },
  },
  test = function(case)
    local result = patch.parse_single_file_patch(case.patch_text)
    if case.expected == nil then
      assert(result == nil, "Expected nil for patch with no hunks")
    else
      assert_patch_eq(result, case.expected)
    end
  end,
}

M.roundtrip = {
  test_cases = {
    simple_addition = {
      old_file = { "line1", "line2", "line3" },
      new_file = { "line1", "line2", "NEW LINE", "line3" },
      patch_text = make_git_diff_from_string [[
        @@ -1,3 +1,4 @@
         line1
         line2
        +NEW LINE
         line3
      ]],
    },
    simple_deletion = {
      old_file = { "line1", "line2", "line3", "line4" },
      new_file = { "line1", "line2", "line4" },
      patch_text = make_git_diff_from_string [[
        @@ -1,4 +1,3 @@
         line1
         line2
        -line3
         line4
      ]],
    },
    simple_modification = {
      old_file = { "line1", "original line", "line3" },
      new_file = { "line1", "modified line", "line3" },
      patch_text = make_git_diff_from_string [[
        @@ -1,3 +1,3 @@
         line1
        -original line
        +modified line
         line3
      ]],
    },
    multiple_hunks = {
      old_file = { "line1", "line2", "unchanged", "line3", "line4" },
      new_file = {
        "line1",
        "NEW1",
        "line2",
        "unchanged",
        "line3",
        "NEW2",
        "line4",
      },
      patch_text = make_git_diff_from_string [[
        @@ -1,2 +1,3 @@
         line1
        +NEW1
         line2
        @@ -4,2 +5,3 @@
         line3
        +NEW2
         line4
      ]],
    },
    complex_changes = {
      old_file = {
        "header",
        "old line 1",
        "old line 2",
        "more content",
        "old footer",
      },
      new_file = { "header", "new line 1", "content", "more content", "footer" },
      patch_text = make_git_diff_from_string [[
        @@ -1,5 +1,5 @@
         header
        -old line 1
        -old line 2
        +new line 1
        +content
         more content
        -old footer
        +footer
      ]],
    },
    add_to_empty_file = {
      old_file = {},
      new_file = { "line1", "line2" },
      patch_text = make_git_diff_from_string [[
        @@ -0,0 +1,2 @@
        +line1
        +line2
      ]],
    },
    delete_entire_file = {
      old_file = { "line1", "line2" },
      new_file = {},
      patch_text = make_git_diff_from_string [[
        @@ -1,2 +0,0 @@
        -line1
        -line2
      ]],
    },
    addition_at_beginning = {
      old_file = { "line1", "line2" },
      new_file = { "NEW", "line1", "line2" },
      patch_text = make_git_diff_from_string [[
        @@ -1,2 +1,3 @@
        +NEW
         line1
         line2
      ]],
    },
    addition_at_end = {
      old_file = { "line1", "line2" },
      new_file = { "line1", "line2", "NEW" },
      patch_text = make_git_diff_from_string [[
        @@ -1,2 +1,3 @@
         line1
         line2
        +NEW
      ]],
    },
  },
  test = function(case)
    -- Validate parsing.
    local parsed = patch.parse_single_file_patch(case.patch_text)
    assert(parsed ~= nil, "Failed to parse patch")

    -- Validate patch application.
    local forward_result = patch.apply_patch(case.old_file, parsed)
    testing.assert_list_eq(
      forward_result,
      case.new_file,
      "Forward application failed: "
    )

    -- Validate patch inversion and reverse application.
    local inverted = patch.invert_patch(parsed)
    local reverse_result = patch.apply_patch(case.new_file, inverted)
    testing.assert_list_eq(
      reverse_result,
      case.old_file,
      "Reverse application failed: "
    )
  end,
}

return M
