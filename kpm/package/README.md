# Royal Road Kindle Tools — KPM package

This package currently contains a **read-only browser LIPC diagnostic**, not a story downloader or EPUB builder.

## Kindle library items

- **RR-JS-Smoke-Test** — records safe browser settings and inventories the browser-related LIPC property names/type/access metadata. It deliberately does not navigate, launch, refresh, or inject into the browser.
- **RR-Upload-Diagnostic** — manually uploads a redacted copy of the latest LIPC diagnostic log to a temporary paste link. It does not need a GitHub credential.
- **RoyalRoadTools** — the older bookmark setup/repair launcher, retained for the earlier bookmark test.
- **KPM-Update-All** — refreshes package repositories and upgrades installed packages.
- **KindleBatchPrepareFix** — installs a backed-up, validated menu-registration fix for the separate Kindle Batch Preparation KOReader add-on.
- **KindleBatchPrepareDiagnostics** — gathers the separate KOReader add-on diagnostics.

## Upload the diagnostic without a USB cable

1. Run **RR-JS-Smoke-Test** first.
2. Return to the Kindle library and open **RR-Upload-Diagnostic**.
3. The script uploads only `/mnt/us/documents/RR-JS-Smoke-Test.log` to paste.rs, after redacting the Royal Road story/chapter path.
4. It displays a short `https://paste.rs/...` link and saves it to `/mnt/us/documents/RR-JS-Smoke-Test-upload-url.txt`.
5. Send that link in the chat. The diagnostic can then be copied into this GitHub repository.

The paste link is **not private**: anyone who has the link can read it. The upload is not automatic; it occurs only when you open **RR-Upload-Diagnostic**. No GitHub token or other credential is stored on the Kindle or in this public repository. After the log has been copied into GitHub, the temporary paste should be deleted.

The uploader refuses logs larger than 64 KiB and stops if it detects credential-like strings. Its own log is `/mnt/us/documents/RR-Upload-Diagnostic.log`.

## Install the Kindle Batch Preparation menu fix

1. Run **KPM-Update-All** from the Kindle library to refresh repositories and upgrade the package.
2. Open **KindleBatchPrepareFix** from the Kindle library.
3. The script downloads the replacement from this repository, validates it, backs up the existing add-on `main.lua`, then atomically replaces it.
4. Restart KOReader and look under **Tools → Kindle batch preparation**.

The installer log is saved to `/mnt/us/documents/KindleBatchPrepareFix.log`. The timestamped backup remains beside the add-on's `main.lua` file in `/mnt/us/koreader/plugins/kindle_batch_prepare.koplugin/`.

## Run the detailed read-only diagnostic

1. Open a Royal Road chapter in the Kindle's built-in browser.
2. Let it finish loading. Do not refresh during the test.
3. Return to the Kindle Home screen.
4. Open **RR-JS-Smoke-Test** from the Kindle library.
5. Read the on-screen output, or use **RR-Upload-Diagnostic** to send a redacted copy without a cable.

The diagnostic:
- checks which Kindle application is in the foreground;
- reads the last-open browser URL with query parameters and fragments removed;
- reads only the browser's `getAllSettings` value and reports whether JavaScript and images are enabled;
- probes only `com.lab126.kppbrowser` and `com.lab126.browser`;
- prints property names and type/access metadata, never the property Value column;
- reports whether `invokeAction` is registered and whether its metadata shows it as writable;
- checks whether the browser already has a remote-debugging port flag.

The log is cleared at the beginning of each diagnostic run, so it contains only the latest results.

## Why injection is not enabled yet

The earlier experimental script tried `com.lab126.browser gotoURL`, but that property was not verified on the device and the page stopped loading during the test. The current diagnostic does not send any browser action. Public LIPC inventories show `com.lab126.kppbrowser` exposes `getLastOpenPage` and `invokeAction`; the accepted `invokeAction` payload is not yet established. We will not guess the arguments or send a test action until its contract is known.

## Logs

- `/mnt/us/documents/RR-JS-Smoke-Test.log`
- `/mnt/us/documents/RR-JS-Smoke-Test-upload-url.txt`
- `/mnt/us/documents/RR-Upload-Diagnostic.log`
- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/KindleBatchPrepareFix.log`
- `/mnt/us/documents/KindleBatchPrepareDiagnostics.log`
- `/mnt/us/documents/RoyalRoadTools-launch.log`
- `/mnt/us/documents/RoyalRoadTools-bookmark.log`
- `/mnt/us/documents/RoyalRoadTools.log`
- `/mnt/us/documents/RoyalRoadTools-package.log`
- `/mnt/us/documents/RoyalRoadTools-install.log`

## Safety and current limits

No browser database, bookmark, root filesystem file, cookie, credential, or browser setting is changed by **RR-JS-Smoke-Test**. The uploader redacts the story path and sends only the diagnostic log, but the resulting paste is readable by anyone with the link. The package is only diagnostic; full chapter collection and EPUB creation have not been implemented.
