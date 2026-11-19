# Kindle installation and maintenance

## Update All and automatic cleanup

Open **KPM-Update-All** from the Kindle library when you choose to refresh registered repositories and upgrade installed KPM packages.

After a successful package upgrade, the updater runs the private cleanup queue and regenerates the Kindle software version report. It no longer adds a screensaver repository or automatically installs the old Rabbinic screensaver assets.

The cleanup runner is stored privately at:

/mnt/us/documents/.royalroadtools/cleanup.sh

There is no separate **RoyalRoadTools-Cleanup** launcher. The installer merges new items into /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt; cleanup is run by Update All after the KPM upgrade succeeds.

## Current manual launchers

- **KPP-Native-Bridge-Export** — one manual read-only export of the running KPP executable and mapped ELF libraries.
- **KPP-JavaScript-Bundle-Export** — one manual read-only copy of /app/KPPMainApp/js/KPPMainApp.js.hbc into Documents. It checks the Hermes header, file-size limit, and SHA-256.
- **Inspect-USB-Screen** — read-only inspection of the separate stock USB-connection display; it is not a sleep-screensaver installer.
- **KPM-Update-All** — KPM repository refresh, package upgrade, cleanup, and version-report refresh.
- **KindleBatchPrepareFix** — manual repair/reinstall of the KOReader Kindle Batch Preparation plugin.

Each investigation or repair launcher remains manual; installation does not run it.

## JavaScript bundle test

1. Open the Kindle's built-in browser and leave it running.
2. Open **KPP-JavaScript-Bundle-Export** from the Kindle library.
3. Connect the Kindle to Windows over USB.
4. Copy KPPMainApp.js.hbc from Documents and attach it directly in ChatGPT, together with the existing native archive if requested.

There is no Windows analysis tool to install. The uploaded bundle is inspected in ChatGPT; the exporter does not run the bundle or upload it anywhere.

## Retired screensaver assets

The package no longer builds or installs the old Rabbinic/KOReader sleep-screen images. On the next successful Update All, cleanup removes only these exact known project-installed files:
- 01_Rav_Zvi_Kushelevsky.png
- 02_Rav_Osher_Arieli.png
- 03_Chofetz_Chaim.jpg
- SHA256SUMS

The image folder under /mnt/us/koreader-screensavers-inverted is removed only if empty. In /mnt/us/screensavers, only the two exact project-installed portrait filenames are removed. All other images and folders are preserved.

The cleanup does not uninstall the separate third-party Custom Screensaver KPM extension or remove its settings. It also does not delete the USB display inspection utility, because that utility examines a different screen.

## Version report

/mnt/us/documents/Kindle-Version-Report.txt is regenerated after successful package installation, Update All, and successful plugin repair. There is no manual version-report launcher.

## Active logs and reports

- KPP-Native-Bridge-Export.txt
- KPP-JavaScript-Bundle-Export.txt
- RoyalRoadTools-Cleanup.log
- KPM-Update-All.log
- KindleBatchPrepareFix.log
- Kindle-Version-Report.txt
- USB-Screen-Inspection.txt when the optional USB display inspection is run

Old diagnostic logs and launchers are removed by exact cleanup entries. The cleaner does not delete KOReader books, EPUBs, story files, browser data, or unrelated files.
