/*
 * Royal Road Kindle Tools — browser-side session diagnostic
 *
 * Run this only while viewing a Royal Road chapter page.
 * It makes one same-origin request to the current URL and displays
 * aggregate diagnostics only. It does not transmit or save chapter text,
 * cookies, headers, or browser storage.
 */
(async function royalRoadSessionDiagnostic() {
  const currentUrl = window.location.href;
  const isRoyalRoad = window.location.hostname === "www.royalroad.com";
  if (!isRoyalRoad || !/\/chapter\//.test(window.location.pathname)) {
    window.alert("Open a Royal Road chapter page first.");
    return;
  }

  const visibleText = document.querySelector(".chapter-content")?.innerText || "";
  const challengePattern = /cf-chl-|cloudflare|just a moment|verify you are human/i;

  const lines = [
    "ROYAL ROAD BROWSER TEST",
    "Page: " + currentUrl,
    "Visible chapter text characters: " + visibleText.length,
    "Visible chapter appears substantial: " + (visibleText.length > 1000 ? "YES" : "NO"),
    "",
    "Testing one same-origin request..."
  ];

  try {
    const response = await fetch(currentUrl, {
      method: "GET",
      credentials: "include",
      redirect: "follow",
      cache: "no-store"
    });
    const html = await response.text();
    const parsed = new DOMParser().parseFromString(html, "text/html");
    const returnedChapter = parsed.querySelector(".chapter-content")?.innerText || "";
    const challenge = challengePattern.test(html);

    lines.push("HTTP status: " + response.status);
    lines.push("Final origin: " + new URL(response.url).origin);
    lines.push("Response characters: " + html.length);
    lines.push("Challenge markers: " + (challenge ? "YES" : "NO"));
    lines.push("Returned chapter text characters: " + returnedChapter.length);
    lines.push("Returned chapter appears substantial: " + (returnedChapter.length > 1000 ? "YES" : "NO"));
    lines.push("");
    lines.push(
      response.ok && !challenge && returnedChapter.length > 1000
        ? "RESULT: SAME-ORIGIN FETCH LOOKS PROMISING"
        : "RESULT: NOT READY FOR AUTOMATIC DOWNLOADING"
    );
  } catch (error) {
    lines.push("Fetch error: " + String(error && error.message ? error.message : error));
    lines.push("RESULT: BROWSER REQUEST FAILED");
  }

  window.alert(lines.join("\n"));
})();
