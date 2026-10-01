#!/usr/bin/env bash
# shellcheck disable=SC2329  # the functions run through until_
# pertag: each tag keeps its own layout, master area size (mfact), number of
# master windows (nmaster) and bar. The built dwm and st on a virtual screen
# (where Xvfb, xdotool and xprop are; CI installs them): three tags set up
# differently, then switched between with Alt+N, Alt+Tab, Alt+0 and
# Alt+Ctrl+N, each showing its own settings again, read off the windows'
# geometry and the bar's place.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox

missing=
for c in Xvfb xdotool xprop; do command -v "$c" >/dev/null || missing+=" $c"; done
[[ -x $ROOT/suckless/dwm/dwm && -x $ROOT/suckless/st/st ]] || missing+=" a built dwm and st"
if [[ -n $missing ]]; then
    if [[ ${CI:-} == true ]]; then
        fail "CI is missing:$missing"
    else
        echo "  skip  dwm on a virtual screen (missing:$missing)"
    fi
    finish
fi

mkdir -p "$T/bin" "$T/home"
ln -s "$ROOT/suckless/st/st" "$T/bin/st"
export HOME=$T/home PATH="$T/bin:$PATH" DISPLAY=:$((100 + RANDOM % 400))
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
xvfb=$!
dwm='' sts=()
trap 'kill "${sts[@]}" $dwm $xvfb 2>/dev/null; wait 2>/dev/null; rm -rf "$T"' EXIT

until_() {
    local n=$(($1 * 10))
    shift
    while ((n-- > 0)); do "$@" && return 0; sleep 0.1; done
    return 1
}
wm_running() { xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q 'window id'; }
until_ 10 xprop -root >/dev/null 2>&1 || { fail "Xvfb didn't start"; finish; }
"$ROOT/suckless/dwm/dwm" 2>"$T/dwm.log" &
dwm=$!
until_ 10 wm_running || { fail "dwm didn't start: $(cat "$T/dwm.log")"; finish; }
key() { xdotool key "$1"; }
win() { xdotool search --name "^$1\$" 2>/dev/null | head -n1; }
has_window() { [[ -n $(win "$1") ]]; }
open() {
    st -t "$1" &
    sts+=($!)
    until_ 15 has_window "$1" || fail "no window $1"
}
geom() { eval "$(xdotool getwindowgeometry --shell "$(win "$1")")"; echo "$X $Y $WIDTH $HEIGHT"; }

# What a tag with two windows A and B shows, as one word:
#   monocle  both the same, the whole screen
#   nmaster2 side by side no more: one above the other, both full width
#   tileN    master left, N = its share of the width in hundredths
layout_of() {
    local ax ay aw ah bx by bw bh
    read -r ax ay aw ah <<<"$(geom "$1")"
    read -r bx by bw bh <<<"$(geom "$2")"
    if ((ax == bx && ay == by && aw == bw && ah == bh)); then
        echo monocle
    elif ((ax == bx && aw == bw)); then
        echo nmaster2
    else
        # the master's width, gaps and borders back in, over the screen's
        echo "tile$(((aw + 24) * 100 / 1280))"
    fi
}
# bar: shown or hidden (dwm moves its window above the screen to hide it)
bar() {
    local id
    id=$(xdotool search --classname '^dwm$' 2>/dev/null | head -n1)
    eval "$(xdotool getwindowgeometry --shell "$id")"
    if ((Y >= 0)); then echo shown; else echo hidden; fi
}
is() { [[ $(layout_of "$1" "$2") == "$3" && $(bar) == "$4" ]]; }
bar_shown() { [[ $(bar) == shown ]]; }
# expect_tag DESCRIPTION A B LAYOUT BAR: within 5 s the windows A and B show
# LAYOUT, and the bar is BAR
expect_tag() {
    until_ 5 is "$2" "$3" "$4" "$5"
    expect "$1" "$4, bar $5" "$(layout_of "$2" "$3"), bar $(bar)"
}

# tag 1: the master area grown twice (0.55 to 0.65)
open a1
open a2
expect_tag "tag 1 at first: tiled, the master area 0.55" a1 a2 tile55 shown
key alt+l
key alt+l
expect_tag "tag 1: Alt+L twice grows the master area to 0.65" a1 a2 tile65 shown
# tag 2: monocle, and the bar hidden
key alt+2
open b1
open b2
expect_tag "tag 2 starts with the defaults, not tag 1's" b1 b2 tile55 shown
key alt+m
key alt+b
expect_tag "tag 2: monocle, bar hidden" b1 b2 monocle hidden
# tag 3: two windows in the master area
key alt+3
until_ 5 bar_shown
expect "tag 3: the bar back, as tag 3 has it" shown "$(bar)"
open c1
open c2
key alt+i
expect_tag "tag 3: Alt+I, two master windows" c1 c2 nmaster2 shown

key alt+1
expect_tag "back to tag 1: its master area, 0.65, and its bar" a1 a2 tile65 shown
key alt+2
expect_tag "back to tag 2: monocle, bar hidden" b1 b2 monocle hidden
key alt+3
expect_tag "back to tag 3: two master windows" c1 c2 nmaster2 shown
key alt+Tab
expect_tag "Alt+Tab: tag 2 again, with its settings" b1 b2 monocle hidden
key alt+Tab
expect_tag "Alt+Tab again: tag 3, with its settings" c1 c2 nmaster2 shown

# Alt+0, all nine tags: a view of its own, with the defaults
key alt+0
until_ 5 bar_shown
eval "$(xdotool getwindowgeometry --shell "$(win a1)")"
expect "Alt+0: the view of every tag has the defaults (bar shown, master 0.55)" "shown 55" "$(bar) $(((WIDTH + 24) * 100 / 1280))"
key alt+1
expect_tag "and back to tag 1: still 0.65" a1 a2 tile65 shown

# Alt+Ctrl+3 adds tag 3 to the view: the settings stay tag 1's, as it's
# still in view; taking tag 1 away hands them to tag 3
key ctrl+alt+3
sleep 0.5
eval "$(xdotool getwindowgeometry --shell "$(win a1)")"
expect "Alt+Ctrl+3 on tag 1: tag 1's master area stays" 65 "$(((WIDTH + 24) * 100 / 1280))"
key ctrl+alt+1
expect_tag "then Alt+Ctrl+1, leaving tag 3: tag 3's settings" c1 c2 nmaster2 shown

# the master area set the other two ways, each kept by the tag: Alt+Shift+R
# back to the default, and dragged with Alt and the right mouse button
key alt+1
expect_tag "tag 1 again" a1 a2 tile65 shown
key alt+shift+r
expect_tag "Alt+Shift+R: tag 1's master area back to 0.55" a1 a2 tile55 shown
key alt+2
key alt+1
expect_tag "kept after switching away and back" a1 a2 tile55 shown
eval "$(xdotool getwindowgeometry --shell "$(win a1)")"
xdotool mousemove $((X + 100)) $((Y + 100))
xdotool keydown alt mousedown 3
xdotool mousemove 960 400
sleep 0.3
xdotool mousemove 961 400 mouseup 3 keyup alt
# (the master's right edge follows the pointer: 0.75 of the width)
dragged() { [[ $(layout_of a1 a2) == tile7[0-9] ]]; }
until_ 5 dragged
expect_match "dragged with Alt+right button: the master area about 0.75" "^tile7[0-9]$" "$(layout_of a1 a2)"
was=$(layout_of a1 a2)
key alt+2
key alt+1
expect_tag "the dragged size kept after switching away and back" a1 a2 "$was" shown

finish
