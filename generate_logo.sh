#!/bin/bash
# Generates the rps_logo.png (Synthwave / Cyberpunk theme)
# Requires: ImageMagick 7+, VT323 font

FONT="${FONT:-$HOME/Library/Fonts/VT323-Regular.ttf}"
OUTPUT="${1:-rps_logo.png}"

magick -size 400x400 xc:'#0a0a1a' \
  -fill '#141428' -draw 'roundrectangle 20,40 380,370 14,14' \
  -fill '#1e1e3a' -draw 'roundrectangle 20,40 380,90 14,14' \
  -fill '#1e1e3a' -draw 'rectangle 20,75 380,90' \
  -fill '#ff2975' -draw 'circle 48,65 56,65' \
  -fill '#ffd319' -draw 'circle 78,65 86,65' \
  -fill '#00ff9f' -draw 'circle 108,65 116,65' \
  -font "$FONT" \
  -fill '#7b6f9e' -pointsize 140 -annotate +45+230 '$' \
  -fill '#ff2975' -pointsize 140 -annotate +115+230 'RPS' \
  -fill '#00ff9f' -draw 'rectangle 45,295 95,310' \
  "$OUTPUT"

echo "Generated $OUTPUT"
