#!/usr/bin/env bash
# shellcheck disable=SC2329  # the functions run through until_
# EWMH desktops: dwm tells other programs (an external bar, a pager,
# xdotool) about its tags as desktops, and takes their requests. The built
# dwm and st on a virtual screen (where Xvfb, xdotool and xprop are; CI
# installs them): the nine desktops and their names on the root window,
# _NET_CURRENT_DESKTOP following Alt+N, Alt+Ctrl+N and Alt+0, each window's
# _NET_WM_DESKTOP following Alt+Shift+N and Alt+Shift+0, xdotool switching
# tags and moving windows, and a scratchpad on no desktop at all.
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
# root PROP / prop WINDOW PROP: the property's value, as xprop prints it
# after " = ", or nothing when it isn't set
root() { xprop -root "$1" 2>/dev/null | sed -n 's/^[^=]* = //p'; }
prop() { xprop -id "$1" "$2" 2>/dev/null | sed -n 's/^[^=]* = //p'; }
# current: _NET_CURRENT_DESKTOP; desktop NAME: NAME's _NET_WM_DESKTOP
current() { root _NET_CURRENT_DESKTOP; }
desktop() { prop "$(win "$1")" _NET_WM_DESKTOP; }
is_current() { [[ $(current) == "$1" ]]; }
is_on() { [[ $(desktop "$1") == "$2" ]]; }
# shown / hidden NAME: dwm hides a window by moving it left of the screen
x_of() { eval "$(xdotool getwindowgeometry --shell "$(win "$1")")"; echo "$X"; }
shown() { (($(x_of "$1") >= 0)); }
hidden() { (($(x_of "$1") < 0)); }
# expect_current DESCRIPTION N: within 5 s _NET_CURRENT_DESKTOP is N
expect_current() {
    until_ 5 is_current "$2"
    expect "$1" "$2" "$(current)"
}
# expect_on DESCRIPTION NAME N: within 5 s NAME's _NET_WM_DESKTOP is N
expect_on() {
    until_ 5 is_on "$2" "$3"
    expect "$1" "$3" "$(desktop "$2")"
}

# the desktops, one per tag
supported=$(root _NET_SUPPORTED)
for atom in _NET_NUMBER_OF_DESKTOPS _NET_CURRENT_DESKTOP _NET_DESKTOP_NAMES _NET_DESKTOP_VIEWPORT _NET_WM_DESKTOP; do
    expect_match "_NET_SUPPORTED lists $atom" "(^|, )$atom(,|$)" "$supported"
done
expect "nine desktops, one per tag" 9 "$(root _NET_NUMBER_OF_DESKTOPS)"
expect "each named after its tag" '"1", "2", "3", "4", "5", "6", "7", "8", "9"' "$(root _NET_DESKTOP_NAMES)"
expect "every desktop at 0,0" "$(printf '0, %.0s' {1..17})0" "$(root _NET_DESKTOP_VIEWPORT)"
expect "at first desktop 0, tag 1" 0 "$(current)"

# a window's desktop: its tag
open a
expect_on "a window opened on tag 1 is on desktop 0" a 0
key alt+3
expect_current "Alt+3: desktop 2" 2
open b
expect_on "a window opened on tag 3 is on desktop 2" b 2
key alt+shift+5
expect_on "Alt+Shift+5 moves it to desktop 4" b 4
key alt+1
until_ 5 shown a
key alt+shift+0
expect_on "Alt+Shift+0 puts it on every tag: 0xFFFFFFFF" a 4294967295

# views of more than one tag: the lowest
key alt+5
expect_current "Alt+5: desktop 4" 4
key ctrl+alt+2
expect_current "Alt+Ctrl+2 adds tag 2: the lowest in view, desktop 1" 1
key ctrl+alt+2
expect_current "Alt+Ctrl+2 again takes it away: desktop 4" 4
key alt+0
expect_current "Alt+0, every tag: desktop 0" 0

# requests from other programs, here xdotool
xdotool set_desktop 6
expect_current "xdotool set_desktop 6: desktop 6" 6
open c
expect_on "a window opened there is on desktop 6" c 6
xdotool set_desktop_for_window "$(win c)" 7
expect_on "xdotool set_desktop_for_window: on desktop 7" c 7
expect "and hidden, as tag 8 isn't in view" yes "$(until_ 5 hidden c && echo yes)"
xdotool set_desktop 7
expect_current "xdotool set_desktop 7: desktop 7" 7
expect "where it shows" yes "$(until_ 5 shown c && echo yes)"
xdotool set_desktop 9
sleep 0.5
expect "xdotool set_desktop 9, past the last tag: nothing happens" 7 "$(current)"

# a scratchpad is on no desktop, and doesn't change the current one
key alt+grave
spterm() { xdotool search --classname '^spterm$' 2>/dev/null | head -n1; }
has_spterm() { [[ -n $(spterm) ]]; }
if until_ 15 has_spterm; then
    expect "the terminal scratchpad has no _NET_WM_DESKTOP" "" "$(prop "$(spterm)" _NET_WM_DESKTOP)"
    expect "showing it leaves the current desktop" 7 "$(current)"
    xdotool set_desktop_for_window "$(spterm)" 2
    sleep 0.5
    expect "xdotool can't move it to a desktop" "" "$(prop "$(spterm)" _NET_WM_DESKTOP)"
else
    fail "Alt+\`: no terminal scratchpad"
fi

finish
