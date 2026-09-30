#!/usr/bin/env bash
# Every color is written down once, in palette: no other file in the repo
# may spell one out. Caught: any #rgb or #rrggbb; any palette color (every
# flavor) as bare hex, or in decimal as red;green;blue or red,green,blue;
# console palette escapes (\e]P<n><rrggbb>); vt.default_* lists; and
# 256-color escapes. The generated files are ignored by git, so not checked.
# The samples it checks itself with are built from the palette as it runs,
# so this file spells out no color either.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox

# the checkout's own git, read only (safe.directory: CI runs the tests as a
# user who doesn't own the checkout)
repo() { git -c safe.directory="$ROOT" -C "$ROOT" "$@"; }

# every color in the palette, from every flavor's column
mapfile -t hexes < <(sed 's/#.*//' "$ROOT/palette" |
    awk 'NF && $1 != "name" { for (i = 2; i <= NF; i++) if ($i ~ /^[0-9a-f]+$/ && length($i) == 6) print $i }' | sort -u)
expect "read the palette's colors (so this checks something)" yes "$( ((${#hexes[@]} >= 26)) && echo yes)"

bare=() dec=()
for h in "${hexes[@]}"; do
    bare+=("$h")
    dec+=("$((16#${h:0:2}))[;,] ?$((16#${h:2:2}))[;,] ?$((16#${h:4:2}))")
done
join() { local IFS='|'; echo "$*"; }
patterns=(
    '(^|[^[:alnum:]_&])#([[:xdigit:]]{3}|[[:xdigit:]]{6}|[[:xdigit:]]{8})([^[:alnum:]_]|$)'
    "(^|[^[:alnum:]_])($(join "${bare[@]}"))([^[:alnum:]_]|\$)"
    "(^|[^0-9])($(join "${dec[@]}"))([^0-9]|\$)"
    '\]P[[:xdigit:]][[:xdigit:]]{6}'
    'vt\.default_(red|grn|blu)=[0-9]'
    '\[[34]8;5;[0-9]'
)
re=$(join "${patterns[@]}")

# spelled FILE...: file:line:match for each color spelled out in them
spelled() { grep -HnoIiE -- "$re" "$@"; }

# first, that it catches what it should, and nothing it shouldn't
h=${hexes[0]}
r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))
caught=(
    "#$h" "#${h^^}" "$(printf '#%06d' 0)" "#""fff" "color: $h;"
    "printf '\\e]P0$h'" "38;2;$r;$g;$b" "rgb($r, $g, $b)"
    "vt.default_red=$r,$g" '\e[38;5;'"$r"'m'
)
missed=()
for s in "${caught[@]}"; do
    printf 'x %s x\n' "$s" >"$T/sample"
    spelled "$T/sample" >/dev/null || missed+=("$s")
done
expect "catches each kind of color" "" "${missed[*]}"
flagged=()
for s in '#define COL_BASE' "sha256 04d5${h}e8f9" 'colors#256,' 'fdwm_base' "${r}px" '# a comment'; do
    printf 'x %s x\n' "$s" >"$T/sample"
    spelled "$T/sample" >/dev/null && flagged+=("$s")
done
expect "leaves alone what isn't a color" "" "${flagged[*]}"

# then the repo: every file git tracks, and new ones it doesn't ignore
mapfile -t files < <(repo ls-files -co --exclude-standard | grep -vx palette)
existing=()
for f in "${files[@]}"; do [[ -f $ROOT/$f ]] && existing+=("$f"); done
expect "found the repo's files (so this checks something)" yes "$( ((${#existing[@]} > 50)) && echo yes)"
found=$(cd "$ROOT" && spelled "${existing[@]}")
if [[ -z $found ]]; then
    pass "no file but palette spells out a color"
else
    fail "colors spelled out outside palette (use the palette's names instead):"
    while read -r line; do printf '        %s\n' "$line"; done <<<"$found"
fi

finish
