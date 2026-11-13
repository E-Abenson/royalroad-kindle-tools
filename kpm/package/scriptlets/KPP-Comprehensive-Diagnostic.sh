#!/bin/sh
# KPP-Comprehensive-Diagnostic: one-run, read-only KPP/browser/LIPC snapshot.
# LIPC inventory uses lipc-probe -l followed by individual service probes.
# Exact browser services from earlier project checks are always queried.
# Never use -v; raw output, values, URLs, command lines and cookies are excluded.

DOCS="/mnt/us/documents"
REPORT="$DOCS/KPP-Comprehensive-Diagnostic.txt"
TMP="$DOCS/.kpp-comprehensive-diagnostic.$$"
REPORT_TMP="$DOCS/.KPP-Comprehensive-Diagnostic.txt.tmp.$$"
PASTE_URL_FILE="$DOCS/KPP-Comprehensive-Diagnostic-upload-url.txt"
DELETE_URL_FILE="$DOCS/KPP-Comprehensive-Diagnostic-delete-url.txt"
HBC="/app/KPPMainApp/js/KPPMainApp.js.hbc"
KPP_BIN="/app/bin/KPPMainAppV2"

umask 077
mkdir -p "$DOCS" 2>/dev/null || { echo "Cannot access Kindle Documents."; exit 1; }
mkdir "$TMP" 2>/dev/null || { echo "Cannot create diagnostic temporary folder."; exit 1; }
cleanup_temp() { rm -rf "$TMP"; rm -f "$REPORT_TMP"; }
trap cleanup_temp 0
trap 'exit 1' HUP INT TERM
say() { printf '%s\n' "$*" >> "$REPORT_TMP"; }
section() { say ""; say "================================================================"; say "$1"; say "================================================================"; }

: > "$REPORT_TMP"
say "KINDLE KPP / BROWSER — COMPREHENSIVE READ-ONLY DIAGNOSTIC"
say "Generated: $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
say "Privacy: technical metadata only; no page URL/host, account identifier, cookie, command-line argument, or property value."
say "Sharing: sanitized report; link-only paste; one-week expiry requested."
say "Changes: no LIPC writes, events, configuration changes, or app modifications."

section "1. DEVICE AND PACKAGE"
say "Kernel: $(uname -r 2>/dev/null || echo unavailable)"
say "Architecture: $(uname -m 2>/dev/null || echo unavailable)"
if [ -r /etc/prettyversion.txt ]; then
  FW_LINE="$(head -n 1 /etc/prettyversion.txt 2>/dev/null | tr -cd '[:print:]')"
  [ -n "$FW_LINE" ] && say "Firmware marker: $FW_LINE"
else
  say "Firmware marker: unavailable"
fi
INSTALLED_VERSION="$DOCS/.RoyalRoadTools-installed-version.txt"
if [ -r "$INSTALLED_VERSION" ]; then
  VERSION_LINE="$(grep '^version=' "$INSTALLED_VERSION" 2>/dev/null | head -n 1)"
  [ -n "$VERSION_LINE" ] && say "Royal Road Kindle Tools: $VERSION_LINE"
else
  say "Royal Road Kindle Tools: installed-version marker unavailable"
fi

section "2. DIAGNOSTIC UTILITIES"
for TOOL in lipc-probe lipc-get-prop dbus-send sha256sum od readlink awk grep sort curl; do
  if command -v "$TOOL" >/dev/null 2>&1; then say "$TOOL: available"; else say "$TOOL: not found"; fi
done
say "dbus-monitor: not run"

section "3. KPP APPLICATION FINGERPRINTS"
for FILE in "$KPP_BIN" "$HBC"; do
  if [ -r "$FILE" ]; then
    SIZE="$(wc -c < "$FILE" 2>/dev/null | tr -d ' ')"
    say "File: $(basename "$FILE")"
    say "Size: $SIZE bytes"
    if command -v sha256sum >/dev/null 2>&1; then
      HASH="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"
      [ -n "$HASH" ] && say "SHA256: $HASH"
    fi
  else
    say "File unavailable: $(basename "$FILE")"
  fi
done
if [ -r "$HBC" ] && command -v od >/dev/null 2>&1; then
  HBC_MAGIC="$(od -An -tx1 -N 8 "$HBC" 2>/dev/null | tr -d '[:space:]')"
  HBC_VERSION="$(od -An -tu4 -j 8 -N 4 "$HBC" 2>/dev/null | tr -d '[:space:]')"
  [ -n "$HBC_MAGIC" ] && say "Hermes magic: $HBC_MAGIC"
  [ -n "$HBC_VERSION" ] && say "Hermes bytecode version: $HBC_VERSION"
