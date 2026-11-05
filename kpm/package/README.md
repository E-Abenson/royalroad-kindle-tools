# Royal Road Kindle Tools — KPM package

This package installs a read-only Royal Road browser diagnostic, not a downloader.

## Separate log files

- \`/mnt/us/documents/RoyalRoadTools-bookmark.log\` records bookmark installation/update attempts, the bookmarklet length and hash, and whether the bookmark entry was verified.
- When the browser test runs, it displays the results and provides a **SAVE SEPARATE TEST LOG FILE** link. Tap that link to save the browser test results as a separate \`.log\` file through the browser download mechanism.

The browser test log contains only aggregate diagnostics (page host/path, character counts, HTTP status, challenge detection, and any error). It does not record chapter text, cookies, credentials, or history.

## Test procedure

1. Open a Royal Road chapter in the Kindle browser.
2. Select **Royal Road Session Test** from the browser bookmarks.
3. The bookmark first displays a confirmation alert. If you do not see that alert, the bookmark JavaScript is not being executed by the browser.
4. After the test, tap **SAVE SEPARATE TEST LOG FILE** to save the results.

## Update the bookmark

Open **RoyalRoadTools** from the Kindle library to run the package's bookmark updater. It backs up the browser database before changing only the bookmark titled **Royal Road Session Test**.

## Rollback

Run \`;kpm uninstall royalroad-kindle-tools\`. Existing backup and log files are retained.
