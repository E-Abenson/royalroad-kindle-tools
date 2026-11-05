# Kindle installation

This package is currently a diagnostic-only project; it does not yet download a story or create an EPUB.

## One-tap updater

Open **KPM-Update-All** from the Kindle library to refresh KPM repositories and upgrade all installed packages. Output is saved to `/mnt/us/documents/KPM-Update-All.log`.

## Plain-text bookmarklet test

1. Open **RR-JS-Smoke-Test** from the Kindle library. It backs up the browser database and temporarily changes **Royal Road Session Test** to a tiny script that replaces the current page body's text with only **RR JS EXECUTED**.
2. Open a Royal Road chapter and tap **Royal Road Session Test** in the browser bookmarks.
3. If the chapter text disappears and only the test phrase remains, bookmark JavaScript is executing. If the page is unchanged, it did not visibly execute.
4. Reload the chapter or press Back to restore the original text.
5. Setup log: `/mnt/us/documents/RR-JS-Smoke-Test.log`.

## Restore the full diagnostic

Open **RoyalRoadTools** from the Kindle library to restore the full browser-session diagnostic bookmarklet. It backs up the database before changing only the test bookmark.

## Removal

Run `;kpm uninstall royalroad-kindle-tools`. Existing backup and log files are retained.