fi

section "4. RUNNING KPP / BROWSER PROCESSES"
PROCESS_COUNT=0
for COMM_FILE in /proc/[0-9]*/comm; do
  [ -r "$COMM_FILE" ] || continue
  PROCESS_NAME="$(head -n 1 "$COMM_FILE" 2>/dev/null | tr -cd '[:alnum:]_.-')"
  LOWER_NAME="$(printf '%s' "$PROCESS_NAME" | tr '[:upper:]' '[:lower:]')"
  case "$LOWER_NAME" in
    *kpp*|*browser*|*webkit*|*webview*|*chrome*|*slate*)
      say "Process: $PROCESS_NAME"
      PROCESS_COUNT=$((PROCESS_COUNT + 1))
      ;;
  esac
done
[ "$PROCESS_COUNT" -gt 0 ] || say "No matching KPP/browser process names visible."

section "5. LIPC SERVICE-NAME DISCOVERY"
if command -v lipc-probe >/dev/null 2>&1; then
  if lipc-probe -l > "$TMP/lipc-list.txt" 2> "$TMP/lipc-list-error.txt"; then
    LIST_STATUS=0
  else
    LIST_STATUS=$?
  fi
  say "lipc-probe -l exit status: $LIST_STATUS"
  # Parse service-name tokens only.
  awk '
    {
      line=$0
      gsub(/\r/, "", line)
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      if (line ~ /^(com|org)[.][A-Za-z0-9_.-]+$/) {
        low=tolower(line)
        if (low ~ /(kpp|browser|webkit|webview|chrome|slate|appmgrd)/ && !seen[line]++) print line
      }
    }
  ' "$TMP/lipc-list.txt" > "$TMP/discovered-services.txt"

  # Query the historical project targets even if -l fails on this firmware.
  {
    [ -s "$TMP/discovered-services.txt" ] && cat "$TMP/discovered-services.txt"
    printf '%s\n' "com.lab126.kppbrowser" "com.lab126.browser" "com.lab126.appmgrd"
  } | sort -u > "$TMP/services.txt"

  DISCOVERED_COUNT="$(wc -l < "$TMP/discovered-services.txt" | tr -d ' ')"
  SELECTED_COUNT="$(wc -l < "$TMP/services.txt" | tr -d ' ')"
  say "Matching service names discovered: $DISCOVERED_COUNT"
  say "Services selected for individual probes: $SELECTED_COUNT"
  if [ "$LIST_STATUS" -ne 0 ]; then say "Service-list command failed; historical targeted probes will still run."; fi
  if [ ! -s "$TMP/discovered-services.txt" ]; then say "No matching service names parsed; historical targeted probes will still run."; fi
else
  say "ERROR: lipc-probe unavailable."
fi


