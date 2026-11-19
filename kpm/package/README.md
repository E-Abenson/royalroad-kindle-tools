# Royal Road Kindle Tools — KPM package

This package contains a small set of manual Kindle utilities and a private cleanup runner. It is not a Royal Road downloader or EPUB builder.

## Current Kindle launchers

- **KPP-Native-Bridge-Export** — one manual export of the running KPP executable and selected shared libraries mapped by KPPMainApp. It creates KPP-Native-Bridge-Binaries.tar.gz in Documents for USB transfer. It does not inspect page contents, read cookies, modify the app or upload binaries.
- **KPM-Update-All** — manually refreshes package repositories and upgrades installed packages. After a successful upgrade, it automatically runs the private cleanup helper and regenerates the version report.
- **Inspect-USB-Screen** — a one-run, read-only inventory of the stock USB-mode display assets. It records their metadata and PNG dimensions, saves the text report in Documents, and uploads that text report to Pasters.io with a one-day expiry. The paste link is shown on the Kindle and saved in Documents. If Pasters provides its per-paste deletion URL, that secret is stored separately in a hidden file with restricted permissions, never in the public report. A separate archive containing the actual image files remains local; those images are not uploaded.
- **Install-Rabbinic-Screensavers** — a separate manual launcher. It copies the two normal-grayscale portraits already installed by KPM in `/mnt/us/koreader-screensavers-inverted/` into `/mnt/us/screensavers/`. It verifies each source and staged copy against the KPM package's `SHA256SUMS`; no internet download is involved. It changes only those two named images.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the separate Kindle Batch Preparation KOReader plugin.
- **ScreenLockPin** — third-party KOReader PIN lock plugin (upstream v2026.10), installed automatically into `/mnt/us/koreader/plugins/screenlockpin.koplugin/` and updated with this KPM package.

The previous comprehensive diagnostic, last-open-page test and Hermes bytecode export are completed and retired. Their launchers, output files and package-cache copies are queued for removal by the automatic cleanup.

## USB display inspection

The USB-connected screen is rendered by the Kindle system USB display, separately from the sleep screensaver. The diagnostic copies the stock files under /usr/share/blanket/usb and records the device display information, image dimensions, permissions and checksums. It does not remount the root filesystem read-write, replace images, change permissions or restart Blanket.

1. Open **Inspect-USB-Screen** from the Kindle library.
2. It uploads the text report to Pasters.io and displays the share link when the upload is confirmed.
3. Paste that link into the ChatGPT conversation. The paste is readable by anyone with the link and is requested to expire after one day. Pasters.io may retain expired pastes for recovery for a further 21 days before purging them. If Pasters returns its per-paste deletion URL, the launcher stores it privately in a hidden Documents file with mode 600; it is not printed or uploaded.
4. The detailed text report is also saved as `USB-Screen-Inspection.txt`, and the paste link as `USB-Screen-Inspection-Paste.txt`, in Kindle Documents.

The optional archive `USB-Screen-Inspection.tar.gz` contains the actual USB display image files and stays local; the image files are not included in the Pasters.io upload. It may be needed later to inspect the image artwork itself. The diagnostic is manual; it does not run during KPM installation or updates. The existing Custom Screensaver package and images are left untouched.

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
from the Kindle library. It copies the two prepared Rav Zvi Kushelevsky and
Rav Osher Arieli portraits from the local KPM-installed folder
`/mnt/us/koreader-screensavers-inverted/` into `/mnt/us/screensavers/`.

The source folder has a historical `-inverted` name, but the current images
inside it are normal grayscale, not colour-inverted. The installer reads their
expected hashes from the package's `SHA256SUMS`, verifies each source, verifies
the staged copy, and then replaces only the two matching files in the standard
screensavers folder. No Wi-Fi or GitHub download is needed. Existing unrelated
screensaver images are preserved. The launcher remains manual and does not run
automatically during KPM installation.

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


## KOReader PIN lock — ScreenLockPin

This package includes [ScreenLockPin](https://github.com/oleasteo/koreader-screenlockpin),
upstream release **v2026.10**, under its MIT licence. KPM installs the plugin
code to:

`/mnt/us/koreader/plugins/screenlockpin.koplugin/`

The first time KOReader loads the plugin, follow its setup prompt and create a
3–12 digit PIN. When asked whether to enable weekly GitHub update checks, choose
**Disable Auto-Updates** so KPM remains the single update manager for this
bundled copy. New upstream plugin versions will be included in later KPM
releases.

Open **Screen → Lock screen** to manage the PIN and its options. Enable
**Lock on wakeup** to require the PIN after the Kindle wakes from sleep. The
upstream v2026.10 default also enables **Lock on boot**; leave it on if you want
a PIN whenever KOReader starts, or turn it off if you only want wake-from-sleep
locking.

On KPM upgrades, only the plugin program files are replaced. Your PIN and
preferences remain in KOReader's `settings.reader.lua`; they are not stored
inside the plugin folder. If you uninstall this KPM package, its marked
ScreenLockPin program folder is removed but the KOReader settings file is
left intact.

ScreenLockPin is intended for casual privacy, not cryptographic security. It
cannot prevent a forced device reboot or protect the Kindle when KOReader is
not in the foreground. It is separate from the Kindle's own Device Passcode.
