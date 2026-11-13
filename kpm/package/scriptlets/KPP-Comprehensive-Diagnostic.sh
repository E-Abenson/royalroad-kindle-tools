#!/bin/sh
# Name: KPP-Comprehensive-Diagnostic
# One-run, read-only KPP/browser/LIPC inventory for Kindle 5.16+.
#
# SAFETY:
# - Does not set LIPC properties or emit LIPC events.
# - Does not write to invokeAction or any browser/action interface.
# - Uses lipc-probe -a WITHOUT -v: inventories property names/types only.
# - Reads getLastOpenPage only if the service advertises it as readable;
#   reports the hostname only and discards the path/query/fragment.
# - Does not monitor D-Bus traffic, alter D-Bus policy, access cookies,
#   inspect browser storage, or make network requests.
# - Does not execute, modify, or upload the KPP application bundle.

DOCS="/mnt/us/documents"
REPORT="$DOCS/KPP-Comprehensive-Diagnostic.txt"
TMP="$DOCS/.kpp-comprehensive-diagnostic.$$"
REPORT_TMP="$DOCS/.KPP-Comprehensive-Diagnostic.txt.tmp.$$"
HBC="/app/KPPMainApp/js/KPPMainApp.js.hbc"
KPP_BIN="/app/bin/KPPMainAppV2"

umask 077
mkdir -p "$DOCS" 2>/dev/null || {
  echo "Cannot access Kindle Documents."
  exit 1
}
if ! mkdir "$TMP" 2>/dev/null; then
  echo "Could not create the temporary diagnostic folder."
  exit 1
fi
trap 'rm -rf "$TMP"; rm -f "$REPORT_TMP"' 0 HUP INT TERM

say() {
  printf '%s\n' "$*" >> "$REPORT_TMP"
}
section() {
  say ""
  say "================================================================"
  say "$1"
  say "================================================================"
}

: > "$REPORT_TMP"
say "KINDLE KPP / BROWSER — COMPREHENSIVE READ-ONLY DIAGNOSTIC"
say "Generated: $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
say "Purpose: one consolidated snapshot of KPP, browser and LIPC interfaces."
say "Privacy: no account identifiers, command-line arguments, cookies, or page paths are collected."
say "Network: no network requests were made."
say "Changes: no LIPC writes, events, configuration changes, or app modifications were made."

section "1. DEVICE AND PACKAGE"
say "Kernel: $(uname -r 2>/dev/null || echo unavailable)"
say "Architecture: $(uname -m 2>/dev/null || echo unavailable)"
if [ -r /etc/prettyversion.txt ]; then
  FW_LINE="$(head -n 1 /etc/prettyversion.txt 2>/dev/null | tr -cd '[:print:]')"
  [ -n "$FW_LINE" ] && say "Firmware marker: $FW_LINE"
else
  say "Firmware marker: /etc/prettyversion.txt unavailable"
fi
INSTALLED_VERSION="$DOCS/.RoyalRoadTools-installed-version.txt"
if [ -r "$INSTALLED_VERSION" ]; then
  VERSION_LINE="$(grep '^version=' "$INSTALLED_VERSION" 2>/dev/null | head -n 1)"
  [ -n "$VERSION_LINE" ] && say "Royal Road Kindle Tools: $VERSION_LINE"
else
  say "Royal Road Kindle Tools: installed-version marker unavailable"
fi

section "2. DIAGNOSTIC UTILITIES"
for TOOL in lipc-probe lipc-get-prop dbus-send sha256sum od readlink awk grep; do
  TOOL_PATH="$(command -v "$TOOL" 2>/dev/null)"
  if [ -n "$TOOL_PATH" ]; then
    say "$TOOL: available ($TOOL_PATH)"
  else
    say "$TOOL: not found"
  fi
done
if command -v dbus-monitor >/dev/null 2>&1; then
  say "dbus-monitor: available (not run; no bus traffic captured)"
else
  say "dbus-monitor: not found"
fi

section "3. KPP APPLICATION FILES"
for FILE in "$KPP_BIN" "$HBC"; do
  if [ -r "$FILE" ]; then
    SIZE="$(wc -c < "$FILE" 2>/dev/null | tr -d ' ')"
    say "File: $FILE"
    say "Size: ${SIZE:-unknown} bytes"
    if command -v sha256sum >/dev/null 2>&1; then
      HASH="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"
      say "SHA256: ${HASH:-unavailable}"
    fi
  else
    say "File unavailable: $FILE"
  fi
