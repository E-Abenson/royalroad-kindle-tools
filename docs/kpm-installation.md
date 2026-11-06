# Kindle installation

The KPM package currently contains a **native-browser injection diagnostic**, not a story downloader or EPUB builder.

## Install / update using KPM

If the repository is already registered, open **KPM-Update-All** in the Kindle library to refresh the package index and upgrade installed KPM packages. Output is shown live and saved to `/mnt/us/documents/KPM-Update-All.log`.

For initial installation, open the one-time `Install-RoyalRoadTools` scriptlet. It registers the repository, refreshes its package index and installs the package. Its log is `/mnt/us/documents/RoyalRoadTools-install.log`.

## Run the native browser injection test

1. Open a Royal Road chapter in the Kindle's built-in browser.
2. Leave the chapter as the browser's last-open page.
3. Return to the Kindle Home screen.
4. Open **RR-JS-Smoke-Test** from the Kindle library.
5. Return to the browser and look for a white label reading **RR JS INJECTED VIA LIPC**.

The script reads the last-open page URL through LIPC, focuses the native browser and sends a tiny JavaScript URL through `com.lab126.browser gotoURL`. The label is the proof that injection worked; a successful shell command alone is not proof. Reloading the page removes the label.

The test also checks a few localhost Chromium DevTools ports and the browser process command line. These checks do not enable remote debugging or change browser launch arguments.

## Logs

- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/RR-JS-Smoke-Test.log`
- `/mnt/us/documents/RoyalRoadTools-launch.log`
- `/mnt/us/documents/RoyalRoadTools-bookmark.log`
- `/mnt/us/documents/RoyalRoadTools.log`
- `/mnt/us/documents/RoyalRoadTools-package.log`
- `/mnt/us/documents/RoyalRoadTools-install.log`

## Safety and current limits

The native injection test does not use a bookmarklet, alter the browser database, read chapter text, cookies, credentials, authorization headers or browser history, modify rootfs, or bypass Cloudflare controls. It is only a diagnostic: full chapter collection and EPUB creation have not been implemented yet.
