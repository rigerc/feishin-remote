#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../website"
for file in playing.webp library.webp queue.webp tour.mp4 tour-poster.webp; do
  if [[ ! -s "public/media/$file" ]]; then
    echo "Missing public/media/$file. Run tool/media.sh before building the site." >&2
    exit 1
  fi
done
npm ci --no-audit --no-fund
npm run build
for file in index.html privacy/index.html support/index.html media/tour.mp4; do
  test -s "dist/$file"
done