done
if [ -r "$HBC" ] && command -v od >/dev/null 2>&1; then
  HBC_MAGIC="$(od -An -tx1 -N 8 "$HBC" 2>/dev/null | tr -d '[:space:]')"
  HBC_VERSION="$(od -An -tu4 -j 8 -N 4 "$HBC" 2>/dev/null | tr -d '[:space:]')"
  say "Hermes magic: ${HBC_MAGIC:-unavailable}"
  say "Hermes bytecode version: ${HBC_VERSION:-unavailable}"
fi

section "4. RUNNING KPP / BROWSER PROCESSES"
PROCESS_COUNT=0
for COMM_FILE in /proc/[0-9]*/comm; do
  [ -r "$COMM_FILE" ] || continue
  PROCESS_NAME="$(head -n 1 "$COMM_FILE" 2>/dev/null | tr -cd '[:alnum:]_.-')"
  LOWER_NAME="$(printf '%s' "$PROCESS_NAME" | tr '[:upper:]' '[:lower:]')"
  case "$LOWER_NAME" in
    *kpp*|*browser*|*webkit*|*webview*|*chrome*|*slate*)
      PID_DIR="${COMM_FILE%/comm}"
      PID="${PID_DIR##*/}"
      EXE_PATH=""
      if [ -L "/proc/$PID/exe" ] && command -v readlink >/dev/null 2>&1; then
        EXE_PATH="$(readlink "/proc/$PID/exe" 2>/dev/null)"
      fi
      say "PID=$PID  process=$PROCESS_NAME${EXE_PATH:+  executable=$EXE_PATH}"
      PROCESS_COUNT=$((PROCESS_COUNT + 1))
      ;;
  esac
done
[ "$PROCESS_COUNT" -gt 0 ] || say "No process names matching KPP/browser/WebKit/Chrome were visible in /proc."

section "5. LIPC SERVICE AND PROPERTY INVENTORY (NAMES ONLY)"
if command -v lipc-probe >/dev/null 2>&1; then
  # Deliberately omit -v: it would read and print every readable property value.
  lipc-probe -a > "$TMP/lipc-all.txt" 2> "$TMP/lipc-error.txt"
  LIPC_STATUS=$?
  say "lipc-probe -a exit status: $LIPC_STATUS"
  say "The full service scan was filtered locally. Only matching service/property names are included."
  if [ "$LIPC_STATUS" -eq 0 ] && [ -s "$TMP/lipc-all.txt" ]; then
    awk -v svcfile="$TMP/services.txt" -v outfile="$TMP/relevant-lipc.txt" '
      function trim(s) {
        sub(/^[[:space:]]+/, "", s)
        sub(/[[:space:]]+$/, "", s)
        sub(/:$/, "", s)
        return s
      }
      {
        raw = $0
        candidate = trim(raw)
        if (candidate ~ /^(com|org)[.][A-Za-z0-9_.-]+$/ && raw !~ /^[[:space:]]/) {
          service = candidate
          lower = tolower(service)
          capture = (lower ~ /(kpp|browser|webkit|webview|chrome|slate|appmgrd)/)
          if (capture) {
            print service >> svcfile
            print service >> outfile
          }
          next
        }
        if (capture && raw ~ /[^[:space:]]/) print raw >> outfile
      }
    ' "$TMP/lipc-all.txt"

    if [ -s "$TMP/services.txt" ]; then
      sort -u "$TMP/services.txt" > "$TMP/services-sorted.txt"
      say ""
      say "Matching registered services and their advertised properties:"
      cat "$TMP/relevant-lipc.txt" >> "$REPORT_TMP"
      cp "$TMP/services-sorted.txt" "$TMP/services.txt"
    else
      say "No matching service blocks were parsed from lipc-probe output."
      say "Matching service-name lines, if any:"
      grep -iE '^[[:space:]]*(com|org)[.][A-Za-z0-9_.-]*(kpp|browser|webkit|webview|chrome|slate|appmgrd)[A-Za-z0-9_.-]*[[:space:]]*$' "$TMP/lipc-all.txt" >> "$REPORT_TMP" 2>/dev/null || say "(none found)"
    fi
  else
    say "LIPC inventory did not return a usable listing."
  fi
else
  say "lipc-probe is unavailable; LIPC inventory was skipped."
fi

