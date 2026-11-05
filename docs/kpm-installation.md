# Kindle installation

This package is currently a diagnostic-only project; it does not yet download a story or create an EPUB.

## Kindle-screen progress

The library scriptlets display progress on the Kindle screen using the jailbreak's shell integration. Their output is also mirrored into log files. They should no longer redirect all output away from the display.

## Install / update using KPM

If the repository is already registered, open **KPM-Update-All** in the Kindle library to refresh the package index and upgrade installed KPM packages. Output is shown live and saved to `/mnt/us/documents/KPM-Update-All.log`.

For the initial installation, open the one-time `Install-RoyalRoadTools` scriptlet. It displays repository registration, package-index refresh and installation output. Its log is `/mnt/us/documents/RoyalRoadTools-install.log`.

## Available Kindle library items

- **KPM-Update-All** — refreshes repositories and upgrades installed packages.
- **RoyalRoadTools** — restores/installs the real chapter diagnostic bookmark and displays each setup stage.
- **RR-JS-Smoke-Test** — temporarily installs the plain-text JavaScript bookmark test and displays each setup stage.

## Restore the full diagnostic

Open **RoyalRoadTools** from the Kindle library. It restores the full chapter-session diagnostic bookmarklet. It backs up the database before changing only that test bookmark.

## Logs

- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/RoyalRoadTools-launch.log`
- `/mnt/us/documents/RoyalRoadTools-bookmark.log`
- `/mnt/us/documents/RoyalRoadTools.log`
- `/mnt/us/documents/RoyalRoadTools-package.log`
- `/mnt/us/documents/RR-JS-Smoke-Test.log`
- `/mnt/us/documents/RoyalRoadTools-install.log`

## Removal

Run `;kpm uninstall royalroad-kindle-tools`. Existing backup and log files are retained.
