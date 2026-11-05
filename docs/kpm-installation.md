# Kindle installation

This is currently a diagnostic-only package. It tests one chapter using the Kindle browser's ordinary same-origin request. It does not yet download a story or create an EPUB.

## Update an existing installation through KPM

If this repository is already added to KPM, no manual download is needed. Run these Kindle search-bar commands:

1. `;kpm update`
2. `;kpm upgrade`

KPM downloads the newer package from the configured repository. The package install hook copies both Kindle library launchers into `documents`.

## Test whether bookmark JavaScript executes

1. Open **RR-JS-Smoke-Test** from the Kindle library. It installs a test bookmarklet that adds a large white panel reading **RR JS EXECUTED** to the page. This test does not use an alert dialog.
2. Open a Royal Road chapter in the Kindle browser and select **Royal Road Session Test** from bookmarks.
3. If the panel appears, bookmark JavaScript runs. If it does not, we need to investigate the browser's handling of JavaScript bookmark URLs.
4. The setup log is `/mnt/us/documents/RR-JS-Smoke-Test.log`.

## Restore the full diagnostic

Open **RoyalRoadTools** from the Kindle library. It restores the full chapter-session diagnostic bookmarklet. It backs up the database before changing only the package's test bookmark.

## Run the browser diagnostic

1. Open a Royal Road chapter in the Kindle browser.
2. Open the browser bookmarks/favorites list and select **Royal Road Session Test**.
3. The diagnostic should show a confirmation alert, then a panel with visible/returned chapter character counts, HTTP status, response size, and Cloudflare challenge markers. It does not transmit chapter text or browser credentials.
4. Tap **SAVE SEPARATE TEST LOG FILE** to save the result.

## Removal

Run `;kpm uninstall royalroad-kindle-tools`. Existing backup and log files are retained.
