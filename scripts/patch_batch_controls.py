#!/usr/bin/env python3
"""Patch and validate Kindle Batch Preparation controls and bounded batch runs."""

import gzip
import re
from pathlib import Path

path = Path("kpm/package/files/kindle_batch_prepare_main.lua.gz")
source = gzip.decompress(path.read_bytes()).decode("utf-8")


def once(old: str, new: str, label: str) -> None:
    global source
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    source = source.replace(old, new, 1)


if "-- KOREADER_BATCH_PREPARE_MENU_FIX_V6" not in source:
    once(
        "-- KOREADER_BATCH_PREPARE_MENU_FIX_V2",
        "-- KOREADER_BATCH_PREPARE_MENU_FIX_V6",
        "source version",
    )
    once(
        'local PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V1"',
        'local PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V2"',
        "new helper marker",
    )
    once(
        'local PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V2"',
        'local PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V2"\nlocal LEGACY_PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V1"',
        "legacy helper marker",
    )
    once(
        "\n# KOREADER_BATCH_PREPARE_V1\n",
        "\n# KOREADER_BATCH_PREPARE_V2\n",
        "embedded helper version marker",
    )
    once(
        '    os.remove(progress_path .. ".tmp")\n',
        '    os.remove(progress_path .. ".tmp")\n'
        '    if cancel_path and cancel_path ~= "" then\n'
        '        os.remove(cancel_path .. ".pause")\n'
        '    end\n',
        "pause marker cleanup",
    )
    once(
        '    local cancel_path = temp_base .. ".cancel"\n',
        '    local cancel_path = temp_base .. ".cancel"\n'
        '    local pause_path = cancel_path .. ".pause"\n',
        "pause marker path",
    )
    once(
        '        "--cancel-file", cancel_path,\n',
        '        "--cancel-file", cancel_path,\n'
        '        "--pause-file", pause_path,\n',
        "pause process argument",
    )
    once(
        '    local positions_path = epub_path:gsub("%.epub$", ".positions.json")\n'
        '    for _, path in ipairs({ epub_path, meta_path, positions_path }) do\n',
        '    local positions_path = epub_path:gsub("%.epub$", ".positions.json")\n'
        '    local partial_epub_path = epub_path:gsub("%.epub$", ".batch-partial.epub")\n'
        '    local partial_positions_path = partial_epub_path:gsub("%.epub$", ".positions.json")\n'
        '    for _, path in ipairs({ epub_path, meta_path, positions_path, partial_epub_path, partial_positions_path }) do\n',
        "cleanup of staged EPUB and position map",
    )
    once(
        '    local epub_path, meta_path = cache:getCachePaths(book)\n'
        '    local cache_ok, cache_err = cache:ensureCacheDir()\n',
        '    local epub_path, meta_path = cache:getCachePaths(book)\n'
        '    local partial_epub_path = epub_path:gsub("%.epub$", ".batch-partial.epub")\n'
        '    local partial_positions_path = partial_epub_path:gsub("%.epub$", ".positions.json")\n'
        '    os.remove(partial_epub_path)\n'
        '    os.remove(partial_positions_path)\n'
        '    local cache_ok, cache_err = cache:ensureCacheDir()\n',
        "staged output paths",
    )
    once(
        '        "--output", epub_path,\n',
        '        "--output", partial_epub_path,\n',
        "write conversion to staging EPUB",
    )
    once(
        '    if result.ok ~= true then\n'
        '        cleanupBatchFiles(epub_path, meta_path, "", "", "", "")\n'
        '    end\n'
        '    return result\n',
        '    if result.ok == true then\n'
        '        local final_positions_path = epub_path:gsub("%.epub$", ".positions.json")\n'
        '        if not lfs.attributes(partial_epub_path) then\n'
        '            cleanupBatchFiles(epub_path, meta_path, "", "", "", "")\n'
        '            return nil, { code = "missing_output", message = "The converter reported success but the staged EPUB is missing." }\n'
        '        end\n'
        '        local rename_ok, rename_err = os.rename(partial_epub_path, epub_path)\n'
        '        if not rename_ok then\n'
        '            cleanupBatchFiles(epub_path, meta_path, "", "", "", "")\n'
        '            return nil, { code = "commit_failed", message = "Could not commit the completed EPUB: " .. tostring(rename_err) }\n'
        '        end\n'
        '        if lfs.attributes(partial_positions_path) then\n'
        '            local positions_ok, positions_err = os.rename(partial_positions_path, final_positions_path)\n'
        '            if not positions_ok then\n'
        '                os.remove(epub_path)\n'
        '                cleanupBatchFiles(epub_path, meta_path, "", "", "", "")\n'
        '                return nil, { code = "positions_commit_failed", message = "Could not commit the reading-position map: " .. tostring(positions_err) }\n'
        '            end\n'
        '        end\n'
        '        result.output_path = epub_path\n'
        '    else\n'
        '        cleanupBatchFiles(epub_path, meta_path, "", "", "", "")\n'
        '    end\n'
        '    return result\n',
        "atomic commit of staged EPUB",
    )
    once(
        '    local result, err = self:convertWithProgress(helper, cache, settings, book, index, total)\n',
        '    -- Remove stale or interrupted cache contents before starting again.\n'
        '    cache:clearBookCache(book)\n'
        '    local result, err = self:convertWithProgress(helper, cache, settings, book, index, total)\n',
        "clear stale cache before retry",
    )

    legacy_gate = '''    if source:find(PATCH_MARKER, 1, true) then
        return false, "already_patched"
    end
    if not source:find("VERSION = 1", 1, true) or not source:find("def cmd_convert(args):", 1, true) then
'''
    legacy_upgrade = '''    if source:find(PATCH_MARKER, 1, true) then
        return false, "already_patched"
    end

    -- Upgrade the previous progress-enabled helper in place. Do not try to
    -- apply the original v0.0.11 patch a second time: its imports and convert
    -- function have already been modified by the V1 installation.
    if source:find(LEGACY_PATCH_MARKER, 1, true) then
        local ok, patched = pcall(function()
            local result = source
            result = replaceOnce(
                result,
                '        self.cancel_file = getattr(args, "cancel_file", "") or ""\\n',
                '        self.cancel_file = getattr(args, "cancel_file", "") or ""\\n'
                    .. '        self.pause_file = getattr(args, "pause_file", "") or ""\\n',
                "legacy pause-file setting"
            )
            result = replaceOnce(
                result,
                '    def check_cancel(self):\\n'
                    .. '        if self.cancel_file and os.path.exists(self.cancel_file):\\n'
                    .. '            raise BatchConversionCancelled("Batch preparation cancelled")\\n',
                '    def check_cancel(self):\\n'
                    .. '        while True:\\n'
                    .. '            if self.cancel_file and os.path.exists(self.cancel_file):\\n'
                    .. '                raise BatchConversionCancelled("Batch preparation cancelled")\\n'
                    .. '            if not self.pause_file or not os.path.exists(self.pause_file):\\n'
                    .. '                return\\n'
                    .. '            time.sleep(0.15)\\n',
                "legacy pause checkpoint"
            )
            result = replaceOnce(
                result,
                '    p_convert.add_argument("--cancel-file", default="")\\n',
                '    p_convert.add_argument("--cancel-file", default="")\\n'
                    .. '    p_convert.add_argument("--pause-file", default="")\\n',
                "legacy pause CLI argument"
            )
            result = replaceOnce(
                result,
                LEGACY_PATCH_MARKER,
                PATCH_MARKER,
                "helper version marker"
            )
            return result
        end)
        if not ok then
            return nil, tostring(patched)
        end

        local backup_path = helper_path .. ".batch-prepare.bak"
        if not readFile(backup_path) then
            local backup_ok, backup_err = writeFile(backup_path, source)
            if not backup_ok then
                return nil, "Could not create helper backup: " .. tostring(backup_err)
            end
        end
        local temp_path = helper_path .. ".batch-prepare.tmp"
        local write_ok, write_err = writeFile(temp_path, patched)
        if not write_ok then
            return nil, "Could not write upgraded helper: " .. tostring(write_err)
        end
        local rename_ok, rename_err = os.rename(temp_path, helper_path)
        if not rename_ok then
            os.remove(temp_path)
            return nil, "Could not replace upgraded helper: " .. tostring(rename_err)
        end
        return true, "pause_support_upgraded"
    end

    if not source:find("VERSION = 1", 1, true) or not source:find("def cmd_convert(args):", 1, true) then
'''
    once(legacy_gate, legacy_upgrade, "legacy helper migration path")

    once(
        '            help_text = _("Convert all locally available Kindle KFX books one after another. Existing prepared books are skipped. Tap the progress message to pause, then choose Abort to stop the current book and the whole batch."),',
        '            help_text = _("Prepare eligible Kindle KFX books. The batch limit controls the maximum number of new conversion attempts in one run; already prepared books do not count. Pause waits for a safe checkpoint; Resume continues; Abort stops the batch."),',
        "batch help text",
    )
    once(
        '            text = _("Prepare all Kindle books for KOReader"),',
        '            text = _("Prepare Kindle books for KOReader"),',
        "batch menu action label",
    )
    once(
        '    if not self.settings.min_free_mb then self.settings.min_free_mb = DEFAULT_MIN_FREE_MB end\n',
        '    if not self.settings.min_free_mb then self.settings.min_free_mb = DEFAULT_MIN_FREE_MB end\n'
        '    if self.settings.max_books == nil then self.settings.max_books = 1 end\n',
        "safe default batch limit",
    )
    once(
        'function PLUGIN:addToMainMenu(menu_items)\n',
        '''function PLUGIN:createBatchLimitMenuItem()
    local choices = { 1, 2, 3, 5, 10, 0 }
    local submenu = {}
    for choice_index, limit in ipairs(choices) do
        table.insert(submenu, {
            text = limit == 0 and _("All remaining eligible books") or T(_("Up to %1 new books"), limit),
            checked_func = function() return self.settings.max_books == limit end,
            callback = function()
                self.settings.max_books = limit
                self:saveSettings()
                if limit == 0 then
                    self:showInfo(_("The next batch will attempt all remaining eligible books."), 4)
                else
                    self:showInfo(T(_("The next batch will attempt up to %1 new book conversions. Already prepared books do not count against this limit."), limit), 4)
                end
            end,
        })
    end
    return {
        text_func = function()
            local limit = self.settings.max_books or 1
            if limit == 0 then return _("Batch limit: all remaining books") end
            return T(_("Batch limit: up to %1 new books"), limit)
        end,
        sub_item_table = submenu,
    }
end

function PLUGIN:addToMainMenu(menu_items)
''',
        "batch limit submenu",
    )
    once(
        '        table.insert(sub_items, self:createReserveMenuItem())\n',
        '        table.insert(sub_items, self:createBatchLimitMenuItem())\n'
        '        table.insert(sub_items, self:createReserveMenuItem())\n',
        "add batch limit submenu",
    )
    once(
        '        local aborted = false\n'
        '        for index, book in ipairs(convertible) do\n',
        '        local aborted = false\n'
        '        local max_books = math.max(0, math.floor(tonumber(self.settings.max_books) or 1))\n'
        '        local attempted_count = 0\n'
        '        local not_attempted_count = 0\n'
        '        for index, book in ipairs(convertible) do\n',
        "batch attempt limit counters",
    )
    once(
        '            else\n'
        '                local status, result = self:prepareOneBook(helper, cache, settings, book, index, #convertible)\n',
        '            elseif max_books > 0 and attempted_count >= max_books then\n'
        '                not_attempted_count = not_attempted_count + 1\n'
        '            else\n'
        '                attempted_count = attempted_count + 1\n'
        '                local status, result = self:prepareOneBook(helper, cache, settings, book, index, #convertible)\n',
        "enforce maximum new conversion attempts",
    )
    once(
        '        else\n'
        '            summary = summary .. "\\n\\nAll eligible books have been checked."\n'
        '        end\n',
        '        else\n'
        '            if not_attempted_count > 0 then\n'
        '                summary = summary .. string.format("\\n\\nBatch limit reached. %d eligible books were left untouched. Increase the limit or run the batch again to continue.", not_attempted_count)\n'
        '            else\n'
        '                summary = summary .. "\\n\\nAll eligible books have been checked."\n'
        '            end\n'
        '        end\n',
        "batch limit completion summary",
    )

    function_start = source.find("function PLUGIN:convertWithProgress")
    start = source.find(
        "    local title = book.display_name or book.title or book.id\n",
        function_start,
    )
    end_at = source.find("    if aborted then\n", start)
    if function_start < 0 or start < 0 or end_at < 0:
        raise SystemExit("Could not isolate conversion progress loop")

    replacement = """    local title = (book.display_name or book.title or book.id):gsub("[%c]", " ")
    local function makeProgressText(state)
        local percent = state and tonumber(state.percent) or 0
        local stage = tostring(state and state.stage or "Starting conversion"):gsub("[%c]", " ")
        if #stage > 28 then stage = stage:sub(1, 28) end
        local filled = math.max(0, math.min(20, math.floor(percent / 5)))
        local bar = string.rep("#", filled) .. string.rep("-", 20 - filled)
        local free = state and friendlyBytes(state.free_bytes) or "unknown"
        return string.format(
            "Preparing book %d of %d\\n%s\\n[%s] %3.0f%%\\n%-28s\\nFree storage: %8s\\nTap anywhere to open controls",
            book_number, book_total, title, bar, percent, stage, free
        )
    end

    local progress_text = makeProgressText(readJson(progress_path))
    local aborted = false
    Trapper:setPausedText(
        _("Pause this book at the next safe checkpoint?"),
        _("Pause"),
        _("Continue")
    )

    local first_update = true
    while processAlive(pid) do
        local state = readJson(progress_path)
        if state then
            progress_text = makeProgressText(state)
        end

        -- Reuse the same InfoMessage after its first display. Recreating it
        -- every 150 ms flushes touch events and can swallow the user's tap.
        local keep_going = Trapper:info(progress_text, not first_update)
        first_update = false
        if not keep_going then
            writeFile(pause_path, "pause\\n")
            local abort_batch = Trapper:confirm(
                _("Preparation is paused at a safe checkpoint.\\n\\nResume to continue, or abort to discard the incomplete book and stop the rest of the batch. Completed books are kept."),
                _("Resume"),
                _("Abort batch")
            )
            if abort_batch then
                aborted = true
                writeCancel(cancel_path)
                signalProcess(pid, 15)
                break
            else
                os.remove(pause_path)
                progress_text = makeProgressText(readJson(progress_path))
                Trapper:info(progress_text)
                first_update = false
            end
        end
        ffiUtil.sleep(0.15)
    end

"""
    source = source[:start] + replacement + source[end_at:]
    path.write_bytes(gzip.compress(source.encode("utf-8"), mtime=0))