section "6. READ-ONLY LIPC SERVICE OWNERS"
if [ -s "$TMP/services.txt" ] && command -v dbus-send >/dev/null 2>&1; then
  OWNER_COUNT=0
  while IFS= read -r SERVICE || [ -n "$SERVICE" ]; do
    [ -n "$SERVICE" ] || continue
    case "$SERVICE" in *[!A-Za-z0-9_.-]*) continue ;; esac
    [ "$OWNER_COUNT" -lt 20 ] || break
    OWNER_REPLY="$(dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetConnectionUnixProcessID "string:$SERVICE" 2>/dev/null)"
    OWNER_PID="$(printf '%s\n' "$OWNER_REPLY" | awk '/uint32/ {print $2; exit}')"
    case "$OWNER_PID" in
      ''|*[!0-9]*) say "$SERVICE: owner PID unavailable (service may not be active)" ;;
      *)
        OWNER_COMM=""
        [ -r "/proc/$OWNER_PID/comm" ] && OWNER_COMM="$(head -n 1 "/proc/$OWNER_PID/comm" 2>/dev/null)"
        OWNER_EXE=""
        if [ -L "/proc/$OWNER_PID/exe" ] && command -v readlink >/dev/null 2>&1; then
          OWNER_EXE="$(readlink "/proc/$OWNER_PID/exe" 2>/dev/null)"
        fi
        say "$SERVICE: PID=$OWNER_PID${OWNER_COMM:+ process=$OWNER_COMM}${OWNER_EXE:+ executable=$OWNER_EXE}"
        ;;
    esac
    OWNER_COUNT=$((OWNER_COUNT + 1))
  done < "$TMP/services.txt"
elif [ -s "$TMP/services.txt" ]; then
  say "dbus-send is unavailable; service-owner lookup was skipped."
else
  say "No filtered service names were available for owner lookup."
fi

section "7. SAFE CURRENT-PAGE CHECK"
if [ -s "$TMP/lipc-all.txt" ] && command -v lipc-get-prop >/dev/null 2>&1; then
  if awk '
    /^[[:space:]]*com[.]lab126[.]kppbrowser[[:space:]]*$/ { in_service=1; next }
    /^[^[:space:]]/ { in_service=0 }
    in_service && $2 == "Str" && $NF == "getLastOpenPage" && ($1 == "r" || $1 == "rw") { found=1 }
    END { exit !found }
  ' "$TMP/lipc-all.txt"; then
    PAGE_VALUE="$(lipc-get-prop com.lab126.kppbrowser getLastOpenPage 2>/dev/null | head -n 1 | tr -d '\r')"
    PAGE_VALUE="$(printf '%s' "$PAGE_VALUE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$PAGE_VALUE" in
      \[*\]) PAGE_VALUE="${PAGE_VALUE#\[}"; PAGE_VALUE="${PAGE_VALUE%\]}" ;;
    esac
    case "$PAGE_VALUE" in
      http://*|https://*)
        PAGE_REST="${PAGE_VALUE#*://}"
        PAGE_HOST="${PAGE_REST%%/*}"
        PAGE_HOST="${PAGE_HOST%%:*}"
        case "$PAGE_HOST" in
          ''|*[!A-Za-z0-9.-]*) PAGE_HOST="[host omitted]" ;;
        esac
        say "com.lab126.kppbrowser.getLastOpenPage: readable."
        say "Current page host: $PAGE_HOST"
        say "Page path, query, fragment and full URL: deliberately omitted."
        ;;
      *)
        say "com.lab126.kppbrowser.getLastOpenPage was readable, but returned an empty or non-HTTP(S) value; the value was omitted."
        ;;
    esac
  else
    say "No readable com.lab126.kppbrowser.getLastOpenPage property was advertised; no page value was requested."
  fi
else
  say "The LIPC listing or lipc-get-prop is unavailable; current-page check was skipped."
fi

section "8. EXPLICITLY NOT TESTED"
say "- No LIPC property was written."
say "- No invokeAction value or browser action was attempted."
say "- No LIPC event was emitted."
say "- No JavaScript was injected or executed."
say "- No D-Bus monitor/eavesdrop policy was enabled or changed."
say "- No cookies, browser history, page text, URL path, query string, or account data were read."
say "- No network request was made."
say "- No application binary or configuration file was modified."

section "9. RESULT"
say "This report is a single read-only snapshot, not proof that an external browser action is supported."
say "The most useful evidence is the filtered LIPC property list, service-owner mapping, process list, and KPP bundle fingerprint."
say "Report path: $REPORT"

chmod 644 "$REPORT_TMP" 2>/dev/null || true
if ! mv -f "$REPORT_TMP" "$REPORT"; then
  echo "Diagnostic completed, but the report could not be saved to Documents."
  exit 1
fi
chmod 644 "$REPORT" 2>/dev/null || true
sync 2>/dev/null
echo "SUCCESS — comprehensive read-only diagnostic saved:"
echo "$REPORT"
echo "No device settings or browser actions were changed."
exit 0
