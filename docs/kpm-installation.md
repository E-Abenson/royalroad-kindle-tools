# Kindle installation

This is currently a diagnostic-only package. It tests one chapter using the Kindle browser's ordinary same-origin request. It does not yet download a story or create an EPUB.

## One-time bootstrap

1. Download the bootstrap scriptlet from the latest GitHub Release:
   https://github.com/E-Abenson/royalroad-kindle-tools/releases/latest/download/Install-RoyalRoadTools.sh
2. Save it into the Kindle documents folder and open it from the Kindle library. It adds this KPM repository, refreshes the index, and installs the package.
3. The package installation hook copies the RoyalRoadTools launcher into documents and attempts to add the Royal Road Session Test bookmark. It creates a timestamped local database backup before changing that bookmark.

The bootstrap writes its log to `/mnt/us/documents/RoyalRoadTools-install.log`. Bookmark setup writes to `/mnt/us/documents/RoyalRoadTools-bookmark.log` and `/mnt/us/documents/RoyalRoadTools.log`.

## Update an existing installation through KPM

If this repository is already added to KPM, no manual download is needed. Run these Kindle search-bar commands:

1. `;kpm update`
2. `;kpm upgrade`

KPM downloads the newer package from the configured repository. The package install hook updates the library launchers and reinstalls the full diagnostic bookmarklet.

## Test whether bookmark JavaScript executes

1. Open **RR-JS-Smoke-Test** from the Kindle library. It installs a one-line bookmarklet that only displays `RR JS EXECUTED`.
2. Open a Royal Road chapter in the Kindle browser and select **Royal Road Session Test** from bookmarks.
3. If the popup appears, saved JavaScript bookmarks execute. If it does not, the browser is not executing that JavaScript URL.
4. The setup log is `/mnt/us/documents/RR-JS-Smoke-Test.log`.

## Restore the full diagnostic

Open **RoyalRoadTools** from the Kindle library. It restores the full chapter-session diagnostic bookmarklet. It backs up the database before changing only the package's test bookmark.

## Run the browser diagnostic

1. Open a Royal Road chapter in the Kindle browser.
2. Open the browser bookmarks/favorites list and select **Royal Road Session Test**.
3. The diagnostic should show a confirmation alert, then a panel with visible/returned chapter character counts, HTTP status, response size, and Cloudflare challenge markers. It does not transmit chapter text or browser credentials.
4. Tap **SAVE SEPARATE TEST LOG FILE** to save the result.

## Removal

Run `;kpm uninstall royalroad-kindle-tools`. The uninstall hook backs up the browser database again, removes only this package's exact bookmark URL, and removes its Kindle library launchers. Existing backup files are retained.

## Current limitation

A successful same-origin fetch on one chapter does not prove that a complete chapter list can be read or that an entire story can be safely collected. The next stage is deliberately gated on this test result. If the browser receives a challenge, the project will stop rather than attempt to bypass it.