data = gzip.decompress(path.read_bytes()).decode("utf-8")
block = re.search(r"local PROGRESS_CLASS = " + re.escape("[==[") + r"(.*?)" + re.escape("]==]"), data, re.S)
if not block:
    raise SystemExit("Embedded Python progress class was not found")
compile(block.group(1), "batch_progress.py", "exec")

required = [
    "-- KOREADER_BATCH_PREPARE_MENU_FIX_V6",
    "local partial_epub_path = epub_path:gsub",
    "The converter reported success but the staged EPUB is missing.",
    "commit_failed",
    "cache:clearBookCache(book)",
    'local PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V2"',
    'local LEGACY_PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V1"',
    'if source:find(LEGACY_PATCH_MARKER, 1, true) then',
    'self.pause_file = getattr(args, "pause_file", "") or ""',
    'p_convert.add_argument("--pause-file", default="")',
    '"--pause-file", pause_path,',
    "Tap anywhere to open controls",
    "Pause this book at the next safe checkpoint?",
    '_("Resume")',
    '_("Abort batch")',
    "function PLUGIN:createBatchLimitMenuItem()",
    "Batch limit: all remaining books",
    "self.settings.max_books = 1",
    "local max_books = math.max(0, math.floor(tonumber(self.settings.max_books) or 1))",
    "attempted_count >= max_books",
    "not_attempted_count = not_attempted_count + 1",
    "Batch limit reached.",
]
for marker in required:
    if marker not in data:
        raise SystemExit("Batch controls validation failed; missing: " + marker)

print("Validated helper migration, pause/resume/abort, staged output protection, and selectable batch-size limits.")
