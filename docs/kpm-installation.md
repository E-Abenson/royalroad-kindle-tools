# Kindle installation

This is the first diagnostic-only release. It does not yet download a story or create an EPUB.

## One-time bootstrap

1. Download the bootstrap scriptlet from the latest GitHub Release:
   https://github.com/E-Abenson/royalroad-kindle-tools/releases/latest/download/Install-RoyalRoadTools.sh
2. Save it into the Kindle documents folder. The Kindle browser may be able to download it directly; otherwise copy this one small file over USB.
3. Open Install-RoyalRoadTools from the Kindle library. It calls KPM directly, adds this repository, refreshes the index, and installs the package. This direct call avoids the Kindle search-bar input filter that can reject URL punctuation.
4. The package installation hook attempts to add the Royal Road Session Test bookmark. Before changing the browser bookmark database it creates a timestamped local backup. It changes only the bookmark table.

The bootstrap writes its log to /mnt/us/documents/RoyalRoadTools-install.log. The browser bookmark helper writes its log to /mnt/us/documents/RoyalRoadTools.log.

## Run the browser test

1. Open a Royal Road chapter in the Kindle browser.
2. Open the browser bookmarks/favorites list and select Royal Road Session Test.
3. Read the alert. The diagnostic reports visible/returned chapter character counts, HTTP status, response size, final origin, and Cloudflare challenge markers. It does not transmit chapter text or browser credentials.

If the bookmark was not added during installation (for example, because the database was busy), open the RoyalRoadTools library item once. That runs the helper again. It is safe to run repeatedly: it detects the exact existing bookmark and does not add duplicates.

## Removal

Use ;kpm uninstall royalroad-kindle-tools. The uninstall hook backs up the browser database again, removes only this package's exact bookmark URL, and removes its library launcher. Existing backup files are retained.

## Current limitation

A successful same-origin fetch on one chapter does not prove that a complete chapter list can be read or that an entire story can be safely collected. The next stage is deliberately gated on this test result. If the browser receives a challenge, the project will stop rather than attempt to bypass it.
