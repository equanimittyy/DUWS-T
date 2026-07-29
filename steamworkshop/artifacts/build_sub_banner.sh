#!/usr/bin/env bash
# Builds a section heading strip for the Workshop description.
#
# Deliberately subordinate to the main banner: smaller type, off-white rather
# than white, no red accent, no corner ticks, and a darker plate.
#
# The 2px outer border replaces the reference's separate top rule - at this
# height the two sit close enough to read as one doubled line.
#
# Background and border take the left-to-right alpha ramp; the title does not.
# The longest heading runs well past the point where the plate has faded, so
# fading the text with it would dissolve the last word. Left opaque, the title
# stays readable against the page while the plate dissolves out from under it.
#
# Inputs default to the copies beside this script; override by env:
#   DUWS_FONT   fonts/Jost-var.ttf, or another Futura-class face
#   DUWS_TOPO   topo_background.jpg
#
# Shipped strips were built with the defaults below, one per heading:
#   Features / How to Play / FAQ / Discussions & Community
#
# usage: build_sub_banner.sh <out.png> <title> [height] [darken-pct]
#          [plateau-frac] [pointsize]
# plateau-frac is the share of width held fully opaque before the ramp starts.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
F=${DUWS_FONT:-$DIR/fonts/Jost-var.ttf}
BG=${DUWS_TOPO:-$DIR/topo_background.jpg}
for p in "$F" "$BG"; do
  [ -r "$p" ] || { echo "missing input: $p (set DUWS_FONT / DUWS_TOPO)" >&2; exit 1; }
done

OUT=$1; TITLE=$2; H=${3:-100}; DARK=${4:-60}; PLAT=${5:-0.30}; PS=${6:-54}
W=950; TX=85; K=2                            # TX matches the reference's text inset
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
py () { python3 -c "print($1)"; }
PW=$(py "round($W*$PLAT)"); GW=$(py "$W-round($W*$PLAT)")
CAP=$(py "0.7035*$PS"); TBASE=$(py "round(($H+$CAP)/2)")   # optically centred on cap height

convert "$BG" -rotate 90 -resize ${W}x${H}^ -gravity center -extent ${W}x${H} \
        -fill "#060B12" -colorize ${DARK}% "$T/bg.png"
convert "$T/bg.png" -fill none -stroke "#7F8B99" -strokewidth 2 \
        -draw "rectangle 1,1 $((W-2)),$((H-2))" "$T/plate.png"

# gradient: runs top-to-bottom, so build it tall and rotate; appending a solid
# block to an unrotated gradient leaves a hard vertical seam at the join.
convert -size ${PW}x${H} xc:white \
        \( -size ${H}x${GW} gradient:white-black -rotate -90 \) \
        +append "$T/ramp.png"
convert "$T/plate.png" "$T/ramp.png" -alpha off -compose CopyOpacity -composite "$T/faded.png"

convert "$T/faded.png" -font "$F" -pointsize "$PS" -kerning "$K" \
        -fill "#E2E8EE" -annotate +"${TX}"+"${TBASE}" "$TITLE" "$OUT"
convert "$OUT" -format "  %wx%h base=$TBASE '$TITLE'\n" info:
