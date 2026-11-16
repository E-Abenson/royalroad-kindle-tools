# Royal Road Kindle Tools — KPM package

This package contains a small set of manual Kindle utilities and a private cleanup runner. It is not a Royal Road downloader or EPUB builder.

## Current Kindle launchers

- **KPP-Native-Bridge-Export** — one manual export of the running KPP executable and selected shared libraries mapped by KPPMainApp. It creates KPP-Native-Bridge-Binaries.tar.gz in Documents for USB transfer. It does not inspect page contents, read cookies, modify the app or upload binaries.
- **KPM-Update-All** — manually refreshes package repositories and upgrades installed packages. After a successful upgrade, it automatically runs the private cleanup helper and regenerates the version report.
- **Inspect-USB-Screen** — a one-run, read-only inventory of the stock USB-mode display assets. It copies the files in /usr/share/blanket/usb, records their metadata and PNG dimensions, and writes USB-Screen-Inspection.tar.gz to Documents. It does not modify the system.
- **Install-Rabbinic-Screensavers** — a separate manual launcher. When opened on the Kindle, it downloads two SHA256-verified grayscale portraits directly into /mnt/us/screensavers/. It does not run automatically during KPM installation and does not change any other images.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the separate Kindle Batch Preparation KOReader plugin.

The previous comprehensive diagnostic, last-open-page test and Hermes bytecode export are completed and retired. Their launchers, output files and package-cache copies are queued for removal by the automatic cleanup.

## USB display inspection

The USB-connected screen is rendered by the Kindle system USB display, separately from the sleep screensaver. The diagnostic copies the stock files under /usr/share/blanket/usb and records the device display information, image dimensions, permissions and checksums. It does not remount the root filesystem read-write, replace images, change permissions or restart Blanket.

1. Open **Inspect-USB-Screen** from the Kindle library.
2. It creates **USB-Screen-Inspection.tar.gz** in Kindle Documents.
3. Connect the Kindle to the PC and copy that archive from Documents.
4. Attach the archive in the ChatGPT conversation so the exact background and overlay assets can be checked before designing any replacement.

The diagnostic is manual; it does not run during KPM installation or updates. The existing Custom Screensaver package and images are left untouched.

## Native browser bridge inspection

This is the next step after the already-completed Hermes disassembly and the successful getLastOpenPage URL test.

1. Open the Kindle's built-in browser and leave it open.
2. Launch **KPP-Native-Bridge-Export** once.
3. It creates KPP-Native-Bridge-Binaries.tar.gz in Kindle Documents. The archive contains unchanged copies of /app/bin/KPPMainAppV2 and selected shared libraries mapped by the running KPPMainApp process. It also writes KPP-Native-Bridge-Export.txt with counts and the archive checksum.
4. Copy the archive to Windows over USB.
5. Extract KPP-Native-Bridge-Inspector-Windows.zip from the matching GitHub release into the same folder.
6. Drag KPP-Native-Bridge-Binaries.tar.gz onto Run-KPP-Native-Inspection.bat.

The Windows helper uses Python 3.8+ already installed. It needs no pip packages, compiler, administrator rights or system-wide installation. It reads ELF headers, symbol tables and selected embedded strings, and writes KPP-Native-Bridge-Findings.txt next to the archive.

**This is fully offline.** The helper does not contact Pasters.io or any other service and does not upload the archive, binaries, findings or any other file. When it finishes, attach KPP-Native-Bridge-Findings.txt directly in the ChatGPT conversation.

The report excludes page URLs, absolute device paths, email addresses, cookies, session/authentication markers, account identifiers and runtime browser data. It reports ELF metadata and selected native browser/bridge markers. A marker string or symbol is a lead, not proof that an external interface is callable or that its arguments are known.

## Automatic cleanup

There is no separate cleanup launcher. The cleaner is stored privately at /mnt/us/documents/.royalroadtools/cleanup.sh and runs automatically when **KPM-Update-All** completes a successful package upgrade.

The installer merges the queue template into /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt; it does not execute cleanup itself. Before cleanup, existing retired targets are re-queued only if they actually exist, even when an older completion ledger says they were removed. Successful actions are removed from the pending queue and recorded in RoyalRoadTools-Cleanup-Completed.txt. Failed or unverifiable actions remain queued for the next Update All run.

Remote Pasters deletion is attempted only for old retired diagnostic pastes when a private delete URL was saved. The new native-inspection helper does not create pastes or delete URLs.

## Safety and limits

The export reads only the running KPP executable and selected mapped shared libraries. It does not read browser memory, cookies, history, current page text, page source or JavaScript state. It does not send LIPC writes, events or invokeAction messages. It does not alter the KPP application. The archive and findings report stay on the user's PC.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA/proof-of-work bypasses or other access-control circumvention. Full chapter collection and EPUB creation have not been implemented.


## Rabbinic screensavers

After installing/upgrading this KPM package, open **Install-Rabbinic-Screensavers**
from the Kindle library. It downloads the prepared Rav Zvi Kushelevsky and
Rav Osher Arieli portraits directly to /mnt/us/screensavers/, checks each
file against a pinned SHA256 digest, tries three GitHub download routes and
falls back from curl to wget. Detailed errors are saved to
/mnt/us/documents/Install-Rabbinic-Screensavers.log. It atomically replaces only those two
named files. Existing unrelated screensaver images are preserved. No USB
transfer or Windows-side download is required.

The images are 1072x1448 PNGs in 8-bit grayscale, adjusted for e-ink contrast.
The Custom Screensaver Scriptlet remains responsible for enabling/rotating
screensavers.



## KOReader custom sleep-screen images

The KPM package automatically installs three normal-grayscale images to:

`/mnt/us/koreader-screensavers-inverted/`

The images are normal (not colour-inverted):

- `01_Rav_Zvi_Kushelevsky.png`
- `02_Rav_Osher_Arieli.png`
- `03_Chofetz_Chaim.jpg`

The folder keeps its historical `-inverted` name solely so an existing KOReader custom-screensaver folder selection continues to work. The image files themselves are now normal grayscale photographs, suitable for a sleep screen that does not invert colours.

During a KPM update, the installer verifies all three SHA256 checksums before replacing the three named files. Other files in the folder are preserved. It does not touch `/mnt/us/screensavers/` or the normal Kindle Custom Screensaver collection.

No KOReader setting change is needed when the folder was already selected.
