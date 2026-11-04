/*
 * Royal Road Kindle Tools — browser-side session diagnostic.
 *
 * Run this while viewing a Royal Road chapter. It performs one ordinary
 * same-origin fetch and displays aggregate diagnostics only.
 * It does not transmit or store chapter text, cookies, headers, or history.
 */
(function royalRoadSessionDiagnostic() {
  var w = window;
  var d = document;
  var url = w.location.href;

  function chapterText(doc) {
    var node = doc.querySelector(".chapter-content") ||
      doc.querySelector("#chapter-content") ||
      doc.querySelector("[class*='chapter-content']");
    var value = node ? (node.innerText || node.textContent || "") : "";
    return value.replace(/\s+/g, " ").trim();
  }

  if (w.location.hostname !== "www.royalroad.com" ||
      !/\/chapter\//.test(w.location.pathname)) {
    w.alert("Open a Royal Road chapter page first.");
    return;
  }

  var visible = chapterText(d);
  var lines = [
    "ROYAL ROAD BROWSER SESSION TEST",
    "Visible chapter characters: " + visible.length,
    "Visible chapter substantial (>1000): " + (visible.length > 1000 ? "YES" : "NO"),
    "",
    "Testing one same-origin request. No page text will be sent anywhere."
  ];

  if (!w.fetch) {
    lines.push("Fetch API: unavailable", "RESULT: browser cannot run this test");
    w.alert(lines.join("\n"));
    return;
  }

  w.fetch(url, {
    method: "GET",
    credentials: "include",
    redirect: "follow",
    cache: "no-store"
  }).then(function (response) {
    return response.text().then(function (html) {
      var parsed = new DOMParser().parseFromString(html, "text/html");
      var returned = chapterText(parsed);
      var challenge = /cf-chl-|cloudflare|just a moment|verify you are human|attention required/i.test(html);
      var finalOrigin = "unknown";
      try {
        finalOrigin = new URL(response.url).origin;
      } catch (e) {}

      lines.push(
        "HTTP status: " + response.status,
        "Final origin: " + finalOrigin,
        "Response characters: " + html.length,
        "Challenge markers: " + (challenge ? "YES" : "NO"),
        "Returned chapter characters: " + returned.length,
        "Returned chapter substantial (>1000): " + (returned.length > 1000 ? "YES" : "NO"),
        "",
        response.ok && !challenge && returned.length > 1000
          ? "RESULT: SAME-ORIGIN FETCH LOOKS PROMISING"
          : "RESULT: NOT READY FOR AUTOMATIC DOWNLOADING"
      );
      w.alert(lines.join("\n"));
    });
  }).catch(function (error) {
    lines.push(
      "Fetch error: " + (error && error.message ? error.message : String(error)),
      "RESULT: BROWSER REQUEST FAILED"
    );
    w.alert(lines.join("\n"));
  });
})();
