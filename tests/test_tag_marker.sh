#!/usr/bin/env bash
# shellcheck disable=SC2329  # the functions run through until_
# The tags' marks in dwm's bar. First config.h: the bar draws in col_fg
# (ui_text), the selected tag's underline in col_accent (ui_accent). Then,
# where Xvfb, xdotool, xprop, cc and make are (CI installs them), a dwm built
# here in the ThinkPad flavor, whose text (subtext1) and accent (red) differ,
# on a virtual screen: no tag has a square until it holds a window; the
# square is in the text color, filled while the focused window is on that
# tag and empty otherwise; scratchpads mark no tag; and the viewed tag keeps
# its underline in the accent.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
config=$ROOT/suckless/dwm/config.h

expect_match "the bar's color is ui_text" '^static const char col_fg\[\] = COL_UI_TEXT;' "$(cat "$config")"
expect_match "the accent is ui_accent" '^static const char col_accent\[\] = COL_UI_ACCENT;' "$(cat "$config")"
expect_match "SchemeNorm draws in col_fg" '\[SchemeNorm\] = \{ col_fg, ' "$(cat "$config")"
expect_match "SchemeSel draws in col_accent" '\[SchemeSel\]  = \{ col_accent, ' "$(cat "$config")"

# the live part needs X tools, a compiler for dwm and xpixels, and a built st
missing=
for c in Xvfb xdotool xprop cc make; do command -v "$c" >/dev/null || missing+=" $c"; done
[[ -x $ROOT/suckless/st/st ]] || missing+=" a built st"
if [[ -n $missing ]]; then
    if [[ ${CI:-} == true ]]; then
        fail "CI is missing:$missing"
    else
        echo "  skip  dwm on a virtual screen (missing:$missing)"
    fi
    finish
fi

# dwm in the ThinkPad flavor, from a copy of the repo (nothing is written
# into the checkout), and xpixels to read the screen
mkdir -p "$T/bin" "$T/home/.config/fdwm"
export HOME=$T/home
theme_repo "$T/repo"
cp -r "$ROOT/suckless/dwm" "$T/repo/suckless/"
echo thinkpad >"$HOME/.config/fdwm/flavor"
if ! { bash "$T/repo/fdwm-theme" generate && make -C "$T/repo/suckless/dwm" clean dwm; } >"$T/build.log" 2>&1; then
    fail "can't build dwm in the ThinkPad flavor: $(tail -5 "$T/build.log")"
    finish
fi
if ! cc -o "$T/xpixels" "$ROOT/tests/xpixels.c" -lX11 2>"$T/xpixels.log"; then
    fail "can't build tests/xpixels.c: $(cat "$T/xpixels.log")"
    finish
fi
# color NAME: the palette color colors.h gives COL_NAME, as rrggbb
color() { sed -n "s/^#define COL_$1 \"#\([0-9a-f]*\)\"$/\1/p" "$T/repo/suckless/colors.h"; }
text=$(color UI_TEXT) accent=$(color UI_ACCENT) base=$(color BASE)
expect "ThinkPad's text and accent differ, so the test can tell them apart" yes \
    "$([[ -n $text && -n $accent && $text != "$accent" ]] && echo yes)"

ln -s "$ROOT/suckless/st/st" "$T/bin/st"
export PATH="$T/bin:$PATH" DISPLAY=:$((100 + RANDOM % 400))
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
xvfb=$!
dwm='' sts=()
trap 'kill "${sts[@]}" $dwm $xvfb 2>/dev/null; wait 2>/dev/null; rm -rf "$T"' EXIT

# until_ SECONDS COMMAND...: retry COMMAND every 0.1 s
until_() {
    local n=$(($1 * 10))
    shift
    while ((n-- > 0)); do "$@" && return 0; sleep 0.1; done
    return 1
}
wm_running() { xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q 'window id'; }
until_ 10 xprop -root >/dev/null 2>&1 || { fail "Xvfb didn't start"; finish; }
"$T/repo/suckless/dwm/dwm" 2>"$T/dwm.log" &
dwm=$!
until_ 10 wm_running || { fail "dwm didn't start: $(cat "$T/dwm.log")"; finish; }
key() { xdotool key "$1"; }

