#!/usr/bin/env bash
# shellcheck disable=SC2329  # the functions run through until_
# movestack: Alt+Shift+J / K move the focused window down / up the stack.
# First config.h: the two keys and their descriptions. Then, where Xvfb,
# xdotool and xprop are (CI installs them), the built dwm and st on a
# virtual screen with three tiled windows: each press swaps the focused
# window with its neighbour, wrapping at the ends, the focus staying on it;
# a floating window (a scratchpad) moves nothing.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
config=$ROOT/suckless/dwm/config.h

expect_match "Alt+Shift+J moves down the stack" 'MODKEY\|ShiftMask, +XK_j, +movestack, +\{\.i = \+1 \} \}, /\* windows: ' "$(cat "$config")"
expect_match "Alt+Shift+K moves up the stack" 'MODKEY\|ShiftMask, +XK_k, +movestack, +\{\.i = -1 \} \}, /\* windows: ' "$(cat "$config")"

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
# order: the three windows as the tiled layout shows them: the master (left),
# then the stack from the top
order() {
    local t
    for t in one two three; do
        eval "$(xdotool getwindowgeometry --shell "$(win "$t")")"
        echo "$X $Y $t"
    done | sort -n -k1,1 -k2,2 | awk '{ print $3 }' | paste -sd' '
}
order_is() { [[ $(order) == "$1" ]]; }
focused() { xdotool getwindowname "$(xdotool getactivewindow 2>/dev/null)" 2>/dev/null; }
# press KEY WANT DESCRIPTION: press KEY; within 5 s the order is WANT
press() {
    key "$1"
    until_ 5 order_is "$2"
    expect "$3" "$2" "$(order)"
}

open one
open two
open three
until_ 5 order_is "one two three"
expect "three windows, the newest at the bottom of the stack" "one two three" "$(order)"
expect "the newest has the focus" three "$(focused)"

press alt+shift+k "one three two" "Alt+Shift+K: three moves up, over two"
expect "the focus stays on it" three "$(focused)"
press alt+shift+k "three one two" "Alt+Shift+K again: three becomes the master"
press alt+shift+k "two one three" "Alt+Shift+K on the master: it swaps with the bottom one"
press alt+shift+j "three one two" "Alt+Shift+J from the bottom: it swaps with the master"
press alt+shift+j "one three two" "Alt+Shift+J: three moves down, under one"
expect "the focus is still on it" three "$(focused)"

# a scratchpad, focused and floating: nothing in the stack moves
spterm() { xdotool search --classname '^spterm$' 2>/dev/null | head -n1; }
has_spterm() { [[ -n $(spterm) ]]; }
spterm_focused() { [[ $(xdotool getactivewindow 2>/dev/null) == "$(spterm)" ]]; }
key alt+grave
until_ 15 has_spterm || fail "no scratchpad"
until_ 5 spterm_focused || fail "the scratchpad didn't get the focus"
# (each press checked on its own: a wrong J and K would undo each other)
key alt+shift+j
sleep 0.5
expect "a floating scratchpad focused, Alt+Shift+J: the stack stays as it was" "one three two" "$(order)"
key alt+shift+k
sleep 0.5
expect "and Alt+Shift+K: the stack stays as it was" "one three two" "$(order)"
key alt+grave

finish
