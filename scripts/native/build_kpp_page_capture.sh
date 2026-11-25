#!/bin/sh
# Cross-build the experimental KPP offscreen WebKit text-capture helper.
# Requires Clang + LLD and a matching extracted Kindle firmware/app library tree.
set -eu

SYSROOT="${KINDLE_SYSROOT:-}"
OUT="${1:-kpp-page-capture}"
CC="${CC:-clang}"
LD="${LD:-ld.lld}"

[ -n "$SYSROOT" ] && [ -d "$SYSROOT/usr/lib" ] || {
  echo "Set KINDLE_SYSROOT to the root of the extracted Kindle files tree." >&2
  exit 2
}
command -v "$CC" >/dev/null 2>&1 || { echo "Clang not found: $CC" >&2; exit 2; }
command -v "$LD" >/dev/null 2>&1 || { echo "LLD not found: $LD" >&2; exit 2; }

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TMP="${TMPDIR:-/tmp}/rrkpp-build.$$"
trap 'rm -rf "$TMP"' 0 HUP INT TERM
mkdir -p "$TMP"

"$CC" --target=armv7-unknown-linux-gnueabihf -mfpu=vfpv3 -mfloat-abi=hard \
  -fPIC -ffreestanding -fno-stack-protector -fno-unwind-tables \
  -fno-asynchronous-unwind-tables -O2 -c "$HERE/kpp_page_capture.c" \
  -o "$TMP/kpp_page_capture.o"
"$CC" --target=armv7-unknown-linux-gnueabihf -mfpu=vfpv3 -mfloat-abi=hard \
  -c "$HERE/kpp_start.S" -o "$TMP/kpp_start.o"

"$LD" -m armelf_linux_eabi -o "$OUT" -e _start \
  --dynamic-linker=/lib/ld-linux-armhf.so.3 -z noexecstack \
  -L"$SYSROOT/usr/lib" -L"$SYSROOT/usr/lib/webkit-gtk" -L"$SYSROOT/lib" \
  -nostdlib "$TMP/kpp_start.o" "$TMP/kpp_page_capture.o" \
  -l:libgtk-x11-2.0.so.0 -l:libwebkitgtk-1.0.so.0 \
  -l:libgobject-2.0.so.0 -l:libglib-2.0.so.0 \
  -l:libc.so.6 -l:libgcc_s.so.1
chmod 755 "$OUT"
echo "Built $OUT"
echo "This experimental helper has not been runtime-tested on a Kindle."
