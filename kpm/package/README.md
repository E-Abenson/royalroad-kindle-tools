# Royal Road Kindle Tools — KPM package

This package currently contains a **native-browser injection diagnostic**, not a story downloader or EPUB builder.

## Kindle library items

- **RR-JS-Smoke-Test** — tests whether a shell script can send JavaScript to the built-in Kindle browser through its LIPC `gotoURL` property. It does not use a bookmarklet.
- **RoyalRoadTools** — the older bookmark setup/repair launcher. The LIPC smoke test does not depend on that bookmark.
- **KPM-Update-All** — refreshes package repositories and upgrades installed packages.

## Run the native browser test

1. Open a Royal Road chapter in the Kindle's built-in browser.
2. Leave that chapter as the browser's last-open page.
3. Return to the Kindle Home screen.
4. Open **RR-JS-Smoke-Test** from the Kindle library.
5. The script reads the last-open page URL through LIPC, focuses the native browser, and sends a small JavaScript URL through `com.lab126.browser gotoURL`.
6. Return to the browser and look for a white label reading **RR JS INJECTED VIA LIPC**.

If the label appears, shell-to-page JavaScript injection worked without a bookmarklet. Reloading the chapter removes the label. A successful `lipc-set-prop` exit status alone is not proof; the visible label is the test result.

The script also checks a few localhost Chromium DevTools ports and looks for an existing `--remote-debugging-port` process flag. These are read-only checks. The script does not enable remote debugging or change browser launch arguments.

## Logs

The diagnostic log is saved to:

`/mnt/us/documents/RR-JS-Smoke-Test.log`

It records the current page host/path and command/diagnostic results. It does not record chapter text, cookies, credentials, authorization headers, or browser history.

## Safety

- No browser database or bookmark is modified by **RR-JS-Smoke-Test**.
- No root filesystem files are changed and no remount is performed.
- The injected label is temporary and disappears on reload.
- The test does not bypass Cloudflare or retry around challenges.
- This is a compatibility probe; it does not yet collect chapters or create EPUBs.

## Update and removal

Open **KPM-Update-All** in the Kindle library to refresh repositories and upgrade installed KPM packages.

Run `;kpm uninstall royalroad-kindle-tools` to remove the package. Existing diagnostic logs and backups are retained.
