# Royal Road Kindle Tools — KPM package

This first package installs a **read-only browser-session diagnostic**, not a full-story downloader.

## What it does

1. Installs a Kindle library scriptlet named RoyalRoadTools.
2. When opened, the scriptlet asks KPM to add one browser bookmark called **Royal Road Session Test**.
3. Before changing /var/local/KPPBrowser.db, the helper creates a timestamped SQLite backup in /mnt/us/documents/RoyalRoadTools-backups/.
4. The bookmark runs one same-origin fetch of the currently open Royal Road chapter and displays only aggregate results: status, response size, challenge markers, and chapter-text character counts.

It does not read or transmit cookies, browser history, authorization headers, or chapter text. It does not solve or work around Cloudflare challenges.

## Test procedure

- Open a Royal Road chapter in the Kindle browser.
- Open the RoyalRoadTools item once from the Kindle library. This adds the bookmark.
- Return to the Royal Road chapter and open the browser's bookmarks/favorites menu.
- Select Royal Road Session Test.
- Record the result shown in the alert.

A successful result is only evidence that one same-origin page fetch worked. It is not proof that a whole story can be downloaded.

## Rollback

Run ;kpm uninstall royalroad-kindle-tools. The uninstall hook makes a fresh backup, removes only the exact bookmark created by this package, and removes the package-owned library scriptlet. Existing backup files are retained.
