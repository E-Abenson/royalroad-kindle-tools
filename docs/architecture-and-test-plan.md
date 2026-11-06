# Architecture and staged test plan

## Goal

Use the Kindle's own built-in browser session to retrieve Royal Road pages that the user can open normally, validate that every chapter is complete, and eventually build one offline EPUB. Avoid manual chapter-by-chapter copying.

## Confirmed device facts

- Kindle: 10th generation; exact model variant not yet identified.
- Firmware: 5.18.1.1.1 (hard-float family).
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A separate Kindle `curl` request to a Royal Road chapter returned HTTP 403 with Cloudflare challenge markers.
- `com.lab126.kppbrowser.getLastOpenPage` is available through LIPC.
- A public LIPC inventory lists `com.lab126.kppbrowser` properties including `getLastOpenPage` and `invokeAction`, but does not list `gotoURL` on that service.

## Current package state

The repository includes a KPM package targeting `kindlehf`. It installs Kindle library scriptlets and uses a GitHub Actions workflow to build a versioned `.kpkg`, publish a GitHub Release, and update `kpm-repo/manifest.json`.

**RR-JS-Smoke-Test is currently read-only.** It:
- reads the active app;
- reads the browser's last-open page, omitting query parameters from its log;
- probes only `com.lab126.kppbrowser` and `com.lab126.browser`;
- prints property names/access types without verbose values;
- checks process command lines for an already-enabled remote-debugging flag.

It does not launch, focus, navigate, refresh, or inject into the browser. It does not dump the full LIPC registry, which can contain unrelated account/session properties.

## Why the previous injection attempt was withdrawn

The earlier test read the last page from `com.lab126.kppbrowser`, launched the browser, and attempted to send a JavaScript URL through `com.lab126.browser gotoURL`. The user reported that this interrupted page loading. The property was not verified against the device's actual LIPC registry. Do not repeat this call or guess the payload for `invokeAction`.

The next step is to inspect the log from **RR-JS-Smoke-Test** and identify the exact browser service and writable navigation/action properties registered on this firmware. Only after the action contract is established should we build a reversible one-line injection test.

## Stage 1: establish a verified browser-control channel

1. Run the read-only diagnostic while a Royal Road chapter has fully loaded.
2. Inspect the two browser-related LIPC services exposed on the actual Kindle.
3. Establish the accepted payload for a supported action from local evidence or firmware source.
4. Test a harmless visual label without changing the current URL or reloading the page.
5. Confirm that the label appears and can be removed by a normal reload.

Do not use bookmarklets as the control mechanism; the user already reported that bookmarklet JavaScript did not work.

## Stage 2: test ordinary chapter retrieval

Only after the injection/control channel is verified:
- read the chapter content already rendered in the browser;
- check whether normal same-origin requests return complete pages;
- use a very small number of sequential requests;
- stop immediately on a challenge, access denial, unexpected redirect, or malformed/incomplete page.

Do not retry around a challenge or attempt CAPTCHA/proof-of-work bypasses.

## Stage 3: build the local collector and EPUB

Only after Stage 2 proves reliable:
- discover the chapter list from ordinary accessible story-page data;
- retain chapter order and canonical URLs;
- collect chapters conservatively and save progress locally;
- validate non-empty content, expected chapter markers, and completeness;
- report failures rather than silently producing partial books;
- package a single EPUB with titles, metadata, formatting, and images where available.

The existing Apps Script receiver URL and authentication are not configured in this repository. Do not commit private endpoints, secrets, chapter text, or session data. Keep the existing EPUB builder untouched.

## Security and reversibility

- Never read, print, copy, or transmit cookies, credentials, authorization headers, or private browser storage.
- Do not dump the entire verbose LIPC registry; it may contain unrelated account/session properties.
- Do not write to rootfs or remount the system read-write.
- Stop on Cloudflare challenges and respect the site's access controls and rate limits.
