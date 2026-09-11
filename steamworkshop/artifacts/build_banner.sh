#!/usr/bin/env bash
# Builds the wide DUWS-T banner: wordmark centred on the topographic plate.
#
# The topo source is portrait; it is rotated 90 before fitting so a wide banner
# downscales it rather than enlarging it, which keeps the thin contour lines
# crisp. Contours carry no correct orientation and the grid stays orthogonal
# through a quarter turn, so nothing reads as rotated.
#
# The source contains pure-white contour lines. White type laid straight on it
# measures 1:1 where the two cross - invisible. Hence two defences: the plate is
# darkened, and a halo masked to the wordmark's own alpha sits under the type.
# The halo is deliberately wide and weak rather than tight and strong; a tight
# one reads as a stroke around the glyphs and fails to reach the bright contours
# sitting further out. Glyph edges stay hard - the halo is strictly behind.
#
# A version tag (DUWS_SUB) sits under the wordmark, folded into the mark layer
# before the halo is cut so it gets the same backing against the contours the
# wordmark relies on.
#
# Inputs default to the copies beside this script; override by env:
#   DUWS_FONT   fonts/Jost-var.ttf, or another Futura-class face
#   DUWS_TOPO   topo_background.jpg
#   DUWS_SUB    version tag under the wordmark (default v2.0; empty to omit)
#
# Shipped duws_t_banner.png was:  build_banner.sh out.png 0.60 55 ticks 32 35
#
# usage: build_banner.sh <out.png> [ink-frac] [darken-pct] [border none|rule|ticks]
#          [halo-sigma] [halo-strength]
# ink-frac is the wordmark's inked width as a fraction of banner width.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
F=${DUWS_FONT:-$DIR/fonts/Jost-var.ttf}
BG=${DUWS_TOPO:-$DIR/topo_background.jpg}
for p in "$F" "$BG"; do
  [ -r "$p" ] || { echo "missing input: $p (set DUWS_FONT / DUWS_TOPO)" >&2; exit 1; }
done

OUT=$1; FRAC=${2:-0.60}; DARK=${3:-55}; BORDER=${4:-ticks}; GSIG=${5:-32}; GLVL=${6:-35}
SUB=${DUWS_SUB-v2.0}
W=952; H=322
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
py () { python3 -c "print($1)"; }

convert "$BG" -rotate 90 -resize ${W}x${H}^ -gravity center -extent ${W}x${H} \
        -fill "#060B12" -colorize ${DARK}% "$T/bg.png"

SC=$(py "$FRAC*$W/902")                      # 902 = wordmark inked width at scale 1
PS=$(py "248.57*$SC"); K=$(py "9.6*$SC"); CAP=$(py "175*$SC")
bbox () { convert -size ${W}x${H} xc:none -font "$F" -pointsize "$PS" -kerning "$K" \
          -fill white -annotate +0+200 "$1" -format "%@" info:; }
xof () { echo "$1" | sed 's/.*+\([0-9]*\)+.*/\1/'; }
wof () { echo "$1" | sed 's/x.*//'; }
FUL=$(bbox 'DUWS-T'); PRE=$(bbox 'DUWS-'); TEE=$(bbox 'T')
IW=$(wof "$FUL")
OX=$(py "round(($W-$IW)/2-$(xof "$FUL"))")
CUT=$(py "round($OX+($(xof "$PRE")+$(wof "$PRE")+$(xof "$FUL")+$IW-$(wof "$TEE"))/2)")

# Empty tag collapses the block back to the wordmark alone, recovering the
# original (H+CAP)/2 centre.
if [ -n "$SUB" ]; then
  SPS=$(py "round($PS*0.18)"); SK=$(py "round($SPS*0.15)")
  SCAP=$(py "0.7035*$SPS"); GAP=$(py "round($SPS*0.55)")
else
  SPS=0; SK=0; SCAP=0; GAP=0
fi
CTOP=$(py "($H-($CAP+$GAP+$SCAP))/2")
BY=$(py "round($CTOP+$CAP)")
SBASE=$(py "round($CTOP+$CAP+$GAP+$SCAP)")
if [ -n "$SUB" ]; then
  SBB=$(convert -size ${W}x${H} xc:none -font "$F" -pointsize "$SPS" -kerning "$SK" \
        -fill white -annotate +0+200 "$SUB" -format "%@" info:)
  SOX=$(py "round(($W-$(wof "$SBB"))/2-$(xof "$SBB"))")
fi
echo "banner ${W}x${H} ps=$PS ink_w=$IW x=$OX base=$BY tag='$SUB' tag_base=$SBASE"

convert -size ${W}x${H} xc:none -font "$F" -pointsize "$PS" -kerning "$K" \
        -fill white     -annotate +"${OX}"+"${BY}" "DUWS-T" "$T/white.png"
convert -size ${W}x${H} xc:none -font "$F" -pointsize "$PS" -kerning "$K" \
        -fill "#EE4027" -annotate +"${OX}"+"${BY}" "DUWS-T" "$T/red.png"
convert -size ${W}x${H} xc:black -fill white -draw "rectangle $CUT,0 ${W},${H}" "$T/cut.png"
convert "$T/white.png" "$T/red.png" "$T/cut.png" -composite "$T/mark.png"
if [ -n "$SUB" ]; then
  convert "$T/mark.png" -font "$F" -pointsize "$SPS" -kerning "$SK" \
          -fill "#E2E8EE" -annotate +"${SOX}"+"${SBASE}" "$SUB" "$T/mark.png"
fi

if [ "$GSIG" != "0" ]; then
  convert "$T/mark.png" -alpha extract -blur 0x"${GSIG}" -level 0%,"${GLVL}"% "$T/halo_a.png"
  convert -size ${W}x${H} xc:"#02060B" "$T/halo_a.png" \
          -alpha off -compose CopyOpacity -composite "$T/halo.png"
  convert "$T/bg.png" "$T/halo.png" -composite "$T/mark.png" -composite "$T/flat.png"
else
  convert "$T/bg.png" "$T/mark.png" -composite "$T/flat.png"
fi

case "$BORDER" in
  none) cp "$T/flat.png" "$OUT" ;;
  rule) convert "$T/flat.png" -fill none \
          -stroke "#7C8794" -strokewidth 2 -draw "rectangle 1,1 $((W-2)),$((H-2))" \
          -stroke "#3E4854" -strokewidth 1 -draw "rectangle 10,10 $((W-11)),$((H-11))" \
          "$OUT" ;;
  ticks) K=26
        convert "$T/flat.png" -fill none \
          -stroke "#7C8794" -strokewidth 2 -draw "rectangle 1,1 $((W-2)),$((H-2))" \
          -stroke "#8A96A3" -strokewidth 2 \
          -draw "line 10,10 $((10+K)),10"          -draw "line 10,10 10,$((10+K))" \
          -draw "line $((W-11)),10 $((W-11-K)),10" -draw "line $((W-11)),10 $((W-11)),$((10+K))" \
          -draw "line 10,$((H-11)) $((10+K)),$((H-11))" -draw "line 10,$((H-11)) 10,$((H-11-K))" \
          -draw "line $((W-11)),$((H-11)) $((W-11-K)),$((H-11))" \
          -draw "line $((W-11)),$((H-11)) $((W-11)),$((H-11-K))" \
          "$OUT" ;;
  *) echo "unknown border: $BORDER" >&2; exit 1 ;;
esac