section "6. ALL-SERVICE METADATA SCAN — PARTIAL OUTPUT IS RETAINED"
: > "$TMP/all-scan-metadata.txt"
if command -v lipc-probe >/dev/null 2>&1; then
  # No -v: do not request readable property values. Parse stdout even on exit 1.
  if lipc-probe -a > "$TMP/lipc-all.txt" 2> "$TMP/lipc-all-error.txt"; then
    ALL_STATUS=0
  else
    ALL_STATUS=$?
  fi
  ALL_BYTES="$(wc -c < "$TMP/lipc-all.txt" 2>/dev/null | tr -d ' ')"
  ALL_LINES="$(wc -l < "$TMP/lipc-all.txt" 2>/dev/null | tr -d ' ')"
  say "lipc-probe -a exit status: $ALL_STATUS"
  say "Captured stdout size: $ALL_BYTES bytes; lines: $ALL_LINES"
  say "Stderr classification: $(error_class "$TMP/lipc-all-error.txt")"
  awk -v out="$TMP/all-scan-metadata.txt" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function access_ok(s) { return s=="r" || s=="w" || s=="rw" }
    function type_ok(s) { return s=="Int" || s=="Str" || s=="Has" }
    function name_ok(s) { return s ~ /^[A-Za-z_][A-Za-z0-9_.-]*$/ }
    {
      line=trim($0)
      if (line ~ /^(com|org)[.][A-Za-z0-9_.-]+$/) {
        current=line
        lower=tolower(current)
        keep=(lower ~ /(kpp|browser|webkit|webview|chrome|slate|appmgrd)/)
        next
      }
      if (!keep) next
      n=split(line, f, /[| \t]+/)
      for (i=1; i<=n && i<=3; i++) f[i]=trim(f[i])
      if (n>=3 && access_ok(f[1]) && type_ok(f[2]) && name_ok(f[3])) {
        print current "|" f[3] "|" f[2] "|" f[1] >> out
      } else if (n>=3 && name_ok(f[1]) && type_ok(f[2]) && access_ok(f[3])) {
        print current "|" f[1] "|" f[2] "|" f[3] >> out
      }
    }
  ' "$TMP/lipc-all.txt" 2>/dev/null
  if [ -s "$TMP/all-scan-metadata.txt" ]; then
    sort -u "$TMP/all-scan-metadata.txt" > "$TMP/all-scan-sorted.txt"
    ALL_ROWS="$(wc -l < "$TMP/all-scan-sorted.txt" | tr -d ' ')"
    say "Relevant property metadata rows recovered from all-scan stdout: $ALL_ROWS"
    while IFS='|' read -r SERVICE PROPERTY PROP_TYPE ACCESS; do
      say "$SERVICE | $PROPERTY | Type: $PROP_TYPE | Access: $ACCESS"
    done < "$TMP/all-scan-sorted.txt"
  else
    say "No relevant property rows could be safely parsed from all-scan stdout."
    say "Partial raw output was discarded after local analysis."
  fi
else
  say "lipc-probe unavailable; all-service scan skipped."
fi

section "7. INDIVIDUAL SERVICE PROBE STATUS AND PROPERTY METADATA"
: > "$TMP/metadata.txt"
if command -v lipc-probe >/dev/null 2>&1 && [ -s "$TMP/services.txt" ]; then
  while IFS= read -r SERVICE || [ -n "$SERVICE" ]; do
    [ -n "$SERVICE" ] || continue
    case "$SERVICE" in *[!A-Za-z0-9_.-]*) continue ;; esac
    if lipc-probe "$SERVICE" > "$TMP/service-output.txt" 2> "$TMP/service-error.txt"; then
      SERVICE_STATUS=0
    else
      SERVICE_STATUS=$?
    fi
    OUT_BYTES="$(wc -c < "$TMP/service-output.txt" 2>/dev/null | tr -d ' ')"
    OUT_LINES="$(wc -l < "$TMP/service-output.txt" 2>/dev/null | tr -d ' ')"
    BEFORE="$(wc -l < "$TMP/metadata.txt" 2>/dev/null | tr -d ' ')"
    # Parse any stdout even when the command exits nonzero.
    awk -v svc="$SERVICE" '
      function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
      function access_ok(s) { return s=="r" || s=="w" || s=="rw" }
      function type_ok(s) { return s=="Str" || s=="Int" || s=="Has" }
      function name_ok(s) { return s ~ /^[A-Za-z_][A-Za-z0-9_.-]*$/ }
      {
        line=$0; gsub(/\r/, "", line); line=trim(line)
        n=split(line, f, /[| \t]+/)
        for (i=1; i<=n && i<=3; i++) f[i]=trim(f[i])
        name=""; type=""; access=""
        if (n>=3 && access_ok(f[1]) && type_ok(f[2]) && name_ok(f[3])) {
          access=f[1]; type=f[2]; name=f[3]
        } else if (n>=3 && name_ok(f[1]) && type_ok(f[2]) && access_ok(f[3])) {
          name=f[1]; type=f[2]; access=f[3]
        }
        if (name!="" && !seen[name]++) print svc "|" name "|" type "|" access
      }
    ' "$TMP/service-output.txt" >> "$TMP/metadata.txt" 2>/dev/null
    AFTER="$(wc -l < "$TMP/metadata.txt" 2>/dev/null | tr -d ' ')"
    ROWS=$((AFTER - BEFORE))
    say "$SERVICE: exit=$SERVICE_STATUS; stdout bytes=$OUT_BYTES; lines=$OUT_LINES; parsed rows=$ROWS; stderr=$(error_class "$TMP/service-error.txt")"
  done < "$TMP/services.txt"

  if [ -s "$TMP/metadata.txt" ]; then
    sort -u "$TMP/metadata.txt" > "$TMP/metadata-sorted.txt"
    while IFS='|' read -r SERVICE PROPERTY PROP_TYPE ACCESS; do
      say "$SERVICE | $PROPERTY | Type: $PROP_TYPE | Access: $ACCESS"
    done < "$TMP/metadata-sorted.txt"
  else
    say "No property metadata rows could be parsed. Raw output and errors were suppressed."
  fi
