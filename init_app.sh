#!/usr/bin/env bash
#
# Generate the SQLite database and download the Pokémon images from PokeAPI.
#
# The Go generator writes ./pokemon.db and ./images relative to its working
# directory, so it runs inside init/ and the results are moved into src/.
# The artwork is then downscaled to 240x240 WebP (the watch screen is at most
# 454x454, the originals are 475x475 and ~129 MB in total) before being moved.
# Both paths are gitignored build inputs.
#
# Requires ImageMagick (magick or convert) for the image conversion.
#
# Usage: ./init_app.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m!!!\033[0m %s\n' "$*" >&2; exit 1; }

mkdir -p src/db
rm -rf init/images
mkdir -p init/images

cd init
# The generator appends to an existing database, so always start from scratch.
rm -f pokemon.db
go run main.go
cd ..

if command -v magick >/dev/null 2>&1; then
    IM=magick
elif command -v convert >/dev/null 2>&1; then
    IM=convert
else
    fail "ImageMagick (magick or convert) is required to resize the artwork"
fi

png_count=$(find init/images -name '*.png' | wc -l)
[ "$png_count" -gt 0 ] || fail "no images were downloaded"
info "Converting ${png_count} images to 240x240 WebP"
export IM
find init/images -name '*.png' -print0 | xargs -0 -P "$(nproc)" -n 1 sh -c \
    '"$IM" "$1" -resize 240x240 -strip -define webp:method=6 -quality 82 -define webp:alpha-quality=90 "${1%.png}.webp"' _

webp_count=$(find init/images -name '*.webp' | wc -l)
[ "$webp_count" -eq "$png_count" ] || fail "converted ${webp_count} of ${png_count} images"
find init/images -name '*.png' -delete

rm -rf src/db/pokemon.db src/images
mv init/pokemon.db src/db/
mv init/images src/

info "Generated src/db/pokemon.db and src/images ($(find src/images -type f | wc -l) files, $(du -sh src/images | cut -f1))"
