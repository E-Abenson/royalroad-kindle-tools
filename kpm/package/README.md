# Royal Road Kindle Tools — KPM package

This package currently contains a **read-only browser LIPC diagnostic**, not a story downloader or EPUB builder.

## Kindle library items

- **RR-JS-Smoke-Test** — inventories the built-in browser's LIPC services and records the active app and last-open page. It deliberately does not navigate, launch, refresh, or inject into the browser.
- **RoyalRoadTools** — the older bookmark setup/repair launcher, retained for the earlier bookmark test.
- **KPM-Update-All** — refreshes package repositories and upgrades installed packages.

## Run the read-only diagnostic

1. Open a Royal Road chapter in the Kindle's built-in browser.
2. Let it finish loading. Do not refresh during the test.
3. Return to the Kindle Home screen.
4. Open **RR-JS-Smoke-Test** from the Kindle library.
5. Read the on-screen output, then share the log at `/mnt/us/documents/RR-JS-Smoke-Test.log`.

The script checks the current foreground application and reads `com.lab126.kppbrowser getLastOpenPage`. It probes only `com.lab126.kppbrowser` and `com.lab126.browser`, without verbose property values, to discover the actual properties available on this firmware.

The script does **not** call `lipc-set-prop`, launch the browser, issue `gotoURL`, send JavaScript, modify bookmarks, read cookies, or access chapter text. It should not interrupt page loading.

## Why injection is not enabled yet

The earlier experimental script tried `com.lab126.browser gotoURL`, but that property was not verified on the device and the page stopped loading during the test. Public LIPC inventories show `com.lab126.kppbrowser` exposes `getLastOpenPage` and `invokeAction`; the accepted `invokeAction` payload is not yet established. The next implementation must be based on the live Kindle diagnostic, not a guessed command.

## Logs

- `/mnt/us/documents/RR-JS-Smoke-Test.log`
- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/RoyalRoadTools-launch.log`
- `/mnt/us/documents/RoyalRoadTools-bookmark.log`
- `/mnt/us/documents/RoyalRoadTools.log`
- `/mnt/us/documents/RoyalRoadTools-package.log`
- `/mnt/us/documents/RoyalRoadTools-install.log`

## Safety and current limits

No browser database, bookmark, root filesystem file, cookie, credential, or browser setting is changed by **RR-JS-Smoke-Test**. It is only a diagnostic; full chapter collection and EPUB creation have not been implemented.
