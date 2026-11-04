# Royal Road Kindle Tools — KPM package

This first package installs a **read-only browser-session diagnostic**, not a full-story downloader.

## What it does

1. Installs a Kindle library scriptlet named **RoyalRoadTools**.
2. During package installation, it tries to add one browser bookmark called **Royal Road Session Test**. The bookmark helper first creates a timestamped SQLite backup in `/mnt/us/documents/RoyalRoadTools-backups/`.
3. If the browser database is busy during installation, opening **RoyalRoadTools** from the Kindle library retries that same safe operation. It detects an existing exact bookmark and does not create duplicates.
4. The bookmark runs one same-origin fetch of the currently open Royal Road chapter and displays aggregate results only: status, response size, challenge markers, and chapter-text character counts.

It does not read or transmit cookies, browser history, authorization headers, or chapter text. It does not solve or work around Cloudflare challenges.

## Test procedure

- Open a Royal Road chapter in the Kindle browser.
- Open the browser bookmarks/favorites menu.
- Select **Royal Road Session Test**.
- Read the alert and note the result.

A successful result is only evidence that one same-origin fetch worked. It is not proof that a whole story can be downloaded.

## Rollback

Run `;kpm uninstall royalroad-kindle-tools`. The uninstall hook makes a fresh backup, removes only the exact bookmark created by this package, and removes the package-owned Kindle library scriptlet. Existing backup files are retained.
