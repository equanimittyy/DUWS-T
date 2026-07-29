#!/usr/bin/env bash
# Lays the DUWS-T wordmark and a subtitle block over an untitled screenshot.
#
# Geometry is duws_t_title_overlay.svg's, mapped from its 2560-wide coordinate
# space onto a 1920 frame (x0.75); the scale arguments multiply that. Jost is the
# stand-in for Futura BT, which is not redistributable - at the SVG's spec Jost
# reproduces its cap height and inked width to within 0.3%, so swapping the face
# invalidates every constant below.
#
# Inputs (override by env; none are in-repo, see the notes at the foot of this file):
#   DUWS_FONT   Jost-var.ttf, or another Futura-class face
#   DUWS_PLATE  the untitled screenshot to letter
#
# Shipped DUWS-T-v2.png was:
#   build_promo_screenshot.sh out.png 0.64 0.588 0.30 50 20 181 10 \
#     "v2.0 Update|Warfare Redefined" l 20
#
# usage: build_promo_screenshot.sh <out.png> <wm-scale> <sub-scale> [vignette]
#          [shift-x] [shift-y] [sub-dx] [sub-dy] [subtitle] [align l|r] [sub-step]
# subtitle takes '|'-separated lines. sub-dx/sub-dy are signed offsets from the
# wordmark (+x right, +y down); sub-step indents each successive line when align=l.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
F=${DUWS_FONT:-$DIR/fonts/Jost-var.ttf}
SRC=${DUWS_PLATE:-$DIR/plate.png}
for p in "$F" "$SRC"; do
  [ -r "$p" ] || { echo "missing input: $p (set DUWS_FONT / DUWS_PLATE)" >&2; exit 1; }
done

OUT=$1; SW=$2; SS=$3; VIG=${4:-0.30}; SHIFTX=${5:-0}; SHIFTY=${6:-0}
SUBDX=${7:-0}; SUBDY=${8:-0}; SUBTEXT=${9:-"v2.0 Update"}; ALIGN=${10:-r}; SUBSTEP=${11:-0}
W=1920; H=1080
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
py () { python3 -c "print($1)"; }

ANCHOR_X=$(py "35+$SHIFTX"); ANCHOR_Y=$(py "61+$SHIFTY")   # wordmark ink-left / cap-top

PSW=$(py "248.57*$SW"); KW=$(py "9.6*$SW"); CAP=$(py "175*$SW")
PSS=$(py "82*$SS");     KS=$(py "2.46*$SS"); ASC=$(py "65*$SS")
GAP=$(py "48*$SW")      # wordmark baseline -> subtitle ascender top; tracks the wordmark

bbox () { convert -size ${W}x${H} xc:none -font "$F" -pointsize "$2" -kerning "$3" \
          -fill white -annotate +0+500 "$1" -format "%@" info:; }
xof () { echo "$1" | sed 's/.*+\([0-9]*\)+.*/\1/'; }
wof () { echo "$1" | sed 's/x.*//'; }

BY=$(py "round($ANCHOR_Y+$CAP)")
PRE=$(bbox 'DUWS-' "$PSW" "$KW"); FUL=$(bbox 'DUWS-T' "$PSW" "$KW"); TEE=$(bbox 'T' "$PSW" "$KW")
OX=$(py "round($ANCHOR_X-$(xof "$FUL"))")
# split point between the hyphen and the T, so one render can carry two colours
CUT=$(py "round($OX+($(xof "$PRE")+$(wof "$PRE")+$(xof "$FUL")+$(wof "$FUL")-$(wof "$TEE"))/2)")
SB=$(py "round($BY+$GAP+$ASC+$SUBDY)")
RIGHT=$(py "$ANCHOR_X+$(wof "$FUL")+$SUBDX")
LEFT=$(py "$ANCHOR_X+$SUBDX")
LEAD=$(py "1.05*$PSS")
echo "wm  ps=$PSW base=$BY x=$OX cut=$CUT ink_w=$(py "round(902*$SW)")"

convert -size ${W}x${H} xc:none -font "$F" -pointsize "$PSW" -kerning "$KW" \
        -fill white     -annotate +"${OX}"+"${BY}" "DUWS-T" "$T/white.png"
convert -size ${W}x${H} xc:none -font "$F" -pointsize "$PSW" -kerning "$KW" \
        -fill "#EE4027" -annotate +"${OX}"+"${BY}" "DUWS-T" "$T/red.png"
convert -size ${W}x${H} xc:black -fill white -draw "rectangle $CUT,0 ${W},${H}" "$T/cut.png"
convert "$T/white.png" "$T/red.png" "$T/cut.png" -composite "$T/wordmark.png"

convert -size ${W}x${H} xc:none "$T/sub.png"
i=0
while IFS= read -r LINE; do
  [ -n "$LINE" ] || continue
  B=$(bbox "$LINE" "$PSS" "$KS")
  if [ "$ALIGN" = "l" ]; then LX=$(py "round($LEFT+$i*$SUBSTEP-$(xof "$B"))")
  else LX=$(py "round($RIGHT-$(xof "$B")-$(wof "$B"))"); fi
  LY=$(py "round($SB+$i*$LEAD)")
  echo "sub[$i] '$LINE' x=$LX base=$LY w=$(wof "$B")"
  convert "$T/sub.png" -font "$F" -pointsize "$PSS" -kerning "$KS" \
          -fill white -annotate +"${LX}"+"${LY}" "$LINE" "$T/sub.png"
  i=$((i+1))
done <<EOF
$(echo "$SUBTEXT" | tr '|' '\n')
EOF

if [ "$VIG" != "0" ]; then
  # the SVG's own ramp: alpha = VIG * r^2, r in half-diagonals from frame centre.
  # Rendered small and scaled up because -fx is per-pixel and the ramp is smooth.
  convert -size 480x270 xc: \
    -fx "$VIG*(((i/479-0.5)*1920)^2+((j/269-0.5)*1080)^2)/1213200" \
    -resize ${W}x${H}\! "$T/vig_a.png"
  convert -size ${W}x${H} xc:black "$T/vig_a.png" \
    -alpha off -compose CopyOpacity -composite "$T/vig.png"
  convert "$T/vig.png" -write mpr:v +delete "$SRC" mpr:v -composite "$T/base.png"
else cp "$SRC" "$T/base.png"; fi

convert "$T/base.png" "$T/wordmark.png" -composite "$T/sub.png" -composite "$OUT"

# The untitled plate is not in the worktree - HEAD's DUWS-T-v2.png is the lettered
# result. Recover one with:  git show <commit>:steamworkshop/artifacts/DUWS-T-v2.png
# from any revision before the wordmark was applied.
