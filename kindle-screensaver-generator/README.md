# Rabbi Kindle Screensavers

This isolated branch contains a small GitHub Actions job that downloads two
photographs and prepares portrait-format grayscale PNGs for a Kindle.

## Output
- 1072 x 1448 pixels
- PNG, 8-bit grayscale
- Portrait crop, mild contrast/brightness adjustment and restrained sharpening
- No text, frames or added graphics

## Run
The workflow runs automatically when this branch is pushed. The finished ZIP
is uploaded as the Actions artifact named **rabbinic-kindle-screensavers**.
It can also be rerun manually once the workflow is available in the repository's
default branch.

## Sources
- Rav Zvi Kushelevsky: Wikimedia Commons, original 3549 x 4724 photograph
  by Yzfreeman, CC BY-SA 4.0.
- Rav Osher Arieli: Agudath Israel Vimeo recording, with Malchei Rabbanan
  event photographs listed as retrieval fallbacks.

The source and processing manifest is included with the output files.
