# Royal Road Kindle Tools — KPM package

This package currently installs a read-only Royal Road browser diagnostic, not a downloader.

## One-tap KPM updater

The package installs a Kindle library item named **KPM-Update-All**. Tap it to run the equivalent of these two commands automatically:

1. `;kpm update`
2. `;kpm upgrade`

It refreshes the configured KPM repositories, then upgrades all installed KPM packages. The upgrade runs with automatic confirmation (`-y`). It records the full output in `/mnt/us/documents/KPM-Update-All.log`. The scriptlet uses atomic replacement so it remains safe when it upgrades the package that installed it.

## Logs

- `/mnt/us/documents/RoyalRoadTools-bookmark.log` records bookmark installation/update attempts, the bookmarklet length and hash, and whether the bookmark entry was verified.
- `/mnt/us/documents/RoyalRoadTools.log` records general package/bookmark setup activity.
- `/mnt/us/documents/RR-JS-Smoke-Test.log` records whether the temporary visible-DOM smoke-test bookmark was installed and verified.
- `/mnt/us/documents/KPM-Update-All.log` records repository refresh and package-upgrade output.
- After the browser diagnostic runs, it displays results and provides a **SAVE SEPARATE TEST LOG FILE** link. Tap that link to save the browser test results as a separate `.log` file.

The browser test log contains only aggregate diagnostics. It does not record chapter text, cookies, credentials, or history.

## Test whether Kindle executes bookmark JavaScript

Open **RR-JS-Smoke-Test** from the Kindle library. It backs up the browser database and temporarily changes only the bookmark titled **Royal Road Session Test** to a small bookmarklet that inserts a large white panel reading **RR JS EXECUTED** directly into the open page. It deliberately does not use `alert()`.

Then open a Royal Road chapter and tap **Royal Road Session Test** from the browser bookmarks.

- If the white panel appears, bookmark JavaScript is executing.
- If no panel appears, we need to investigate the browser's handling of JavaScript bookmark URLs.

The smoke-test setup log is `/mnt/us/documents/RR-JS-Smoke-Test.log`. Its database backup is saved under `/mnt/us/documents/RoyalRoadTools-backups/`.

## Restore the full diagnostic bookmark

Open **RoyalRoadTools** from the Kindle library. This reruns the package's normal bookmark updater and restores the full Royal Road Session Test bookmarklet. It backs up the browser database before changing that bookmark. No other bookmarks, cookies, or history are touched.

## Update the package

Use **KPM-Update-All** to refresh repositories and upgrade installed KPM packages. The first installation still requires the normal KPM commands once; after the library item is installed, future updates are one tap.

## Removal

Run `;kpm uninstall royalroad-kindle-tools`. Existing backup and log files are retained.