else
  say "Individual service probes were skipped."
fi

section "8. READ-ONLY D-BUS INTROSPECTION FALLBACK"
: > "$TMP/introspection-methods.txt"
if command -v dbus-send >/dev/null 2>&1 && [ -s "$TMP/services.txt" ]; then
  INTROSPECT_COUNT=0
  while IFS= read -r SERVICE || [ -n "$SERVICE" ]; do
    [ -n "$SERVICE" ] || continue
    LOWER_SERVICE="$(printf '%s' "$SERVICE" | tr '[:upper:]' '[:lower:]')"
    case "$LOWER_SERVICE" in
      *kppbrowser*|*browser*|*kppmainapp*|*kppnavigation*|*kppcontextmenu*|*kppchromebar*|*kppstorage*|*kppsettings*|*kppbridge*) ;;
      *) continue ;;
    esac
    [ "$INTROSPECT_COUNT" -lt 16 ] || break
    if dbus-send --system --print-reply --dest="$SERVICE" /default org.freedesktop.DBus.Introspectable.Introspect > "$TMP/introspection-output.txt" 2> "$TMP/introspection-error.txt"; then
      INTRO_STATUS=0
    else
      INTRO_STATUS=$?
    fi
    sed 's/\\"/"/g' "$TMP/introspection-output.txt" > "$TMP/introspection-unescaped.txt"
    grep -o 'method name="[^"]*"' "$TMP/introspection-unescaped.txt" 2>/dev/null |
      sed 's/^method name="//;s/"$//' |
      grep -E '^(get|set)[A-Za-z0-9_.-]*(Int|Str|Has)
if [ -s "$TMP/services.txt" ] && command -v dbus-send >/dev/null 2>&1; then
  while IFS= read -r SERVICE || [ -n "$SERVICE" ]; do
    [ -n "$SERVICE" ] || continue
    OWNER_REPLY="$(dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetConnectionUnixProcessID "string:$SERVICE" 2>/dev/null)"
    OWNER_PID="$(printf '%s\n' "$OWNER_REPLY" | awk '/uint32/ {print $2; exit}')"
    case "$OWNER_PID" in
      ''|*[!0-9]*) say "$SERVICE: owner unavailable or service inactive" ;;
      *)
        OWNER_COMM=""
        [ -r "/proc/$OWNER_PID/comm" ] && OWNER_COMM="$(head -n 1 "/proc/$OWNER_PID/comm" 2>/dev/null | tr -cd '[:alnum:]_.-')"
        say "$SERVICE: owner process=$OWNER_COMM"
        ;;
    esac
  done < "$TMP/services.txt"
else
  say "Service-owner lookup skipped."
fi

section "10. CURRENT-PAGE PRIVACY"
say "The browser page was not read or included."
say "No URL, hostname, path, query, fragment, page text, or history was collected."

section "11. EXPLICITLY NOT TESTED"
say "- No LIPC property was written."
say "- No invokeAction value or browser action was attempted."
say "- No LIPC event was emitted."
say "- No JavaScript was injected or executed."
say "- No D-Bus monitoring or eavesdropping policy was enabled."
say "- No cookies, browser history, page text, URL, or account data were read."
say "- No application binary or configuration file was modified."

section "12. RESULT"
say "This report is a single read-only snapshot, not proof that an external browser action is supported."
say "LIPC discovery uses lipc-probe -l and targeted individual service probes."
say "The failed lipc-probe -a command is not repeated."
say "The report contains filtered service/property metadata, D-Bus method names, process names, service-owner process names, and software fingerprints."

chmod 600 "$REPORT_TMP" 2>/dev/null || true
if ! mv -f "$REPORT_TMP" "$REPORT"; then
  echo "Diagnostic completed, but the report could not be saved."
  exit 1
fi

echo "Diagnostic collected. Uploading sanitized technical report to pasters.io..."
if ! command -v curl >/dev/null 2>&1; then
  echo "UPLOAD NOT DONE: curl unavailable. Local report saved at $REPORT"
  exit 0
fi

