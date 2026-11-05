# Royal Road Kindle Tools — KPM package

This package currently installs a read-only Royal Road browser diagnostic, not a downloader.

## One-tap KPM updater

The package installs a Kindle library item named **KPM-Update-All**. Tap it to run `;kpm update` followed by `;kpm upgrade`. It refreshes configured repositories, upgrades installed packages with automatic confirmation (`-y`), and writes output to `/mnt/us/documents/KPM-Update-All.log`.

## Plain-text bookmarklet test

Open **RR-JS-Smoke-Test** from the Kindle library. It backs up the browser database and temporarily changes only the bookmark titled **Royal Road Session Test** to a tiny script that replaces the current page body's text with only **RR JS EXECUTED**. It does not use an alert, create an overlay, or make a network request.

Open a Royal Road chapter and tap **Royal Road Session Test** in the browser bookmarks.

- If all chapter text disappears and only **RR JS EXECUTED** remains, JavaScript from the bookmark ran.
- If the page is unchanged, the bookmark JavaScript did not visibly execute.

This changes only the current page in browser memory. Reload the chapter or press Back to restore it.

## Restore the full diagnostic bookmark

Open **RoyalRoadTools** from the Kindle library. This reinstalls the full diagnostic bookmarklet and backs up the browser database before changing only that bookmark.

## Logs

- `/mnt/us/documents/RoyalRoadTools-bookmark.log` — bookmark setup and verification.
- `/mnt/us/documents/RoyalRoadTools.log` — general package log.
- `/mnt/us/documents/RR-JS-Smoke-Test.log` — smoke-test setup log.
- `/mnt/us/documents/KPM-Update-All.log` — one-tap repository refresh and package-upgrade output.

## Removal

Run `;kpm uninstall royalroad-kindle-tools`. Existing backup and log files are retained.
