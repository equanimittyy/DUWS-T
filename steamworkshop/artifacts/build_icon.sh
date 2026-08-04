#!/usr/bin/env bash
# Builds the square DUWS-T icon: the banner's wordmark centred on a square plate.
#
# Composition, colours, halo and corner ticks are build_banner.sh's, so the two
# read as one set; only the aspect and the wordmark's share of the width differ.
# The ink runs wider here (0.82 vs the banner's 0.60) because a square gives the
# single line no vertical company - held at the banner's fraction the type sits
# marooned in the middle of the plate.
#
# Border weight, tick length and inset are derived from the icon's size rather
# than fixed, so a 256 or 128 build keeps the banner's proportions instead of
# thinning to hairlines.
#
# The halo is why white type survives here: the topo source has pure-white
# contour lines that unhaloed white glyphs measure 1:1 against. See
# build_banner.sh for the halo's shape and why it is wide and weak.
#
# Inputs default to the copies beside this script; override by env:
#   DUWS_FONT   fonts/Jost-var.ttf, or another Futura-class face
#   DUWS_TOPO   topo_background.jpg
#
# Shipped duws_t_icon.png was:  build_icon.sh out.png 512 0.82 55 32 35
#
# usage: build_icon.sh <out.png> [size] [ink-frac] [darken-pct] [halo-sigma]
#          [halo-strength]
# ink-frac is the wordmark's inked width as a fraction of the icon's width.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
F=${DUWS_FONT:-$DIR/fonts/Jost-var.ttf}
BG=${DUWS_TOPO:-$DIR/topo_background.jpg}
for p in "$F" "$BG"; do
  [ -r "$p" ] || { echo "missing input: $p (set DUWS_FONT / DUWS_TOPO)" >&2; exit 1; }
done

OUT=$1; S=${2:-512}; FRAC=${3:-0.82}; DARK=${4:-55}; GSIG=${5:-32}; GLVL=${6:-35}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
py () { python3 -c "print($1)"; }

convert "$BG" -rotate 90 -resize ${S}x${S}^ -gravity center -extent ${S}x${S} \
        -fill "#060B12" -colorize ${DARK}% "$T/bg.png"

SC=$(py "$FRAC*$S/902")                      # 902 = wordmark inked width at scale 1
PS=$(py "248.57*$SC"); K=$(py "9.6*$SC"); CAP=$(py "175*$SC")
bbox () { convert -size ${S}x${S} xc:none -font "$F" -pointsize "$PS" -kerning "$K" \
          -fill white -annotate +0+"$((S/2))" "$1" -format "%@" info:; }
xof () { echo "$1" | sed 's/.*+\([0-9]*\)+.*/\1/'; }
wof () { echo "$1" | sed 's/x.*//'; }
FUL=$(bbox 'DUWS-T'); PRE=$(bbox 'DUWS-'); TEE=$(bbox 'T')
IW=$(wof "$FUL")
OX=$(py "round(($S-$IW)/2-$(xof "$FUL"))")
BY=$(py "round(($S+$CAP)/2)")
CUT=$(py "round($OX+($(xof "$PRE")+$(wof "$PRE")+$(xof "$FUL")+$IW-$(wof "$TEE"))/2)")
echo "icon ${S}x${S} ps=$PS ink_w=$IW x=$OX base=$BY"

convert -size ${S}x${S} xc:none -font "$F" -pointsize "$PS" -kerning "$K" \
        -fill white     -annotate +"${OX}"+"${BY}" "DUWS-T" "$T/white.png"
convert -size ${S}x${S} xc:none -font "$F" -pointsize "$PS" -kerning "$K" \
        -fill "#EE4027" -annotate +"${OX}"+"${BY}" "DUWS-T" "$T/red.png"
convert -size ${S}x${S} xc:black -fill white -draw "rectangle $CUT,0 ${S},${S}" "$T/cut.png"
convert "$T/white.png" "$T/red.png" "$T/cut.png" -composite "$T/mark.png"

convert "$T/mark.png" -alpha extract -blur 0x"${GSIG}" -level 0%,"${GLVL}"% "$T/halo_a.png"
convert -size ${S}x${S} xc:"#02060B" "$T/halo_a.png" \
        -alpha off -compose CopyOpacity -composite "$T/halo.png"
convert "$T/bg.png" "$T/halo.png" -composite "$T/mark.png" -composite "$T/flat.png"

BW=$(py "max(2,round($S/171))"); IN=$(py "round($S/32)"); TK=$(py "round($S/12)")
FAR=$(py "$S-1-$IN")
convert "$T/flat.png" -fill none \
  -stroke "#7C8794" -strokewidth $BW \
  -draw "rectangle $((BW/2)),$((BW/2)) $((S-1-BW/2)),$((S-1-BW/2))" \
  -stroke "#8A96A3" -strokewidth $BW \
  -draw "line $IN,$IN $((IN+TK)),$IN"     -draw "line $IN,$IN $IN,$((IN+TK))" \
  -draw "line $FAR,$IN $((FAR-TK)),$IN"   -draw "line $FAR,$IN $FAR,$((IN+TK))" \
  -draw "line $IN,$FAR $((IN+TK)),$FAR"   -draw "line $IN,$FAR $IN,$((FAR-TK))" \
  -draw "line $FAR,$FAR $((FAR-TK)),$FAR" -draw "line $FAR,$FAR $FAR,$((FAR-TK))" \
  "$OUT"
