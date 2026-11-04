#!/bin/sh
ROOT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
if [ ! -x "$ROOT/tools/add-browser-bookmark.sh" ]; then
  echo "Bookmark installer is missing."
  exit 1
fi
sh "$ROOT/tools/add-browser-bookmark.sh"