HTTP_CODE="$(curl -sS --connect-timeout 10 --max-time 45 \
  -D "$TMP/headers.txt" -o "$TMP/response.txt" -w '%{http_code}' \
  --data-binary "@$REPORT" "https://pasters.io/?expires=1w" 2> "$TMP/curl-error.txt")"
CURL_STATUS=$?
if [ "$CURL_STATUS" -ne 0 ]; then
  echo "UPLOAD FAILED. Local report retained at $REPORT"
  echo "No USB export was attempted."
  exit 0
fi

header_value() {
  HEADER_NAME="$1"
  tr -d '\r' < "$TMP/headers.txt" | awk -v wanted="$HEADER_NAME" '
    BEGIN { wanted=tolower(wanted) }
    {
      name=$0; sub(/:.*/, "", name)
      if (tolower(name)==wanted) { sub(/^[^:]*:[ \t]*/, ""); print; exit }
    }'
}
PASTE_URL="$(header_value Location)"
case "$PASTE_URL" in
  https://pasters.io/*) ;;
  *) PASTE_URL="$(sed -n 's@.*\(https://pasters\.io/[A-Za-z0-9_-][A-Za-z0-9_-]*\).*@\1@p' "$TMP/response.txt" | head -n 1)" ;;
esac
DELETE_URL="$(header_value X-Delete-Url)"

case "$PASTE_URL" in
  https://pasters.io/*)
    printf '%s\n' "$PASTE_URL" > "$TMP/paste-url.txt"
    chmod 600 "$TMP/paste-url.txt"
    mv -f "$TMP/paste-url.txt" "$PASTE_URL_FILE"
    case "$DELETE_URL" in
      https://pasters.io/d/*)
        printf '%s\n' "$DELETE_URL" > "$TMP/delete-url.txt"
        chmod 600 "$TMP/delete-url.txt"
        mv -f "$TMP/delete-url.txt" "$DELETE_URL_FILE"
        ;;
      *) rm -f "$DELETE_URL_FILE" ;;
    esac
    echo "UPLOAD COMPLETE (HTTP $HTTP_CODE)."
    echo "Paste link:"
    echo "$PASTE_URL"
    echo "The paste link and any deletion link are saved privately in Documents."
    echo "Only the sanitized diagnostic report was uploaded."
    echo "One-week expiry was requested."
    ;;
  *)
    echo "UPLOAD COULD NOT BE VERIFIED (HTTP $HTTP_CODE)."
    echo "Local report retained at $REPORT"
    ;;
esac
sync 2>/dev/null
exit 0
 |
      sort -u > "$TMP/introspection-one.txt"
    METHOD_COUNT="$(wc -l < "$TMP/introspection-one.txt" 2>/dev/null | tr -d ' ')"
    say "$SERVICE: Introspect exit=$INTRO_STATUS; LIPC-shaped method names=$METHOD_COUNT; stderr=$(error_class "$TMP/introspection-error.txt")"
    if [ -s "$TMP/introspection-one.txt" ]; then
      while IFS= read -r METHOD; do
        printf '%s|%s\n' "$SERVICE" "$METHOD" >> "$TMP/introspection-methods.txt"
      done < "$TMP/introspection-one.txt"
    fi
    INTROSPECT_COUNT=$((INTROSPECT_COUNT + 1))
  done < "$TMP/services.txt"
else
  say "D-Bus introspection skipped; dbus-send or service list unavailable."
fi
if [ -s "$TMP/introspection-methods.txt" ]; then
  sort -u "$TMP/introspection-methods.txt" > "$TMP/introspection-sorted.txt"
  say "LIPC-shaped D-Bus methods exposed by read-only introspection:"
  while IFS='|' read -r SERVICE METHOD; do
    say "$SERVICE | $METHOD"
  done < "$TMP/introspection-sorted.txt"
else
  say "No LIPC-shaped methods were returned by D-Bus introspection."
fi

section "9. READ-ONLY SERVICE OWNER LOOKUP"
if [ -s "$TMP/services.txt" ] && command -v dbus-send >/dev/null 2>&1; then
  while IFS= read -r SERVICE || [ -n "$SERVICE" ]; do
    [ -n "$SERVICE" ] || continue
    OWNER_REPLY="$(dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetConnectionUnixProcessID "string:$SERVICE" 2>/dev/null)"
    OWNER_PID="$(printf '%s\n' "$OWNER_REPLY" | awk '/uint32/ {print $2; exit}')"
    case "$OWNER_PID" in
      ''|*[!0-9]*) say "$SERVICE: owner unavailable or service inactive" ;;
      *)
        OWNER_COMM=""
        [ -r "/proc/$OWNER_PID/comm" ] && OWNER_COMM="$(head -n 1 "/proc/$OWNER_PID/comm" 2>/dev/null | tr -cd '[:alnum:]_.-')"
        say "$SERVICE: owner process=$OWNER_COMM"
        ;;
    esac
  done < "$TMP/services.txt"
