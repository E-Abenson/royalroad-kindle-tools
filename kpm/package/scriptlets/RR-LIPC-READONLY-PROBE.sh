#!/bin/sh
# Name: RR-LIPC-READONLY-PROBE
# Author: E-Abenson
# Read-only inventory of registered Kindle LIPC services and KPP processes.
# Does not set properties, send events, navigate, refresh, or run browser JavaScript.

DOCS="/mnt/us/documents"
LOG="$DOCS/RR-LIPC-READONLY-PROBE.log"
TMP="/tmp/rr_lipc_probe_$$.tmp"

mkdir -p "$DOCS" 2>/dev/null
trap 'rm -f "$TMP"' EXIT HUP INT TERM

{
    echo "============================================================"
    echo "KINDLE — LIPC READ-ONLY SERVICE PROBE"
    date 2>&1
    echo "============================================================"
    echo
    echo "This is a read-only inventory. No LIPC properties are set"
    echo "and no browser action, navigation, refresh, or JavaScript is sent."
    echo

    echo "---- Device / command availability ----"
    uname -a 2>&1
    echo
    for c in lipc-probe lipc-get-prop dbus-send gdbus ps; do
        if command -v "$c" >/dev/null 2>&1; then
            printf '%s: ' "$c"
            command -v "$c"
        else
            echo "$c: not found"
        fi
    done
    echo

    echo "---- KPP process snapshot (read only) ----"
    if command -v ps >/dev/null 2>&1; then
        ps 2>&1 | grep -iE 'KPPMainApp|KPPBrowser' | grep -v grep || echo "No matching process line found."
    else
        echo "ps: not found"
    fi
    echo

    echo "---- Full LIPC enumeration: lipc-probe -a -v ----"
    if command -v lipc-probe >/dev/null 2>&1; then
        lipc-probe -a -v > "$TMP" 2>&1
        PROBE_RC=$?
        echo "lipc-probe exit status: $PROBE_RC"
        if [ -f "$TMP" ]; then
            cat "$TMP"
        else
            echo "ERROR: The temporary probe output was not created."
        fi
        echo
        echo "---- Browser / KPP / Chrome / WebKit matches ----"
        if [ -s "$TMP" ] && grep -inE 'browser|kpp|chrome|webview|webkit' "$TMP"; then
            :
        else
            echo "No matching lines in lipc-probe output."
        fi
    else
        echo "lipc-probe is not installed or not in PATH."
    fi

    echo
    echo "============================================================"
    echo "END — read-only probe complete."
    echo "Log: $LOG"
    echo "============================================================"
} > "$LOG" 2>&1

sync 2>/dev/null
exit 0
