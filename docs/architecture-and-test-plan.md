# Architecture and staged test plan

## Goal

Investigate the Kindle's own built-in KPP browser without changing the application, reading process memory, or bypassing site access controls. The longer-term goal is an offline EPUB only from pages that can be accessed normally. This project is not yet a story downloader.

## Confirmed device facts

- Kindle firmware last reported: 5.18.1.1.1.
- The built-in browser can open Royal Road chapters.
- A separate direct Kindle request received HTTP 403 with Cloudflare challenge markers.
- The browser service has read-only getLastOpenPage and getAllSettings properties and a write-only invokeAction property.
- The accepted invokeAction format remains unknown. No payload has been sent.

## Completed native inspection

The 2026-11-18 native archive contained 128 ELF files. The static analysis identified native browser data-provider methods for history, bookmarks, and URL navigation, together with getter-only LIPC properties for a history record and browser settings.

The React Native library imports a WebKit script helper that returns an integer and contains scroll-related scripts for an embedded bodySection. It does not import the WebKit DOM-reading functions examined in the report. General DOM APIs exported by the separate WebKit library do not establish that the browser app exposes them through a supported external interface.

No ready-made, supported read-only LIPC property returning the current page's text or HTML was identified. Function names alone do not establish that an API is externally callable or safe to invoke.

## Current next stage — correlate the JavaScript bundle

The previous Hermes bundle was exported and disassembled on 2026-11-13. Its report identified NativeModules, BrowserDataProvider, navigation functions, and a call to BrowserDataProvider.loadURL; that method is navigation, not page reading. A fresh bundle is warranted so the JavaScript code can be matched to the newer native binaries.

1. Open the Kindle's built-in browser and leave KPP running.
2. Run **KPP-JavaScript-Bundle-Export** once. It copies only /app/KPPMainApp/js/KPPMainApp.js.hbc to Documents, validates the Hermes magic, verifies SHA-256, and records the bytecode version.
3. Copy KPPMainApp.js.hbc to the computer over USB and attach it directly in ChatGPT.
4. The bundle is inspected offline here and correlated with the 2026-11-18 native findings. There is no Windows helper, local Python dependency, disassembler, or upload service.

The existing **KPP-Native-Bridge-Export** remains the one-time source for native ELF binaries. The new JavaScript exporter does not repeat that export.

## Safety and access limits

- Do not write LIPC properties or send events during static inspection.
- Do not send guessed values to com.lab126.kppbrowser.invokeAction.
- Do not inspect process memory, cookies, authenticated storage, or runtime browser history.
- Do not collect or extract live page text in this investigation.
- Stop on access-denial, Cloudflare challenge, unexpected redirect, or incomplete page.
- Do not attempt CAPTCHA/proof-of-work or other access-control circumvention.

## Future stages

1. Review the uploaded JavaScript bundle's native-module registrations and call sites.
2. Correlate any candidate with the native implementation and its documented read-only semantics.
3. Only if a supported read-only method is established, define a minimal metadata-only test. Do not guess an invokeAction schema.
4. If no such interface exists, stop the native LIPC approach and evaluate ordinary browser-supported export options.
5. Only after reliable ordinary retrieval is established, consider a local collector and validate EPUB completeness.

## Cleanup and versions

There is no separate cleanup launcher. The runner is private at /mnt/us/documents/.royalroadtools/cleanup.sh and is called automatically by KPM-Update-All after a successful package upgrade.

The installer merges the cleanup template into Documents. Each action is narrow and explicit; image cleanup is limited to the exact legacy project-managed filenames. A folder is removed only with rmdir after those files are removed and only if the directory is empty. Other Custom Screensaver files, user images, books, EPUBs, browser data, and unrelated files are left alone.

Kindle-Version-Report.txt is regenerated after successful Update All and successful plugin repair.
