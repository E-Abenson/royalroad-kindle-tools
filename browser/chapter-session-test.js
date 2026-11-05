/*
 * Royal Road Kindle Tools — Kindle browser test.
 * Does not transmit page text, cookies, headers, or history.
 */
(function () {
  var w = window, d = document;
  var id = "rr-session-test-panel";
  var panel = d.getElementById(id);
  var visible = 0, started = new Date();

  function chapterText(doc) {
    var node = doc.querySelector(".chapter-content") ||
      doc.querySelector("#chapter-content") ||
      doc.querySelector("[class*='chapter-content']");
    var value = node ? (node.innerText || node.textContent || "") : "";
    return value.replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
  }

  function show(lines, logText, finalResult) {
    if (!panel) {
      panel = d.createElement("div");
      panel.id = id;
      panel.style.cssText = "position:fixed;top:3%;left:3%;width:94%;max-height:90%;overflow:auto;z-index:2147483647;background:#fff;color:#000;border:3px solid #000;padding:12px;box-sizing:border-box;font:18px/1.35 sans-serif;white-space:pre-wrap;";
      (d.body || d.documentElement).appendChild(panel);
    }
    while (panel.firstChild) panel.removeChild(panel.firstChild);
    var message = d.createElement("div");
    message.textContent = lines;
    panel.appendChild(message);

    if (finalResult) {
      var save = d.createElement("a");
      save.appendChild(d.createTextNode("SAVE SEPARATE TEST LOG FILE"));
      save.style.cssText = "display:block;margin-top:14px;padding:12px;border:2px solid #000;background:#eee;color:#000;font-weight:bold;text-align:center;";
      var filename = "RoyalRoadTools-test-" +
        started.getFullYear() + "-" +
        ("0" + (started.getMonth() + 1)).slice(-2) + "-" +
        ("0" + started.getDate()).slice(-2) + "-" +
        ("0" + started.getHours()).slice(-2) +
        ("0" + started.getMinutes()).slice(-2) + ".log";
      try {
        var blob = new Blob([logText], {type:"text/plain"});
        var objectUrl = (w.URL || w.webkitURL).createObjectURL(blob);
        save.href = objectUrl;
        save.download = filename;
        save.target = "_blank";
        save.onclick = function () {
          w.setTimeout(function () {
            try { (w.URL || w.webkitURL).revokeObjectURL(objectUrl); } catch (e) {}
          }, 30000);
        };
      } catch (e) {
        save.href = "data:text/plain;charset=utf-8," + encodeURIComponent(logText);
        save.target = "_blank";
      }
      panel.appendChild(save);
      var note = d.createElement("div");
      note.style.cssText = "margin-top:8px;font-size:14px;";
      note.textContent = "The result stays here for 10 seconds. Tap the save line above to keep the separate log.";
      panel.appendChild(note);
      if (panel._rrTimer) w.clearTimeout(panel._rrTimer);
      panel._rrTimer = w.setTimeout(function () {
        if (panel && panel.parentNode) panel.parentNode.removeChild(panel);
        panel = null;
      }, 10000);
    }
  }

  function finish(resultLines, fields) {
    fields = fields || {};
    var logLines = [
      "ROYAL ROAD KINDLE TOOLS — BROWSER TEST LOG",
      "Started: " + started.toString(),
      "Page host: " + w.location.host,
      "Page path: " + w.location.pathname,
      "Visible chapter characters: " + visible,
      "HTTP status: " + (fields.status === undefined ? "not available" : fields.status),
      "Response characters: " + (fields.responseChars === undefined ? "not available" : fields.responseChars),
      "Challenge markers: " + (fields.challenge === undefined ? "not checked" : (fields.challenge ? "YES" : "NO")),
      "Returned chapter characters: " + (fields.returned === undefined ? "not available" : fields.returned),
      "Error: " + (fields.error || "none"),
      "Result: " + resultLines[resultLines.length - 1],
      "",
      "No chapter text, cookies, credentials, or browser history were recorded."
    ];
    show(resultLines.join("\n"), logLines.join("\n") + "\n", true);
  }

  /* Immediate alert tells us whether Kindle executed the bookmark at all. */
  try { w.alert("Royal Road Session Test bookmark is running."); } catch (e) {}

  if (!/(^|\.)royalroad\.com$/i.test(w.location.hostname) ||
      !/\/chapter\//i.test(w.location.pathname)) {
    finish([
      "ROYAL ROAD SESSION TEST",
      "",
      "The bookmark did run, but this is not a chapter page.",
      "Open a Royal Road chapter and press the bookmark again.",
      "",
      "RESULT: WRONG PAGE"
    ], {error:"Bookmark opened outside a Royal Road chapter page."});
    return;
  }

  visible = chapterText(d).length;
  show(
    "ROYAL ROAD SESSION TEST\n\nBOOKMARK IS RUNNING\nVisible chapter characters: " + visible +
    "\n\nTesting one same-origin request. Please wait...",
    "",
    false
  );

  var xhr;
  try {
    xhr = new XMLHttpRequest();
    xhr.open("GET", w.location.href, true);
    xhr.withCredentials = true;
    try { xhr.timeout = 20000; } catch (ignore) {}
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      var html = xhr.responseText || "";
      var returned = 0;
      var challenge = /cf-chl-|cloudflare|just a moment|verify you are human|attention required/i.test(html);
      try {
        var parsed = (new DOMParser()).parseFromString(html, "text/html");
        returned = chapterText(parsed).length;
      } catch (e) {}
      var good = xhr.status >= 200 && xhr.status < 300 && !challenge && returned > 1000;
      finish([
        "ROYAL ROAD SESSION TEST",
        "",
        "Visible chapter characters: " + visible,
        "HTTP status: " + xhr.status,
        "Response characters: " + html.length,
        "Challenge markers: " + (challenge ? "YES" : "NO"),
        "Returned chapter characters: " + returned,
        "",
        "RESULT: " + (good ? "SAME-ORIGIN FETCH LOOKS PROMISING" : "NOT READY FOR AUTOMATIC DOWNLOADING"),
        "",
        "Final result remains visible for 10 seconds."
      ], {status:xhr.status,responseChars:html.length,challenge:challenge,returned:returned});
    };
    xhr.onerror = function () {
      finish([
        "ROYAL ROAD SESSION TEST",
        "",
        "Visible chapter characters: " + visible,
        "RESULT: BROWSER REQUEST FAILED",
        "",
        "Final result remains visible for 10 seconds."
      ], {error:"The browser reported a network or request error."});
    };
    xhr.ontimeout = function () {
      finish([
        "ROYAL ROAD SESSION TEST",
        "",
        "Visible chapter characters: " + visible,
        "RESULT: REQUEST TIMED OUT",
        "",
        "Final result remains visible for 10 seconds."
      ], {error:"The request timed out after 20 seconds."});
    };
    xhr.send(null);
  } catch (error) {
    finish([
      "ROYAL ROAD SESSION TEST",
      "",
      "RESULT: TEST COULD NOT START",
      String(error),
      "",
      "Final result remains visible for 10 seconds."
    ], {error:String(error)});
  }
})();