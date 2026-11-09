#!/usr/bin/env python3
"""Patch the bundled Kindle Batch Preparation source before KPM packaging."""

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


if "-- KOREADER_BATCH_PREPARE_MENU_FIX_V3" not in source:
    once(
        "-- KOREADER_BATCH_PREPARE_MENU_FIX_V2",
        "-- KOREADER_BATCH_PREPARE_MENU_FIX_V3",
        "source version",
    )
    once(
        'local PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V1"',
        'local PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V2"',
        "helper marker",
    )
    once(
        '        self.cancel_file = getattr(args, "cancel_file", "") or ""\n',
        '        self.cancel_file = getattr(args, "cancel_file", "") or ""\n'
        '        self.pause_file = getattr(args, "pause_file", "") or ""\n',
        "pause path",
    )
    once(
        '    def check_cancel(self):\n'
        '        if self.cancel_file and os.path.exists(self.cancel_file):\n'
        '            raise BatchConversionCancelled("Batch preparation cancelled")\n',
        '    def check_cancel(self):\n'
        '        while True:\n'
        '            if self.cancel_file and os.path.exists(self.cancel_file):\n'
        '                raise BatchConversionCancelled("Batch preparation cancelled")\n'
        '            if not self.pause_file or not os.path.exists(self.pause_file):\n'
        '                return\n'
        '            time.sleep(0.15)\n',
        "pause checkpoint",
    )
    once(
        '    p_convert.add_argument("--cancel-file", default="")\n',
        '    p_convert.add_argument("--cancel-file", default="")\n'
        '    p_convert.add_argument("--pause-file", default="")\n',
        "pause CLI argument",
    )
    once(
        '    os.remove(progress_path .. ".tmp")\n',
        '    os.remove(progress_path .. ".tmp")\n'
        '    if cancel_path and cancel_path ~= "" then\n'
        '        os.remove(cancel_path .. ".pause")\n'
        '    end\n',
        "pause cleanup",
    )
    once(
        '    local cancel_path = temp_base .. ".cancel"\n',
        '    local cancel_path = temp_base .. ".cancel"\n'
        '    local pause_path = cancel_path .. ".pause"\n',
        "pause marker",
    )
    once(
        '        "--cancel-file", cancel_path,\n',
        '        "--cancel-file", cancel_path,\n'
        '        "--pause-file", pause_path,\n',
        "pause process argument",
    )
    once(
        '            help_text = _("Convert all locally available Kindle KFX books one after another. Existing prepared books are skipped. Tap the progress message to pause, then choose Abort to stop the current book and the whole batch."),',
        '            help_text = _("Convert all locally available Kindle KFX books one after another. Existing prepared books are skipped. Tap the progress message to open controls. Pause waits for a safe checkpoint; Resume continues; Abort stops this and all remaining books."),',
        "help text",
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
        -- every 150 ms flushes touch events and can swallow the tap.
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
block = re.search(r"local PROGRESS_CLASS = \[==\[(.*?)\]==\]", data, re.S)
if not block:
    raise SystemExit("Embedded Python progress class was not found")
compile(block.group(1), "batch_progress.py", "exec")

required = [
    "-- KOREADER_BATCH_PREPARE_MENU_FIX_V3",
    'local PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V2"',
    'self.pause_file = getattr(args, "pause_file", "") or ""',
    'p_convert.add_argument("--pause-file", default="")',
    '"--pause-file", pause_path,',
    "Tap anywhere to open controls",
    "Pause this book at the next safe checkpoint?",
    '_("Resume")',
    '_("Abort batch")',
]
for marker in required:
    if marker not in data:
        raise SystemExit("Batch controls validation failed; missing: " + marker)

print("Validated responsive touch refresh and distinct Pause, Resume, Abort controls.")
