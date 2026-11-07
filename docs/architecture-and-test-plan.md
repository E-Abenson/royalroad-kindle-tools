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
- The user's diagnostic confirmed `com.lab126.kppbrowser.invokeAction` exists. Its accepted payload is still unknown.
- A public LIPC inventory lists browser properties such as `getAllSettings`, `getLastOpenPage`, and `invokeAction`. It does not establish the accepted arguments for `invokeAction`.

## Current package state

The repository includes a KPM package targeting `kindlehf`. It installs Kindle library scriptlets and uses a GitHub Actions workflow to build a versioned `.kpkg`, publish a GitHub Release, and update `kpm-repo/manifest.json`.

**RR-JS-Smoke-Test is a detailed, read-only diagnostic.** It:
- clears its log at the beginning of each run;
- reads the active app;
- reads the browser's last-open page, omitting query parameters and fragments;
- reads the safe JavaScript/image settings from `getAllSettings`;
- probes only `com.lab126.kppbrowser` and `com.lab126.browser`;
- reports property names and type/access metadata, discarding values;
- checks process command lines for an already-enabled remote-debugging flag.

It does not launch, focus, navigate, refresh, or inject into the browser. It does not dump the full verbose LIPC registry, which can contain unrelated account/session properties.

## Why the previous injection attempt was withdrawn

The earlier test read the last page from `com.lab126.kppbrowser`, launched the browser, and attempted to send a JavaScript URL through `com.lab126.browser gotoURL`. The user reported that this interrupted page loading. The property was not verified against the device's actual LIPC registry. Do not repeat this call or guess the payload for `invokeAction`.

The latest detailed test is intended to report the exact browser-related property names and their type/access metadata on the user's firmware. It does not test or invoke `invokeAction`. Once the metadata is available, research its accepted action payload using reliable firmware/source evidence before attempting any browser action.

## Stage 1: establish a verified browser-control channel

1. Run the detailed read-only diagnostic while a Royal Road chapter has fully loaded.
2. Inspect the reported `com.lab126.kppbrowser` property names and access metadata.
3. Establish the accepted payload for a supported action from local evidence or firmware source.
4. Only then build a reversible test that does not change the current URL or reload the page.
5. Confirm the harmless visual result in the browser.

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
