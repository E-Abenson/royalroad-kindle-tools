# Royal Road Kindle Tools — KPM package

This package installs a **read-only browser-session diagnostic**, not a full-story downloader.

## What it does

1. Installs a Kindle library scriptlet named **RoyalRoadTools**.
2. Adds or updates one browser bookmark called **Royal Road Session Test**. Before changing the browser database, it creates a timestamped SQLite backup in \`/mnt/us/documents/RoyalRoadTools-backups/\`.
3. Opening **RoyalRoadTools** from the Kindle library retries the bookmark setup.
4. The bookmark runs one same-origin request for the currently open Royal Road chapter. It shows a visible on-page panel immediately, then displays aggregate results for 10 seconds.

The test reports visible and returned chapter-text character counts, HTTP status, response size, final origin, and whether challenge markers were detected. It does not transmit or store cookies, browser history, authorization headers, or chapter text. It does not solve or work around Cloudflare challenges.

## Test procedure

- Open a Royal Road chapter in the Kindle browser.
- Open the browser bookmarks/favorites menu.
- Select **Royal Road Session Test**.
- A progress panel should appear immediately. The final result remains visible for 10 seconds.

A successful result is only evidence that one same-origin request worked. It is not proof that a whole story can be downloaded.

## Updating the bookmark

Open **RoyalRoadTools** from the Kindle library after updating the package. The helper replaces only the bookmark with the exact title **Royal Road Session Test**, after backing up the browser database. It leaves other bookmarks alone.

## Rollback

Run \`;kpm uninstall royalroad-kindle-tools\`. The uninstall hook removes only the exact package bookmark and package-owned Kindle library scriptlet. Existing backup files are retained.
