#!/usr/bin/env bash
# shellcheck disable=SC2329  # the functions run through until_
# Window swallowing: a graphical program started from st takes the
# terminal's place until it closes. First config.h: st is the terminal, and
# the scratchpads' and fdwm-theme-menu's st are not. Then, where Xvfb,
# xdotool and xprop are (CI installs them), the built dwm and st on a
# virtual screen, with tests/xwin.c as the graphical program: it opens
# where its terminal was and has the focus, the terminal off the screen;
# closing it brings the terminal back; a floating one (a fixed size) opens
# on its own; started from a scratchpad it opens on its own too; a restart
# (Alt+Shift+W) keeps it in the terminal's place; dwm carries on when the
# terminal goes away under it; and a program moved to another tag takes its
# hidden terminal along, as their EWMH desktops say, through a restart and
# until it closes and the terminal comes back there.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
config=$ROOT/suckless/dwm/config.h

rules=$(sed -n '/^static const Rule rules\[\] = {/,/^ *};/p' "$config")
expect_match "st (class st-256color) is a terminal" '^[[:space:]]*\{ "st-256color", +NULL, +NULL, +0, +0, +1, +0, +-1 \},' "$rules"
for name in spterm spnotes fdwm-theme; do
    expect_match "$name, a later rule, isn't one" "^[[:space:]]*\{ NULL, +\"$name\", *NULL, +[^,]+, +1, +0, +0, +-1 \}," "$rules"
done
expect "st's rule comes before them" 1 "$(grep -E '"(st-256color|spterm|spnotes|fdwm-theme)",' <<<"$rules" | head -n1 | grep -c '"st-256color",')"
expect_match "a floating window doesn't swallow" '^static const int swallowfloating += 0;' "$(cat "$config")"

missing=
for c in Xvfb xdotool xprop cc; do command -v "$c" >/dev/null || missing+=" $c"; done
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
if ! cc -o "$T/bin/xwin" "$ROOT/tests/xwin.c" -lX11 2>"$T/xwin.log"; then
    fail "can't build tests/xwin.c: $(cat "$T/xwin.log")"
    finish
fi
export HOME=$T/home PATH="$T/bin:$PATH" DISPLAY=:$((100 + RANDOM % 400))
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
xvfb=$!
dwm='' pids=()
trap 'kill "${pids[@]}" $dwm $xvfb 2>/dev/null; wait 2>/dev/null; rm -rf "$T"' EXIT

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

win() { xdotool search --name "^$1\$" 2>/dev/null | head -n1; }
has_window() { [[ -n $(win "$1") ]]; }
gone() { [[ -z $(win "$1") ]]; }
# at NAME: the window's place, "X Y WxH", from outside dwm's border
at() {
    local X Y WIDTH HEIGHT
    eval "$(xdotool getwindowgeometry --shell "$(win "$1")" 2>/dev/null)"
    echo "$X $Y ${WIDTH}x$HEIGHT"
}
at_is() { [[ $(at "$1") == "$2" ]]; }
shown() { [[ $(at "$1") != -* ]]; }
offscreen() { [[ $(at "$1") == -* ]]; }
focused() { xdotool getwindowname "$(xdotool getactivewindow 2>/dev/null)" 2>/dev/null; }
focused_is() { [[ $(focused) == "$1" ]]; }
# focus NAME: the pointer onto the window, which focuses it in dwm
focus() {
    xdotool mousemove --window "$(win "$1")" 20 20
    until_ 5 focused_is "$1" || fail "can't focus $1"
}
# term TITLE COMMAND: st titled TITLE, running COMMAND in sh
term() {
    st -t "$1" -e sh -c "$2" &
    pids+=($!)
    until_ 15 has_window "$1" || fail "no terminal $1"
}

term one 'exec sleep 600'
term term 'xwin child; exec sleep 600'
until_ 15 has_window child || { fail "xwin didn't start from st: $(cat "$T/dwm.log")"; finish; }
until_ 5 offscreen term
expect "the program started from st takes its place, where the terminal was" yes "$(until_ 5 shown child && echo yes)"
expect "the terminal is off the screen" yes "$(offscreen term && echo yes)"
expect "the program has the focus" child "$(until_ 5 focused_is child; focused)"
childat=$(at child)
expect "one, the master, is where it was" yes "$(shown one && echo yes)"

key() { xdotool key "$1"; }
key alt+q
until_ 5 gone child || fail "Alt+Q didn't close the program"
expect "closed: the terminal is back in its place" "$childat" "$(until_ 5 at_is term "$childat"; at term)"
expect "and has the focus" term "$(until_ 5 focused_is term; focused)"