# The bar's measures, as drawbar() takes them from the font's height, which
# is the bar's height less 2: the square is boxw across, boxs in from the
# tag's left edge and the bar's top, and the underline runs along the bar's
# bottom from boxw in from either edge.
bar=$(xdotool search --classname '^dwm$' 2>/dev/null | head -n1)
[[ -n $bar ]] || { fail "can't find dwm's bar"; finish; }
eval "$(xdotool getwindowgeometry --shell "$bar")"
bh=$HEIGHT barw=$WIDTH
fh=$((bh - 2))
boxs=$((fh / 9)) boxw=$((fh / 6 + 2))

# underline: the first pixel of the bar's bottom row that isn't the
# background, where the underline starts: sets under0 and undercolor
underline() {
    local row i
    read -ra row < <("$T/xpixels" 0 $((bh - 1)) "$barw" 1)
    under0=-1 undercolor=none
    for i in "${!row[@]}"; do
        if [[ ${row[i]} != "$base" ]]; then
            under0=$i undercolor=${row[i]}
            return 0
        fi
    done
    return 1
}
# underline_past X: the underline starts right of X
underline_past() { underline && ((under0 > $1)); }
# each tag's left edge: view it and step back boxw from its underline
left=() prev=-1 bad=
for n in {1..9}; do
    key "alt+$n"
    until_ 3 underline_past "$prev" || bad+=" $n:no-underline"
    prev=$under0
    left[n]=$((under0 - boxw))
    [[ $undercolor == "$accent" ]] || bad+=" $n:$undercolor"
done
expect "each tag, viewed, is underlined in the accent" "" "$bad"
expect "tag 1 starts at the bar's left edge" 0 "${left[1]}"
key alt+1

# square N: none, empty or filled, from tag N's square in the text color
square() {
    local px n=0 all
    all=$("$T/xpixels" $((left[$1] + boxs)) "$boxs" "$boxw" "$boxw")
    for px in $all; do [[ $px == "$text" ]] && n=$((n + 1)); done
    if ((n == 0)); then echo none
    elif ((n == boxw * boxw)); then echo filled
    elif ((n == 4 * (boxw - 1))); then echo empty
    else echo "$n of $((boxw * boxw)) pixels in the text color"
    fi
}
# squares: every tag's square, as "1:none 2:filled ..."
squares() {
    local n out=
    for n in {1..9}; do out+="$n:$(square "$n") "; done
    echo "${out% }"
}
# squares_are WANT: the squares are WANT, as squares prints them
squares_are() { [[ $(squares) == "$1" ]]; }
# expect_squares DESCRIPTION WANT: within 5 s, the squares are WANT (for
# tags 1-9, in order)
expect_squares() {
    local want n=1 w
    want=$(for w in $2; do printf '%s:%s ' $((n++)) "$w"; done)
    want=${want% }
    until_ 5 squares_are "$want"
    expect "$1" "$want" "$(squares)"
}
# has_window TITLE: a window with that title exists
has_window() { [[ -n $(xdotool search --name "^$1\$" 2>/dev/null) ]]; }
no_window() { ! has_window "$1"; }
# has_class INSTANCE: a window with that instance name exists
has_class() { [[ -n $(xdotool search --classname "^$1\$" 2>/dev/null) ]]; }
# open TITLE: an st window with that title, on the tag in view
open() {
    st -t "$1" &
    sts+=($!)
    until_ 15 has_window "$1" || fail "no window $1"
}

expect_squares "no windows: no tag has a square" "none none none none none none none none none"
open one
expect_squares "a window on tag 1, focused: tag 1's square, filled" "filled none none none none none none none none"
expect "the square is in the text color, not the accent" filled "$(square 1)"
underline
expect "tag 1 keeps its underline in the accent" "$accent at $boxw" "$undercolor at $under0"

key alt+shift+3
expect_squares "moved to tag 3, out of view: tag 3's square, empty" "none none empty none none none none none none"
key alt+3
expect_squares "viewing tag 3: its window focused, the square filled" "none none filled none none none none none none"

key alt+2
open two
expect_squares "a window on tag 2 too, focused: 2 filled, 3 empty" "none filled empty none none none none none none"

key alt+grave
until_ 15 has_class spterm || fail "no terminal scratchpad"
expect_squares "a scratchpad, focused: it marks no tag, 2 and 3 empty" "none empty empty none none none none none none"
key alt+grave

key alt+q
until_ 5 no_window two
expect_squares "tag 2's window closed: its square gone" "none none empty none none none none none none"

finish
