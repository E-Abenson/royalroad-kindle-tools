# Royal Road Kindle Tools — KPM package

This package currently installs a read-only Royal Road browser diagnostic, not a downloader.

## Separate log files

- `/mnt/us/documents/RoyalRoadTools-bookmark.log` records bookmark installation/update attempts, the bookmarklet length and hash, and whether the bookmark entry was verified.
- `/mnt/us/documents/RoyalRoadTools.log` records general package/bookmark setup activity.
- After the browser diagnostic runs, it displays results and provides a **SAVE SEPARATE TEST LOG FILE** link. Tap that link to save the browser test results as a separate `.log` file.

The browser test log contains only aggregate diagnostics (page host/path, character counts, HTTP status, challenge detection, and any error). It does not record chapter text, cookies, credentials, or history.

## Test whether Kindle executes bookmarklets

An update now installs a temporary Kindle library item named **RR-JS-Smoke-Test**.

1. Open **RR-JS-Smoke-Test** from the Kindle library. It backs up the browser database and temporarily changes only the bookmark titled **Royal Road Session Test** to `javascript:alert('RR JS EXECUTED')`.
2. Open a Royal Road chapter in the Kindle browser.
3. Select **Royal Road Session Test** from the browser bookmarks.
4. If a popup says **RR JS EXECUTED**, the browser executed the bookmark JavaScript. If nothing happens, the browser is not executing JavaScript from that saved bookmark.

The smoke-test setup log is `/mnt/us/documents/RR-JS-Smoke-Test.log`. Its database backup is saved under `/mnt/us/documents/RoyalRoadTools-backups/`.

## Restore the full diagnostic bookmark

After the smoke test, open **RoyalRoadTools** from the Kindle library. This reruns the package's normal bookmark updater and restores the full Royal Road Session Test bookmarklet. It backs up the browser database before changing that bookmark. No other bookmarks, cookies, or history are touched.

## Update an existing installation

Run `;kpm update` and then `;kpm upgrade`. KPM downloads the updated package from this repository; no USB transfer or manual download is needed. The package install hook copies both Kindle library launchers into `documents`.

## Removal

Run `;kpm uninstall royalroad-kindle-tools`. Existing backup and log files are retained.