else
  say "Service-owner lookup skipped."
fi

section "8. CURRENT-PAGE PRIVACY"
say "The browser page was not read or included."
say "No URL, hostname, path, query, fragment, page text, or history was collected."

section "9. EXPLICITLY NOT TESTED"
say "- No LIPC property was written."
say "- No invokeAction value or browser action was attempted."
say "- No LIPC event was emitted."
say "- No JavaScript was injected or executed."
say "- No D-Bus monitoring or eavesdropping policy was enabled."
say "- No cookies, browser history, page text, URL, or account data were read."
say "- No application binary or configuration file was modified."

section "10. RESULT"
say "This report is a single read-only snapshot, not proof that an external browser action is supported."
say "LIPC discovery uses lipc-probe -l and targeted individual service probes."
say "The failed lipc-probe -a command is not repeated."
say "The report contains filtered service/property metadata, process names, service-owner process names, and software fingerprints."

chmod 600 "$REPORT_TMP" 2>/dev/null || true
if ! mv -f "$REPORT_TMP" "$REPORT"; then
  echo "Diagnostic completed, but the report could not be saved."
  exit 1
fi

echo "Diagnostic collected. Uploading sanitized technical report to pasters.io..."
if ! command -v curl >/dev/null 2>&1; then
  echo "UPLOAD NOT DONE: curl unavailable. Local report saved at $REPORT"
  exit 0
fi

HTTP_CODE="$(curl -sS --connect-timeout 10 --max-time 45 \
  -D "$TMP/headers.txt" -o "$TMP/response.txt" -w '%{http_code}' \
  --data-binary "@$REPORT" "https://pasters.io/?expires=1w" 2> "$TMP/curl-error.txt")"
CURL_STATUS=$?
if [ "$CURL_STATUS" -ne 0 ]; then
  echo "UPLOAD FAILED. Local report retained at $REPORT"
  echo "No USB export was attempted."
  exit 0
fi

header_value() {
  HEADER_NAME="$1"
  tr -d '\r' < "$TMP/headers.txt" | awk -v wanted="$HEADER_NAME" '
    BEGIN { wanted=tolower(wanted) }
    {
      name=$0; sub(/:.*/, "", name)
      if (tolower(name)==wanted) { sub(/^[^:]*:[ \t]*/, ""); print; exit }
    }'
}
PASTE_URL="$(header_value Location)"
case "$PASTE_URL" in
  https://pasters.io/*) ;;
  *) PASTE_URL="$(sed -n 's@.*\(https://pasters\.io/[A-Za-z0-9_-][A-Za-z0-9_-]*\).*@\1@p' "$TMP/response.txt" | head -n 1)" ;;
esac
DELETE_URL="$(header_value X-Delete-Url)"

case "$PASTE_URL" in
  https://pasters.io/*)
    printf '%s\n' "$PASTE_URL" > "$TMP/paste-url.txt"
    chmod 600 "$TMP/paste-url.txt"
    mv -f "$TMP/paste-url.txt" "$PASTE_URL_FILE"
    case "$DELETE_URL" in
      https://pasters.io/d/*)
        printf '%s\n' "$DELETE_URL" > "$TMP/delete-url.txt"
        chmod 600 "$TMP/delete-url.txt"
        mv -f "$TMP/delete-url.txt" "$DELETE_URL_FILE"
        ;;
      *) rm -f "$DELETE_URL_FILE" ;;
    esac
    echo "UPLOAD COMPLETE (HTTP $HTTP_CODE)."
    echo "Paste link:"
    echo "$PASTE_URL"
    echo "The paste link and any deletion link are saved privately in Documents."
    echo "Only the sanitized diagnostic report was uploaded."
    echo "One-week expiry was requested."
    ;;
  *)
    echo "UPLOAD COULD NOT BE VERIFIED (HTTP $HTTP_CODE)."
    echo "Local report retained at $REPORT"
    ;;
esac
sync 2>/dev/null
exit 0
