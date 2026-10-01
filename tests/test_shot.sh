#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# shellcheck disable=SC2154  # fdwm_* come from the generated colors.sh
# fdwm-shot with maim, xclip, notify-send and xdg-user-dir stubbed: a region
# outlined in the palette's accent, the whole screen, both saved and
# copied, and a cancelled region leaving nothing behind.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
shot=$ROOT/dotfiles/.local/bin/fdwm-shot
export HOME=$T/home LOG=$T/log
unset XDG_CONFIG_HOME
theme_repo "$T/repo"
bash "$T/repo/fdwm-theme" generate >/dev/null
# shellcheck source=/dev/null
. "$HOME/.config/fdwm/colors.sh"

# maim writes a file at its last argument, unless $CANCEL is set
stub maim '
echo "maim $*" >>"$LOG"
[ -n "${CANCEL:-}" ] && exit 1
for last; do :; done
echo png >"$last"'
stub xclip 'echo "xclip $*" >>"$LOG"'
stub notify-send 'echo "notify-send $*" >>"$LOG"'
stub xdg-user-dir '[ "$1" = PICTURES ] && echo "$HOME/Bilder"'
PATH="$T/bin:$PATH"
run() { : >"$LOG"; out=$(sh "$shot" "$@" 2>&1); rc=$?; }
name='[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}(-[0-9]+)?\.png'

run region
expect "region: exits 0" 0 "$rc"
expect_match "region: saved in the pictures folder's Screenshots" "^$HOME/Bilder/Screenshots/$name$" "$out"
expect "region: the file is there" yes "$([[ -s $out ]] && echo yes)"
accent=$(awk -v r=$((16#${fdwm_ui_accent:1:2})) -v g=$((16#${fdwm_ui_accent:3:2})) -v b=$((16#${fdwm_ui_accent:5:2})) \
    'BEGIN { printf "%.3f,%.3f,%.3f,1", r / 255, g / 255, b / 255 }')
expect "region: a selection outlined in the palette's accent, 2 px, no pointer" \
    "maim -u -s -b 2 -c $accent $out" "$(grep '^maim' "$LOG")"
expect "region: copied as a PNG" "xclip -selection clipboard -t image/png -i $out" "$(grep '^xclip' "$LOG")"
expect_match "region: says so" "^notify-send -a fdwm-shot .*Screenshot Copied, and saved to $out" "$(grep '^notify-send' "$LOG")"

run screen
expect "screen: the whole screen, no pointer" "maim -u $out" "$(grep '^maim' "$LOG")"
expect "screen: copied too" "xclip -selection clipboard -t image/png -i $out" "$(grep '^xclip' "$LOG")"

# two in the same second: the second gets -2, the first is kept
stub date "echo 2026-01-02_03-04-05"
run screen && first=$out
run screen
expect "the same second: a second name" "${first%.png}-2.png" "$out"
expect "the same second: both kept" 2 "$(find "$HOME/Bilder" -name '2026-01-02_03-04-05*' | wc -l)"

before=$(find "$HOME/Bilder" -type f | wc -l)
CANCEL=1 run region
expect "cancelled: exits 0, quietly" "0:" "$rc:$out"
expect "cancelled: nothing copied or said" "" "$(grep -v '^maim' "$LOG")"
expect "cancelled: no file left" "$before" "$(find "$HOME/Bilder" -type f | wc -l)"

# no pictures folder set up (xdg-user-dir fails) and no colors.sh yet
stub xdg-user-dir 'exit 1'
mv "$HOME/.config/fdwm/colors.sh" "$T/colors.sh"
run region
expect_match "no pictures folder: ~/Pictures/Screenshots" "^$HOME/Pictures/Screenshots/$name$" "$out"
expect_no_match "no colors.sh: maim's own outline color" " -c " "$(grep '^maim' "$LOG")"
mv "$T/colors.sh" "$HOME/.config/fdwm/colors.sh"

run window
expect "anything else: usage, exit 2" "2" "$rc"
expect_match "anything else: says how" "^usage: fdwm-shot region \| screen" "$out"

finish
