#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mode=${1:-all}
case "$mode" in all|screenshots|video) ;; *) echo "Usage: $0 [all|screenshots|video]" >&2; exit 2 ;; esac
command -v ffmpeg >/dev/null
flutter_bin=$(command -v flutter)
font_dir=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().parents[1] / "bin/cache/artifacts/material_fonts")' "$flutter_bin")
output=$(mktemp -d)
trap 'rm -rf "$output"' EXIT
mkdir -p "$output/frames" "$output/web" build/media website/public/media
flutter test --no-pub tool/capture_test.dart \
  --dart-define="MEDIA_MODE=$mode" \
  --dart-define="MEDIA_OUTPUT=$output" \
  --dart-define="MEDIA_FONTS=$font_dir"

if [[ "$mode" != video ]]; then
  for scene in playing library queue; do
    ffmpeg -hide_banner -loglevel error -i "$output/$scene.png" -frames:v 1 -c:v libwebp -quality 85 "$output/web/$scene.webp"
  done
  cp "$output/playing.png" "$output/library.png" "$output/queue.png" build/media/
  cp "$output/web/playing.webp" "$output/web/library.webp" "$output/web/queue.webp" website/public/media/
fi
if [[ "$mode" != screenshots ]]; then
  ffmpeg -hide_banner -loglevel error -framerate 30 -i "$output/frames/%04d.png" \
    -vf scale=600:-2 -c:v libx264 -crf 22 -pix_fmt yuv420p -movflags +faststart -an "$output/web/tour.mp4"
  ffmpeg -hide_banner -loglevel error -i "$output/frames/0000.png" \
    -vf scale=600:-2 -frames:v 1 -c:v libwebp -quality 85 "$output/web/tour-poster.webp"
  cp "$output/web/tour.mp4" "$output/web/tour-poster.webp" build/media/
  cp "$output/web/tour.mp4" "$output/web/tour-poster.webp" website/public/media/
fi
echo "Media available in build/media and website/public/media."
