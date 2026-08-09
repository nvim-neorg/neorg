local tests = require("neorg.tests")
local Path = require("pathlib")
local pathsep = require("neorg.core").config.pathsep

describe("core.journal tests", function()
    local journal = tests
        .neorg_with("core.journal", {
            strategy = "nested",
        }).modules
        .get_module("core.journal")

    local ws_path = Path.cwd() / "journal"

    local function write_file(relpath, content)
        local path = ws_path / relpath
        vim.fn.mkdir(tostring(path:parent()), "p")
        vim.fn.writefile(vim.split(content or "", "\n"), tostring(path))
    end

    describe("get_entries_in_range", function()
        after_each(function()
            vim.fn.delete(ws_path:tostring(), "rf")
        end)

        it("finds entries laid out with the nested strategy", function()
            write_file("2026/08/01.norg", "* Day one")
            write_file("2026/08/09.norg", "* Day nine")
            write_file("2025/12/31.norg", "* Last year")

            local entries = journal.get_entries_in_range(0, os.time() + 1e10)

            local relpaths = vim.tbl_map(function(e)
                return e.relpath
            end, entries)
            table.sort(relpaths)

            assert.same({
                "2025" .. pathsep .. "12" .. pathsep .. "31.norg",
                "2026" .. pathsep .. "08" .. pathsep .. "01.norg",
                "2026" .. pathsep .. "08" .. pathsep .. "09.norg",
            }, relpaths)
        end)

        it("finds entries laid out with the flat strategy", function()
            write_file("2026-08-01.norg", "* Day one")
            write_file("2026-08-09.norg", "* Day nine")

            local entries = journal.get_entries_in_range(0, os.time() + 1e10)

            local relpaths = vim.tbl_map(function(e)
                return e.relpath
            end, entries)
            table.sort(relpaths)

            assert.same({ "2026-08-01.norg", "2026-08-09.norg" }, relpaths)
        end)

        it("ignores non-date files", function()
            write_file("template.norg", "* Template")
            write_file("toc.norg", "* Table of contents")
            write_file("2026/08/01.norg", "* Day one")

            local entries = journal.get_entries_in_range(0, os.time() + 1e10)

            assert.equal(1, #entries)
            assert.equal("2026" .. pathsep .. "08" .. pathsep .. "01.norg", entries[1].relpath)
        end)

        it("excludes entries outside the given range", function()
            write_file("2020/01/01.norg", "* Old entry")
            write_file("2026/08/01.norg", "* Recent entry")

            local from = os.time({ year = 2026, month = 1, day = 1 })
            local to = os.time({ year = 2026, month = 12, day = 31 })
            local entries = journal.get_entries_in_range(from, to)

            assert.equal(1, #entries)
            assert.equal(2026, entries[1].year)
        end)
    end)

    describe("parse_agenda_range", function()
        it("computes 'day' as just today", function()
            local from, to = journal.parse_agenda_range("day")
            assert.equal(os.date("*t", from).day, os.date("*t").day)
            assert.equal(to - from, 24 * 60 * 60 - 1)
        end)

        it("computes 'week' as a 7-day span containing today", function()
            local from, to = journal.parse_agenda_range("week")
            local now = os.time()
            assert.is_true(from <= now)
            assert.is_true(now <= to)
            assert.equal(to - from, 7 * 24 * 60 * 60 - 1)
        end)

        it("computes 'month' as the full current calendar month", function()
            local from, to = journal.parse_agenda_range("month")
            local now = os.date("*t")
            assert.equal(1, os.date("*t", from).day)
            assert.equal(now.month, os.date("*t", from).month)
            assert.equal(now.month, os.date("*t", to).month)
        end)

        it("computes '<N>' as the last N days including today", function()
            local from, to = journal.parse_agenda_range("3")
            assert.equal(to - from, 3 * 24 * 60 * 60 - 1)
        end)

        it("falls back to agenda_default_range when no range is given", function()
            local from_default, to_default = journal.parse_agenda_range(nil)
            local from_week, to_week = journal.parse_agenda_range("week")
            assert.equal(from_week, from_default)
            assert.equal(to_week, to_default)
        end)

        it("returns nil for an invalid range", function()
            local from = journal.parse_agenda_range("bogus")
            assert.is_nil(from)
        end)
    end)

    describe("build_agenda_lines", function()
        after_each(function()
            vim.fn.delete(ws_path:tostring(), "rf")
        end)

        it("produces heading + body + blank-line structure for a small fixture", function()
            write_file(
                "2026/08/01.norg",
                table.concat({
                    "@document.meta",
                    "title: First Entry",
                    "@end",
                    "",
                    "Some body text.",
                }, "\n")
            )
            write_file("2026/08/02.norg", "No metadata here.")

            local entries = journal.get_entries_in_range(0, os.time() + 1e10)
            local lines, line_map = journal.build_agenda_lines(entries)

            assert.equal("* 2026-08-01 - First Entry", lines[1])
            assert.equal("", lines[2])
            assert.equal("Some body text.", lines[3])
            assert.equal("", lines[4])

            -- second entry has no metadata, so the heading is just the date, no filename
            local second_heading_index
            for i, line in ipairs(lines) do
                if line:match("^%* 2026%-08%-02") then
                    second_heading_index = i
                    break
                end
            end
            assert.is_not_nil(second_heading_index)
            assert.equal("* 2026-08-02", lines[second_heading_index])

            assert.is_not_nil(line_map[1])
            assert.matches("2026" .. pathsep .. "08" .. pathsep .. "01%.norg$", line_map[1].path)
        end)
    end)
end)
