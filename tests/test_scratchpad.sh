#!/usr/bin/env bash
# shellcheck disable=SC2016  # regexes and stubs with a literal $
# shellcheck disable=SC2329  # wm_running, exists, shown and hidden run through until_
# dwm's scratchpads. First config.h: each scratchpad's command starts st with
# the instance name its rule matches, the rule floats it on its own tag, and
# the keys toggle the right one. Then, where Xvfb and xdotool are (CI
# installs them), the built dwm and st on a virtual screen: Alt+` and Alt+N
# show their scratchpad centered and hide it again, and Alt+0 leaves a hidden
# one hidden.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
config=$ROOT/suckless/dwm/config.h

# the scratchpads, in order: name and command array
mapfile -t pads < <(sed -n '/^static Sp scratchpads\[\] = {/,/^};/s/^\t{ "\([a-z]*\)", *\([a-z]*\) },.*/\1 \2/p' "$config")
expect "two scratchpads" 2 "${#pads[@]}"
for i in "${!pads[@]}"; do
    read -r name cmd <<<"${pads[i]}"
    cmdline=$(sed -n "/^static const char \*${cmd}\[\] = /,/NULL };/p" "$config" | tr -d '\n\t')
    expect_match "$name: its command starts st as instance $name" "st(\", \"| )-n(\", \"| )${name}[\" ]" "$cmdline"
    expect_match "$name: a rule floats instance $name on its own tag" \
        "^[[:space:]]*\{ NULL, +\"$name\", *NULL, +SPTAG\($i\), +1, " "$(grep -F "\"$name\"," "$config" | grep SPTAG)"
done
expect_match "Alt+\` toggles the terminal" "XK_grave, +togglescratch, +\{\.ui = 0 \}" "$(cat "$config")"
expect_match "Alt+N toggles the notes" "MODKEY, +XK_n, +togglescratch, +\{\.ui = 1 \}" "$(cat "$config")"
expect_match "the notes are Neovim on ~/notes.md" 'nvim \\"\$HOME/notes\.md\\"' "$(sed -n '/spnotescmd\[\] = /,/NULL };/p' "$config")"
expect_match "Alt+0 views every tag but the scratchpads" "XK_0, +view, +\{\.ui = ~SPTAGMASK \}" "$(cat "$config")"
expect_match "scratchpads take 0.6 of the screen" "^static const float spfact = 0\.6;" "$(cat "$config")"

# the live part needs X tools, and dwm and st built (tests/build.sh)
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
# the notes scratchpad runs nvim in st: a stand-in that just stays open
stub nvim 'exec sleep 120'
export HOME=$T/home PATH="$T/bin:$PATH" DISPLAY=:$((100 + RANDOM % 400))
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
xvfb=$!
dwm=
trap 'kill $dwm $xvfb 2>/dev/null; wait 2>/dev/null; rm -rf "$T"' EXIT

# until_ SECONDS COMMAND...: retry COMMAND every 0.1 s
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

# win NAME: the window of the scratchpad whose instance is NAME
win() { xdotool search --classname "^$1\$" 2>/dev/null | head -n1; }
exists() { [[ -n $(win "$1") ]]; }
# geometry NAME: sets X, Y, WIDTH and HEIGHT
geometry() { eval "$(xdotool getwindowgeometry --shell "$(win "$1")")"; }
shown() { geometry "$1" && ((X >= 0)); }
hidden() { geometry "$1" && ((X < 0)); }
# centered NAME: in the middle of the 1280x800 screen, across and (the bar
# above shifting it a little) down, at spfact (0.6) of it: 768 across, and
# about 470 of the height under the bar
centered() {
    geometry "$1"
    local cx=$((X + WIDTH / 2)) cy=$((Y + HEIGHT / 2))
    ((cx >= 638 && cx <= 642 && cy >= 395 && cy <= 430 &&
        WIDTH >= 760 && WIDTH <= 776 && HEIGHT >= 440 && HEIGHT <= 490))
}
key() { xdotool key "$1"; }

key alt+grave
if until_ 15 exists spterm; then pass "Alt+\`: starts the terminal scratchpad"; else fail "Alt+\`: no terminal scratchpad"; finish; fi
until_ 5 shown spterm
expect "Alt+\`: it floats in the middle of the screen" yes "$(centered spterm && echo yes || echo "no, at ${X},${Y} ${WIDTH}x${HEIGHT}")"
expect "Alt+\`: it has the focus" "$(win spterm)" "$(xdotool getactivewindow 2>/dev/null)"
key alt+grave
expect "Alt+\` again: hidden" yes "$(until_ 5 hidden spterm && echo yes)"
key alt+grave
expect "and again: shown, centered" yes "$(until_ 5 shown spterm; centered spterm && echo yes || echo "no, at ${X},${Y} ${WIDTH}x${HEIGHT}")"
expect "the same window, not a second terminal" 1 "$(xdotool search --classname '^spterm$' | wc -l)"

key alt+n
if until_ 15 exists spnotes; then pass "Alt+N: starts the notes scratchpad"; else fail "Alt+N: no notes scratchpad"; finish; fi
expect "Alt+N: centered too" yes "$(until_ 5 shown spnotes; centered spnotes && echo yes || echo "no, at ${X},${Y} ${WIDTH}x${HEIGHT}")"
key alt+n
expect "Alt+N again: the notes hidden" yes "$(until_ 5 hidden spnotes && echo yes)"
expect "the terminal still shown" yes "$(shown spterm && echo yes)"

key alt+grave
until_ 5 hidden spterm
key alt+0
sleep 0.5
expect "Alt+0: the scratchpads stay hidden" yes "$(hidden spterm && hidden spnotes && echo yes)"

finish
