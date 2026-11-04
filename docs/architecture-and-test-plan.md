# Architecture and staged test plan

## Intended workflow

1. The Kindle user opens a Royal Road story in the Kindle's own browser.
2. A small launcher invokes a browser-side test/collector.
3. Browser-side same-origin requests use the browser's normal session, if the site permits them.
4. The collector walks the chapter list, retrieves chapter HTML, preserves order, and validates every chapter.
5. A package is transferred to a separate receiving endpoint.
6. The existing EPUB builder imports the package through a separate adapter; the current downloader remains untouched.

## What is known

- The Kindle browser opens Royal Road.
- The Kindle's separate `curl` client receives HTTP 403 and a Cloudflare challenge page.
- The KPP browser LIPC service exposes `getLastOpenPage` and `getAllSettings`.
- The browser reports JavaScript enabled.
- `/var/local/KPPBrowser.db` has a `bookmark` table with `title`, `url`, and `created_dt` columns.
- Browser-related processes observed included `webreader` and `mesquite`.

## What is not yet proven

- Whether JavaScript bookmark URLs are accepted by this Kindle browser.
- Whether a bookmarklet can make a same-origin `fetch()` request to the current chapter.
- Whether the returned document contains the complete chapter, rather than a challenge or partial response.
- Whether browser-side JavaScript can reliably enumerate all chapter links.
- Whether long-running JavaScript and large downloads are practical on this Kindle.
- The correct, secure upload mechanism to the user's Drive/Apps Script workflow.

## Next experiment: browser-side same-origin fetch

Use a bookmarklet only after installing it through a reversible method. On the already-open Royal Road chapter it should:

- Confirm the page origin and current URL.
- Measure the visible chapter text length.
- Fetch the current URL again with `credentials: "include"`.
- Parse the returned HTML in memory.
- Report only HTTP status, response byte/character count, whether challenge markers exist, and extracted chapter text length.
- Display a short result on-screen.
- Never send chapter text, cookies, headers, or browser storage to any server.

A positive result is not yet proof that every chapter can be retrieved. It only justifies a second test against a small, known chapter list.

## Security constraints

- Never copy or upload Kindle browser cookie databases.
- Never print cookie values or authorization headers.
- Do not put GitHub tokens or Google credentials on the Kindle.
- Do not commit chapter content or diagnostic reports.
- Do not attempt to bypass CAPTCHA, proof-of-work, or other access controls. If Royal Road presents a challenge, stop and use the site's permitted access route.
- All database edits must create a timestamped backup first and provide a rollback instruction.

## Delivery design (not implemented yet)

The preferred delivery model is a small KPM package hosted through a static KPM repository or release assets. A GitHub Actions workflow can build and publish the package. The Kindle should pull updates, not accept inbound connections. A separate receiver should accept only completed story packages and should use a user-owned secret configured outside this public repository.
