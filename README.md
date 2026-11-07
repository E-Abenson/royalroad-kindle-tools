# Royal Road Kindle Tools

An experimental KPM toolkit for investigating whether the jailbroken Kindle's built-in browser can be controlled locally to retrieve Royal Road pages and eventually build a single offline EPUB.

## Device and confirmed findings

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware: 5.18.1.1.1 (hard-float firmware family).
- SpringBoard jailbreak completed.
- Kindle Package Manager works.
- The built-in browser can open Royal Road chapters.
- Direct `curl` from the Kindle received HTTP 403 with Cloudflare challenge markers.
- KPP browser LIPC exposes `com.lab126.kppbrowser.getLastOpenPage`.
- The browser database bookmark table was inspected previously, but the current LIPC diagnostic does not modify it.

## What's in the repository

- KPM package source in `kpm/package/`.
- A read-only LIPC diagnostic scriptlet (**RR-JS-Smoke-Test**) that records the active app, current page without query parameters, safe browser settings, and browser-related LIPC property names/type/access metadata.
- Existing bookmark setup/repair helpers, retained for the earlier bookmark test.
- A one-run bootstrap scriptlet in `install/Install-RoyalRoadTools.sh`.
- A GitHub Actions workflow that builds the KPM package, publishes a versioned GitHub Release, and updates the static KPM repository manifest.

See [Kindle installation](docs/kpm-installation.md), [architecture and staged test plan](docs/architecture-and-test-plan.md), and [package README](kpm/package/README.md).

## Install / update

The KPM repository is already configured on the Kindle. Open **KPM-Update-All** in the Kindle library to refresh the package index and upgrade installed packages. Then open **RR-JS-Smoke-Test**.

For a first-time setup, the latest release includes `Install-RoyalRoadTools.sh`. The scriptlet registers this KPM repository, refreshes its index, and installs the package.

## Current status

The previous diagnostic attempted to send JavaScript through an unverified `com.lab126.browser gotoURL` property. The user observed that the browser page stopped loading during this attempt. That approach has been withdrawn.

The current **RR-JS-Smoke-Test** is deliberately read-only. It queries only `com.lab126.kppbrowser` and `com.lab126.browser`, emits property names and type/access metadata, discards property values, checks the safe JavaScript/image settings, and looks for an already-enabled remote-debugging flag. It clears its own log at the start of each run. It does not launch, focus, navigate, refresh, or inject into the browser, and it does not send an `invokeAction` payload.

The next step is to use the live Kindle results to establish the accepted `invokeAction` contract from reliable local/firmware evidence before attempting any browser action again.

The package does not yet collect full stories, transfer chapter data, or create EPUBs. It will stop on access-denial or Cloudflare challenge responses and will not bypass CAPTCHAs or other access controls.

## Keep the existing EPUB project separate

Nothing in this repository modifies the existing Apps Script downloader or EPUB builder. A future local Kindle collector/EPUB adapter will remain separate until ordinary browser retrieval has been demonstrated to work reliably.