# a fixed size floats, and a floating window doesn't swallow
term termf 'xwin fixed fixed; exec sleep 600'
until_ 15 has_window fixed || fail "xwin fixed didn't start from st"
sleep 0.5
expect "a floating program opens on its own, its terminal stays" yes "$(shown termf && echo yes)"
expect "and it floats" yes "$(shown fixed && [[ $(at fixed) == *300x200 ]] && echo yes)"
key alt+q
until_ 5 gone fixed || fail "Alt+Q didn't close the floating program"
kill "${pids[-1]}"
until_ 5 gone termf

# a scratchpad's st isn't a terminal: what it starts opens on its own
key alt+grave
spterm() { xdotool search --classname '^spterm$' 2>/dev/null | head -n1; }
spterm_focused() { [[ -n $(spterm) && $(xdotool getactivewindow 2>/dev/null) == "$(spterm)" ]]; }
until_ 15 spterm_focused || fail "no scratchpad"
xdotool type --delay 20 "xwin pchild"
key Return
until_ 15 has_window pchild || fail "xwin didn't start from the scratchpad"
sleep 0.5
expect "from the scratchpad: the scratchpad stays" yes "$(geometry=$(xdotool getwindowgeometry --shell "$(spterm)"); eval "$geometry"; ((X >= 0)) && echo yes)"
expect "and the program is a window of its own" yes "$(shown pchild && echo yes)"
focus pchild
key alt+q
until_ 5 gone pchild
key alt+grave

# a restart keeps the program in its terminal's place (the order of the
# tiled windows may change, as it always could)
term term2 'xwin child2; exec sleep 600'
until_ 15 has_window child2 || fail "xwin didn't start from st"
until_ 5 offscreen term2
key alt+shift+w
sleep 1
until_ 10 wm_running || fail "dwm didn't restart: $(cat "$T/dwm.log")"
expect "after a restart, the program is still shown" yes "$(until_ 5 shown child2 && echo yes)"
expect "and its terminal still off the screen" yes "$(until_ 5 offscreen term2 && echo yes)"
expect "and the other two terminals shown" yes "$(shown one && shown term && echo yes)"
child2at=$(at child2)
focus child2
key alt+q
until_ 5 gone child2 || fail "Alt+Q didn't close the program"
expect "closed after the restart: the terminal is back" "$child2at" "$(until_ 5 at_is term2 "$child2at"; at term2)"

# the terminal gone under the program (it ignores the hangup): dwm carries on
term term3 'trap "" HUP; xwin child3; exec sleep 600'
until_ 15 has_window child3 || fail "xwin didn't start from st"
until_ 5 offscreen term3
kill "${pids[-1]}"
until_ 5 gone term3 || fail "the terminal didn't go"
sleep 0.5
expect "the terminal gone: dwm still runs" yes "$(kill -0 "$dwm" 2>/dev/null && wm_running && echo yes)"
expect "and the program is still shown" yes "$(shown child3 && echo yes)"
focus child3
key alt+q
until_ 5 gone child3 || fail "Alt+Q didn't close the program"
sleep 0.5
expect "closed, with no terminal to bring back: dwm still runs" yes "$(kill -0 "$dwm" 2>/dev/null && wm_running && echo yes)"

# the program moved to tag 4: its hidden terminal goes along, their
# _NET_WM_DESKTOP (EWMH) both 3, a restart keeps them there, and closed, the
# program leaves the terminal there
desktop() { xprop -id "$(win "$1")" _NET_WM_DESKTOP 2>/dev/null | sed -n 's/^[^=]* = //p'; }
desktop_is() { [[ $(desktop "$1") == "$2" ]]; }
term term4 'xwin child4; exec sleep 600'
until_ 15 has_window child4 || fail "xwin didn't start from st"
until_ 5 offscreen term4
expect "the program is on its terminal's desktop, 0" 0 "$(until_ 5 desktop_is child4 0; desktop child4)"
focus child4
key alt+shift+4
expect "Alt+Shift+4 moves it to desktop 3" 3 "$(until_ 5 desktop_is child4 3; desktop child4)"
expect "and its hidden terminal too" 3 "$(until_ 5 desktop_is term4 3; desktop term4)"
key alt+shift+w
sleep 1
until_ 10 wm_running || fail "dwm didn't restart: $(cat "$T/dwm.log")"
expect "after a restart, the program is still on desktop 3" 3 "$(until_ 5 desktop_is child4 3; desktop child4)"
expect "and still has its terminal, hidden, there too" "yes 3" "$(until_ 5 offscreen term4 && echo yes) $(desktop term4)"
key alt+4
until_ 5 shown child4
focus child4
key alt+q
until_ 5 gone child4 || fail "Alt+Q didn't close the program"
expect "closed: the terminal is back on tag 4" yes "$(until_ 5 shown term4 && echo yes)"
expect "and its desktop is 3" 3 "$(until_ 5 desktop_is term4 3; desktop term4)"

finish
