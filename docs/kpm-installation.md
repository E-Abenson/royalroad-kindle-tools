# Kindle installation and maintenance

## Update

Open **KPM-Update-All** from the Kindle library. It refreshes the configured package repositories and upgrades installed KPM packages. Its current run is saved in `/mnt/us/documents/KPM-Update-All.log`.

## Clean up completed experiments

After installing the cleanup release, open **RoyalRoadTools-Cleanup** once from the Kindle library. It removes the old RR-JS-Smoke-Test and RR-LIPC-Metadata-Check launchers, their obsolete uploader, old Royal Road bookmarklet source/helpers, the old KOReader diagnostics launcher, their old logs and local upload/deletion links, and the old Royal Road Session Test bookmark previously installed by this project. It first backs up the browser database and verifies the exact title/type match before deleting. It also tries to delete the old pasters.io paste if its saved deletion URL is available.

The cleanup deliberately keeps **RR-KPP-Bundle-Scan** and its uploader because that investigation is not finished. It also keeps **KPM-Update-All**, **KindleBatchPrepareFix**, and the installed KOReader plugin.

## Version report

Open **RoyalRoadTools-Version-Info**. It writes and displays `/mnt/us/documents/Kindle-Version-Report.txt`. The report includes Kindle model/firmware, KPM CLI/library and installed package versions, KOReader revision when available, the Kindle Batch Preparation plugin metadata version and `main.lua` checksum, the bundled repair-source checksum, and the KPP application executable fingerprint.

Open the report again after each KPM or KOReader update. It is refreshed on demand, not automatically.

## Kindle Batch Preparation repair

Keep **KindleBatchPrepareFix** installed. It is an on-demand repair/reinstall utility, not a background service. Use it only if the separate Kindle Batch Preparation plugin disappears, fails to load, or needs the validated menu fix reapplied. It uses the locally bundled source so no manual file copying or network download is needed. Restart KOReader after a successful repair.

## Remaining KPP test

Open **RR-KPP-Bundle-Scan**, then **RR-Upload-Bundle-Scan**, to share the filtered static scan of the KPP application code. The scan does not execute code, navigate the browser, or send an `invokeAction` request.

## Active logs

- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/KindleBatchPrepareFix.log`
- `/mnt/us/documents/RR-KPP-Bundle-Scan.log`
- `/mnt/us/documents/RR-Upload-Bundle-Scan.log`

Each active script clears its own log at the start of a run. Obsolete experiment logs are removed by the cleanup launcher.
