# Kindle installation

This is currently a diagnostic-only package. It tests one chapter using the Kindle browser's ordinary same-origin request. It does not yet download a story or create an EPUB.

## Install / update using KPM

If this repository is already added to KPM, run these commands once to install or upgrade the package:

1. `;kpm update`
2. `;kpm upgrade`

The package installs three Kindle library items:

- **RoyalRoadTools** — restores/installs the real chapter diagnostic bookmark.
- **RR-JS-Smoke-Test** — temporarily installs the visible JavaScript bookmark test.
- **KPM-Update-All** — refreshes the repositories and upgrades all KPM packages with one tap.

## Use the one-tap updater

Open **KPM-Update-All** from the Kindle library whenever you want to perform the equivalent of `;kpm update` followed by `;kpm upgrade`. The full output is saved to `/mnt/us/documents/KPM-Update-All.log`.

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
