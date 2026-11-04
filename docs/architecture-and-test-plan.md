# Architecture and staged test plan

## Goal

Use the Kindle's own browser session to retrieve Royal Road pages, validate that every chapter is complete, and eventually hand a verified story package to a separate EPUB receiver. The workflow should not require copying chapters one by one.

## What is confirmed

- Kindle: 10th generation; exact KT4/PW4 variant not identified.
- Firmware: 5.18.1.1.1, which is in the hard-float firmware family.
- SpringBreak jailbreak completed; KPM works.
- Kindle browser opens Royal Road and reports JavaScript enabled.
- Separate Kindle curl request to a Royal Road chapter returned HTTP 403 with Cloudflare challenge markers.
- KPP browser LIPC can report the last open page.
- The browser database's bookmark table was previously inspected and has title, url, and created_dt columns.

## Current KPM package

The repository now contains a diagnostic-only KPM package targeting kindlehf. The install hook creates a Kindle library scriptlet. It attempts to add one browser bookmark using a helper that first backs up the browser database, checks the expected bookmark schema, inserts only one exact row, and verifies the insertion. The uninstall hook makes another backup and removes only that exact row.

A GitHub Actions workflow downloads the official KPM packager, builds a versioned .kpkg, publishes it as a GitHub Release, and updates kpm-repo/manifest.json. The repository manifest is served as a static raw GitHub file.

The bootstrap scriptlet calls the KPM executable directly to add the repository, update its index, and install the package. This avoids a known Kindle search-bar input-filter problem with URL punctuation.

## Stage 1: test one ordinary browser fetch

Open a chapter in the Kindle browser and select the installed Royal Road Session Test bookmark. It:
- measures the visible chapter text length;
- fetches only the current page using same-origin fetch with ordinary browser credentials;
- parses the returned HTML locally;
- reports status, response size, final origin, challenge markers, and returned chapter length.

It never sends chapter content, cookies, authorization headers, or browser storage anywhere.

A positive result is only a first signal. It does not prove that the chapter list is accessible or that large batches are safe.

## Stage 2: small chapter-list test (not yet built)

Only if Stage 1 succeeds, test a tiny set of chapter links already exposed by Royal Road's normal page. Requests must be sequential and conservative, and must stop immediately on a challenge, access denial, unexpected redirect, or malformed/incomplete page. Do not retry around a challenge and do not attempt CAPTCHA or proof-of-work bypasses.

## Stage 3: full collector (not yet built)

Only after the small test passes:
- discover the complete chapter list through ordinary accessible page content;
- retain chapter order and canonical URLs;
- fetch sequentially with conservative pacing;
- validate non-empty content, expected chapter markers, and stable response lengths;
- mark failures explicitly rather than silently creating partial books;
- package data locally and transfer it to a separate receiver.

The Apps Script receiving URL and its authentication design have not been configured in this repository. Do not put a secret, token, or private endpoint in public GitHub files. The existing downloader/EPUB builder must remain untouched; a future receiver adapter will be separate.

## Security and reversibility

- Never read, print, copy, or transmit browser cookies, credentials, authorization headers, or private browser storage.
- The diagnostic bookmarklet transmits nothing.
- The bookmark helper changes only the bookmark row and makes a timestamped local backup before each database write.
- No files are written to rootfs and no remount-rw operation is used.
- Stop on Cloudflare challenges and respect Royal Road's access controls and rate limits.
- Do not commit chapter text, user session data, or Apps Script secrets.
