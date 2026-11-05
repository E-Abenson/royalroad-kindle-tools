# Royal Road Kindle Tools — KPM package

This package currently installs a read-only Royal Road browser diagnostic, not a downloader.

## Kindle-screen progress and logs

Every library scriptlet is designed to show its progress on the Kindle screen through the jailbreak's shell integration. The same messages are also saved in log files. Output is not redirected exclusively to a file.

- `KPM-Update-All` shows the KPM repository refresh and package-upgrade output live; log: `/mnt/us/documents/KPM-Update-All.log`.
- `RoyalRoadTools` shows bookmark setup stages and the helper's output; logs: `RoyalRoadTools-launch.log`, `RoyalRoadTools.log`, and `RoyalRoadTools-bookmark.log`.
- `RR-JS-Smoke-Test` shows each validation, backup and bookmark-installation stage; log: `RR-JS-Smoke-Test.log`.
- Package install and uninstall hooks also print their steps; log: `RoyalRoadTools-package.log`.
- The one-time bootstrap installer shows repository registration, index refresh and installation output; log: `RoyalRoadTools-install.log`.

## One-tap KPM updater

Open **KPM-Update-All** from the Kindle library. It runs `;kpm update` followed by `;kpm upgrade` (with automatic confirmation). KPM's own messages are streamed to the display and copied to the log. The script preserves the actual KPM exit status so a failed refresh prevents the upgrade step.

## Plain-text bookmarklet test

Open **RR-JS-Smoke-Test** from the Kindle library. It backs up the browser database and temporarily changes only the bookmark titled **Royal Road Session Test** to a tiny script that replaces the current page body's text with only **RR JS EXECUTED**. It does not use an alert, create an overlay, or make a network request.

Open a Royal Road chapter and tap **Royal Road Session Test** in the browser bookmarks.

- If all chapter text disappears and only **RR JS EXECUTED** remains, JavaScript from the bookmark ran.
- If the page is unchanged, the bookmark JavaScript did not visibly execute.

This changes only the current page in browser memory. Reload the chapter or press Back to restore it.

## Restore the full diagnostic bookmark

Open **RoyalRoadTools** from the Kindle library. This reinstalls the full diagnostic bookmarklet and backs up the browser database before changing only that bookmark.

## Removal

Run `;kpm uninstall royalroad-kindle-tools`. Existing backup and log files are retained.
