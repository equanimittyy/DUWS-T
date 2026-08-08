#!/usr/bin/env bash
# Builds a solid heading strip for the in-game DUWS-T manual (map Notes / diary).
#
# Same visual family as the Workshop sub-banners (build_sub_banner.sh): darkened
# topo plate, off-white Jost title, thin grey border. The one departure is the
# alpha fade - the diary renders each header as a self-contained page banner
# rather than a run-on strip against a page, so the plate stays fully opaque and
# long titles run the full width instead of dissolving out from under the text.
#
# Inputs default to the copies beside this script; override by env:
#   DUWS_FONT   fonts/Jost-var.ttf, or another Futura-class face
#   DUWS_TOPO   topo_background.jpg
#
# usage: build_manual_banner.sh <out.png> <title> [height] [darken-pct] [pointsize]
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
F=${DUWS_FONT:-$DIR/fonts/Jost-var.ttf}
BG=${DUWS_TOPO:-$DIR/topo_background.jpg}
for p in "$F" "$BG"; do
  [ -r "$p" ] || { echo "missing input: $p (set DUWS_FONT / DUWS_TOPO)" >&2; exit 1; }
done

OUT=$1; TITLE=$2; H=${3:-100}; DARK=${4:-60}; PS=${5:-45}
# W clears the longest title ("System, Options & Configuration") with room to spare,
# so the diary's max render width never clips its tail; the shorter PS just widens
# the right margin.
W=886; TX=85; K=2                            # TX matches the sub-banner's text inset
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
py () { python3 -c "print($1)"; }
CAP=$(py "0.7035*$PS"); TBASE=$(py "round(($H+$CAP)/2)")   # optically centred on cap height

# Build lossless, encode $OUT once - lets it emit .jpg for the diary without
# recompressing through each intermediate step.
convert "$BG" -rotate 90 -resize ${W}x${H}^ -gravity center -extent ${W}x${H} \
        -fill "#060B12" -colorize ${DARK}% "$T/b.png"
convert "$T/b.png" -fill none -stroke "#7F8B99" -strokewidth 2 \
        -draw "rectangle 1,1 $((W-2)),$((H-2))" "$T/b.png"
convert "$T/b.png" -font "$F" -pointsize "$PS" -kerning "$K" \
        -fill "#E2E8EE" -annotate +"${TX}"+"${TBASE}" "$TITLE" -quality 92 "$OUT"
identify -format "  %wx%h base=$TBASE '$TITLE'\n" "$OUT"
