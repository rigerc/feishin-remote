#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../website"
for file in playing.webp library.webp queue.webp tour.mp4 tour-poster.webp; do
  if [[ ! -s "public/media/$file" ]]; then
    echo "Missing website/public/media/$file. Run tool/media.sh before building the site." >&2
    exit 1
  fi
done
pnpm install --frozen-lockfile
pnpm lint
pnpm check
pnpm test:run
pnpm build
pnpm check:site
pnpm verify
