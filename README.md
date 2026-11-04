# Royal Road Kindle Tools

A separate experimental toolkit for using a jailbroken Kindle to test whether the Kindle browser can retrieve Royal Road chapter pages through its ordinary browser session. The longer-term goal is a one-launch route to a verified story package and EPUB workflow, without manual chapter-by-chapter copying.

## Device and confirmed findings

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware: 5.18.1.1.1 (hard-float firmware family).
- SpringBreak jailbreak completed.
- Kindle Package Manager works; the user has run ;kpm update successfully.
- Kindle browser can open the target Royal Road chapter and reports JavaScript enabled.
- Direct curl from Kindle returned HTTP 403 with Cloudflare challenge markers.
- KPP browser LIPC reports getLastOpenPage.
- /var/local/KPPBrowser.db was inspected previously; its bookmark table has title, url, and created_dt columns.

## What's in the repository

- KPM package source in kpm/package/.
- A read-only same-origin browser diagnostic bookmarklet.
- Backup-first, verified insertion/removal helpers for exactly one bookmark row.
- A one-run bootstrap scriptlet in install/Install-RoyalRoadTools.sh.
- A GitHub Actions workflow that builds the KPM package, publishes a versioned GitHub Release (including the bootstrap scriptlet), and updates the static KPM repository manifest.

See [Kindle installation](docs/kpm-installation.md), [architecture and staged test plan](docs/architecture-and-test-plan.md), and [package README](kpm/package/README.md).

## One-time Kindle setup

Download Install-RoyalRoadTools.sh from the latest GitHub Release:
https://github.com/E-Abenson/royalroad-kindle-tools/releases/latest/download/Install-RoyalRoadTools.sh

Save the file in the Kindle documents folder and open it from the library. It adds this KPM repository, refreshes KPM, and installs royalroad-kindle-tools. The scriptlet calls the KPM executable directly rather than passing a URL through the Kindle search bar.

The installer attempts to add the Royal Road Session Test bookmark automatically. Before changing /var/local/KPPBrowser.db, it creates a timestamped local backup. The change is limited to one bookmark row. If the browser database is busy, open the RoyalRoadTools library item once to retry.

## Important boundary

The current package is **only a diagnostic**. It tests one chapter using an ordinary same-origin browser fetch and displays aggregate measurements. It does not yet collect full stories, transfer chapter data, or modify the existing Apps Script EPUB builder.

Direct Kindle curl was challenged by Cloudflare. We will only build the full collector if the browser's ordinary page fetch proves reliable. The project will not solve CAPTCHAs, forge browser credentials, or circumvent Cloudflare controls.

## Keep the existing EPUB project separate

Nothing in this repository modifies the existing Google Apps Script downloader or EPUB builder. Any future adapter will be separate and will only be considered after a complete chapter retrieval test succeeds.
