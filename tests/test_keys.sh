#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# keys.awk, the list of dwm's keys install.sh writes for fdwm-keys (Alt+/):
# every entry of keys[] and buttons[] in config.h, and every line of the
# TAGKEYS macro, has a "/* group: what it does */" and becomes a row; a line
# without one, or that isn't a key, stops it with that line's number. Then
# fdwm-keys, which shows the list in dmenu.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
config=$ROOT/suckless/dwm/config.h
awkfile=$ROOT/keys.awk

# the entries, counted here without keys.awk: the lines starting with "{" in
# keys[] and buttons[], the TAGKEYS macro's four, and the TAGKEYS uses
section() { sed -n "/^static const $1 $2\\[\\] = {/,/^};/p" "$config"; }
keys=$(section Key keys | grep -E '^[[:space:]]*\{')
buttons=$(section Button buttons | grep -E '^[[:space:]]*\{')
macro=$(sed -n '/^#define TAGKEYS(/,/[^\\]$/p' "$config" | grep -E '^[[:space:]]*\{')
nkeys=$(grep -c . <<<"$keys") nbuttons=$(grep -c . <<<"$buttons") nmacro=$(grep -c . <<<"$macro")
expect "found keys[], buttons[] and TAGKEYS's four" yes "$( ((nkeys > 30 && nbuttons > 5 && nmacro == 4)) && echo yes)"
expect "nine TAGKEYS, for tags 1 to 9" 9 "$(section Key keys | grep -c '^[[:space:]]*TAGKEYS(')"
described='/\* (windows|tags|layouts|apps|system): [^*]+ \*/( \\)?$'
expect "every key has a description" "" "$(grep -vE "$described" <<<"$keys")"
expect "every mouse button has a description" "" "$(grep -vE "$described" <<<"$buttons")"
expect "every TAGKEYS line has a description" "" "$(grep -vE "$described" <<<"$macro")"

if list=$(awk -f "$awkfile" "$config" 2>"$T/err"); then
    pass "keys.awk reads config.h"
else
    fail "keys.awk can't read config.h: $(cat "$T/err")"
fi
expect "one row per key, button and TAGKEYS line" $((nkeys + nbuttons + nmacro)) "$(grep -c . <<<"$list")"
expect "every row in a known group" "" "$(grep -vE '^(windows|tags|layouts|apps|system) ' <<<"$list")"
expect "the groups in order: windows, tags, layouts, apps, system" "windows tags layouts apps system" \
    "$(awk '{ print $1 }' <<<"$list" | uniq | paste -sd' ')"
row() { grep -E "^$1 +$2 +$3\$" <<<"$list" >/dev/null && echo yes; }
expect "Alt+X: open a terminal" yes "$(row apps 'Alt\+X' 'open a terminal \(st\)')"
expect "Alt+Shift+Space: float or tile" yes "$(row windows 'Alt\+Shift\+Space' 'float or tile the focused window')"
expect "the tag keys, one row: Alt+1-9" yes "$(row tags 'Alt\+1-9' 'view the tag')"
expect "and Alt+Ctrl+Shift+1-9" yes "$(row tags 'Alt\+Ctrl\+Shift\+1-9' 'put the focused window on the tag too')"
expect "a media key by name: Volume Up" yes "$(row system 'Volume Up' 'volume up')"
expect 'Alt+`: the terminal scratchpad' yes "$(row apps 'Alt\+`' 'show or hide the terminal scratchpad')"
expect "Alt+/: this list" yes "$(row system 'Alt\+/' 'these keys and buttons \(fdwm-keys\)')"
expect "a mouse button: Alt+Left click on a window" yes "$(row windows 'Alt\+Left click on a window' 'move the window')"
expect "a click without modifier: Middle click on the title" yes "$(row windows 'Middle click on the title' 'move the window to the master area')"

# broken BROKEN.h WHAT: keys.awk on a config.h with one line changed must fail
# and name that line
broken() {
    local n
    n=$(grep -nF -- "$2" "$1" | cut -d: -f1 | head -n1)
    [[ -n $n ]] || { fail "$3: the test's change made nothing different"; return; }
    if awk -f "$awkfile" "$1" >/dev/null 2>"$T/err"; then
        fail "$3: keys.awk didn't fail"
    else
        expect_match "$3: fails, naming line $n" "^$1:$n: " "$(cat "$T/err")"
    fi
}
sed 's| /\* windows: close the focused window \*/||' "$config" >"$T/a.h"
broken "$T/a.h" "XK_q,      killclient,     {0} }," "a key's description taken out"
sed 's| /\* tags: view the tag \*/$||' "$config" >"$T/b.h"
broken "$T/b.h" "Button1,        view,           {0} }," "a button's description taken out"
sed 's|/\* tags: view the tag too \*/ \\|\\|' "$config" >"$T/c.h"
broken "$T/c.h" "toggleview,     {.ui = 1 << TAG} }, \\" "a TAGKEYS line's description taken out"
sed 's|/\* apps: open a terminal (st) \*/$|/* programs: open a terminal (st) */|' "$config" >"$T/d.h"
broken "$T/d.h" "/* programs: " "a group that isn't one of the five"
sed 's#{ MODKEY,                       XK_b, #{ MODKEY|HyperMask,             XK_b, #' "$config" >"$T/e.h"
broken "$T/e.h" "HyperMask" "an unknown modifier"
sed 's|^\tTAGKEYS(                        XK_5,|\tTAGKEYZ(XK_5,|' "$config" >"$T/f.h"
broken "$T/f.h" "TAGKEYZ(" "a line in keys[] that isn't a key"

# fdwm-keys: shows the list in dmenu; without one, says so
mkdir -p "$T/home/.config/fdwm"
stub dmenu 'echo "dmenu $*" >"$T/dmenu.args"; cat >"$T/dmenu.in"'
stub notify-send 'echo "notify-send $*" >>"$T/notified"'
export T PATH="$T/bin:$PATH"
printf '%s\n' "$list" >"$T/home/.config/fdwm/keys"
HOME=$T/home "$ROOT/dotfiles/.local/bin/fdwm-keys"
expect "fdwm-keys: exits 0" 0 "$?"
expect "fdwm-keys: the list, as it is, in dmenu" "$list" "$(cat "$T/dmenu.in")"
expect "fdwm-keys: one per line, filtered as you type" "dmenu -i -l 20 -p keys" "$(cat "$T/dmenu.args")"
rm "$T/home/.config/fdwm/keys" "$T/dmenu.in"
out=$(HOME=$T/home "$ROOT/dotfiles/.local/bin/fdwm-keys" 2>&1)
expect "fdwm-keys, no list: exits 1" 1 "$?"
expect_match "fdwm-keys, no list: says install.sh writes it" "install.sh writes it" "$out"
expect_match "fdwm-keys, no list: as a notification too" "^notify-send -a fdwm-keys" "$(cat "$T/notified" 2>/dev/null)"
expect "fdwm-keys, no list: no dmenu" no "$([[ -e $T/dmenu.in ]] && echo yes || echo no)"

finish
