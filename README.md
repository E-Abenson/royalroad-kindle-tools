# Royal Road Kindle Tools

A separate, experimental toolkit for using a jailbroken Kindle to retrieve Royal Road chapter content and hand it to an EPUB workflow.

## Current device and findings

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware: 5.18.1.1.1.
- SpringBreak jailbreak completed.
- Kindle Package Manager command `;kpm update` works.
- Kindle browser can open the target Royal Road chapter and reports JavaScript enabled.
- Direct `curl` request from Kindle returned HTTP 403 with Cloudflare challenge markers.
- Kindle browser LIPC reports `com.lab126.kppbrowser.getLastOpenPage`.
- Browser database schema at `/var/local/KPPBrowser.db` includes `bookmark(title,url,created_dt)`.

## Project goal

One launch should retrieve a complete story's chapter contents in order, validate that chapters are not truncated, and transfer a package to a separate receiver for EPUB production. No chapter-by-chapter copying.

## Safety and scope

- This repository is separate from the user's existing Royal Road/EPUB project.
- Never store browser cookies, credentials, account tokens, or private chapter downloads in this repository.
- Diagnostics must not print or upload cookie values, passwords, browser history rows, or page contents.
- Do not attempt to defeat or solve Cloudflare challenges. First test whether ordinary same-origin browser requests work in the user's already-open browser session.
- Do not modify the existing EPUB builder until a complete chapter retrieval test succeeds.
- Keep browser database changes backed up and reversible.

## Status

The first decisive result is that direct Kindle `curl` is challenged (HTTP 403). The next experiment is a harmless same-origin JavaScript test run inside the Royal Road page, measuring whether the page can read its displayed chapter and fetch the same URL using normal browser credentials. It must not transmit chapter text.

See [the architecture and test plan](docs/architecture-and-test-plan.md).
