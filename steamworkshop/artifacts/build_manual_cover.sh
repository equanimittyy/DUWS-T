#!/usr/bin/env bash
# Front cover for the in-game manual: the v2.0 announcement shot with the wordmark
# kept and the "v2.0 Update / Warfare Redefined" caption removed.
#
# The caption sits on open sky, so it is painted out by vertically stretching the
# clean sky band between the wordmark baseline and the caption over the caption's
# box. Source and target share the same columns, so the sky gradient lines up with
# no seam. Working from the graded composite (DUWS-T-v2.png), not the raw plate,
# keeps the wordmark and the shot's colour grade byte-identical - the plate is
# ungraded and would not match.
#
# usage: build_manual_cover.sh [src.png] [out.jpg]
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC=${1:-$DIR/DUWS-T-v2.png}
OUT=${2:-$DIR/../../src/image/duws_t_man_cover.jpg}
[ -r "$SRC" ] || { echo "missing source: $SRC" >&2; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

convert "$SRC" -crop 470x26+238+205 +repage "$T/strip.png"
convert "$T/strip.png" -resize 470x130\! "$T/fill.png"
convert "$SRC" "$T/fill.png" -geometry +238+230 -compose over -composite \
        -quality 92 "$OUT"
identify -format "  cover %wx%h -> $OUT\n" "$OUT"
