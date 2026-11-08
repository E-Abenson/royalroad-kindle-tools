# Kindle installation

The KPM package currently contains a **read-only browser LIPC diagnostic** and a manual diagnostic-log uploader. It is not yet a story downloader or EPUB builder.

## Install / update using KPM

If the repository is already registered, open **KPM-Update-All** in the Kindle library to refresh the package index and upgrade installed KPM packages. Output is shown live and saved to `/mnt/us/documents/KPM-Update-All.log`.

For initial installation, open the one-time `Install-RoyalRoadTools` scriptlet. It registers the repository, refreshes KPM, and installs the package. Its log is `/mnt/us/documents/RoyalRoadTools-install.log`.

## Run the detailed read-only diagnostic

1. Open a Royal Road chapter in the Kindle's built-in browser.
2. Let it finish loading. Do not refresh during the test.
3. Return to the Kindle Home screen.
4. Open **RR-JS-Smoke-Test** from the Kindle library.

The script checks the foreground application, reads the last-open URL with query parameters removed, and reports the safe JavaScript/image settings. It probes only `com.lab126.kppbrowser` and `com.lab126.browser`, printing property names and type/access metadata while discarding values. It specifically reports whether `invokeAction` is registered and write-enabled. The log is cleared before each run.

The script does **not** navigate, refresh, inject JavaScript, modify bookmarks, read cookies, or access chapter text.

## Upload the log without a cable

1. After running the diagnostic, return to the Kindle library.
2. Open **RR-Upload-Diagnostic**.
3. The uploader creates a redacted temporary copy and posts it to paste.rs. It removes the Royal Road story/chapter path from the log.
4. The Kindle displays a short paste link. Send that link in the chat.
5. The diagnostic can then be retrieved and committed into the GitHub repository.

The paste URL is readable by anyone who has it; it is not a private upload. Uploading is a deliberate action and does not happen during KPM updates or diagnostic runs. The script uses no GitHub credentials and stores no token. After the repository copy is confirmed, the temporary paste should be deleted.

The uploader stores the resulting link at `/mnt/us/documents/RR-JS-Smoke-Test-upload-url.txt` and its own output at `/mnt/us/documents/RR-Upload-Diagnostic.log`.

## Other library utilities

- **KPM-Update-All** refreshes repositories and upgrades installed packages.
- **KindleBatchPrepareFix** installs the backed-up and validated KOReader menu fix. Restart KOReader after it reports success.
- **KindleBatchPrepareDiagnostics** gathers diagnostics for the separate KOReader add-on.
- **RoyalRoadTools** retains the earlier bookmark repair function.

## Logs

- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/RR-JS-Smoke-Test.log`
- `/mnt/us/documents/RR-JS-Smoke-Test-upload-url.txt`
- `/mnt/us/documents/RR-Upload-Diagnostic.log`
- `/mnt/us/documents/KindleBatchPrepareFix.log`
- `/mnt/us/documents/KindleBatchPrepareDiagnostics.log`
- `/mnt/us/documents/RoyalRoadTools-package.log`
- `/mnt/us/documents/RoyalRoadTools-install.log`

## Safety and current limits

The diagnostic does not change the browser database, bookmarks, root filesystem, cookies, credentials, or browser settings. The uploader shares only the diagnostic log after redacting the story path. The paste link is accessible to anyone who knows it. Full story collection and EPUB creation have not been implemented.
