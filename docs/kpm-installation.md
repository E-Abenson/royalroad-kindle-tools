# Kindle installation

The KPM package currently contains a **read-only browser LIPC diagnostic**, not a story downloader or EPUB builder.

## Install / update using KPM

If the repository is already registered, open **KPM-Update-All** in the Kindle library to refresh the package index and upgrade installed KPM packages. Output is shown live and saved to `/mnt/us/documents/KPM-Update-All.log`.

For initial installation, open the one-time `Install-RoyalRoadTools` scriptlet. It registers the repository, refreshes its package index and installs the package. Its log is `/mnt/us/documents/RoyalRoadTools-install.log`.

## Run the read-only diagnostic

1. Open a Royal Road chapter in the Kindle's built-in browser.
2. Let it finish loading. Do not refresh during the test.
3. Return to the Kindle Home screen.
4. Open **RR-JS-Smoke-Test** from the Kindle library.
5. Read the on-screen output, then share the log at `/mnt/us/documents/RR-JS-Smoke-Test.log`.

The script checks the current foreground application and reads `com.lab126.kppbrowser getLastOpenPage`. It probes only `com.lab126.kppbrowser` and `com.lab126.browser`, without verbose property values, to discover the actual properties available on this firmware.

The script does **not** call `lipc-set-prop`, launch the browser, issue `gotoURL`, send JavaScript, modify bookmarks, read cookies, or access chapter text. It should not interrupt page loading.

## Logs

- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/RR-JS-Smoke-Test.log`
- `/mnt/us/documents/RoyalRoadTools-launch.log`
- `/mnt/us/documents/RoyalRoadTools-bookmark.log`
- `/mnt/us/documents/RoyalRoadTools.log`
- `/mnt/us/documents/RoyalRoadTools-package.log`
- `/mnt/us/documents/RoyalRoadTools-install.log`

## Safety and current limits

No browser database, bookmark, root filesystem file, cookie, credential, or browser setting is changed by **RR-JS-Smoke-Test**. It is only a diagnostic; full chapter collection and EPUB creation have not been implemented yet.
