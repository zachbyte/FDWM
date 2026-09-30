#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# fdwm-bar against a fake /sys and stubbed wpctl, xsetroot, systemctl and
# notify-send: what it shows, that "refresh" redraws at once, and the 10%
# warning and 3% suspend, each once per discharge.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
bar=$ROOT/dotfiles/.local/bin/fdwm-bar
bat=$T/sys/class/power_supply/BAT0
light=$T/sys/class/backlight/intel_backlight
export FDWM_SYS=$T/sys XDG_RUNTIME_DIR=$T/run VOL=$T/volume DRAWN=$T/drawn ACTIONS=$T/actions
mkdir -p "$bat" "$light" "$XDG_RUNTIME_DIR"
: >"$DRAWN" && : >"$ACTIONS"

set_battery() { echo "$1" >"$bat/capacity"; echo "$2" >"$bat/status"; }
set_battery 85 Discharging
echo 800 >"$light/brightness"
echo 1000 >"$light/max_brightness"
echo "Volume: 0.45" >"$VOL"

stub wpctl 'cat "$VOL"'
stub xsetroot '[ "$1" = -name ] && printf "%s\n" "$2" >>"$DRAWN"'
stub systemctl 'echo "systemctl $*" >>"$ACTIONS"'
stub notify-send 'echo "notify-send $*" >>"$ACTIONS"'
PATH="$T/bin:$PATH"

# print: the line itself
clock='󰃭  [0-9]{4}-[0-9]{2}-[0-9]{2}    [0-9]{2}:[0-9]{2} [AP]M$'
expect_match "shows volume, brightness, battery and the clock" "^󰖀  45%    󰃠  80%    󰂁  85%    $clock" "$("$bar" print)"
echo "Volume: 0.80 [MUTED]" >"$VOL"
expect_match "muted: shows the mute icon" "^󰝟  80%    " "$("$bar" print)"
echo "Volume: 0.10" >"$VOL"
set_battery 55 Charging
expect_match "quiet and charging: low-volume and charging icons" "^󰕿  10%    󰃠  80%    󰂄  55%    " "$("$bar" print)"
set_battery 2 Discharging
expect_match "print at 2%: shows the warning" "󰂃  2%  LOW BATTERY, PLUG IN" "$("$bar" print)"
expect "print never warns or suspends" "" "$(cat "$ACTIONS")"
mv "$T/sys" "$T/sys.away"
expect_match "no battery or backlight (a desktop): just volume and clock" "^󰕿  10%    $clock" "$("$bar" print)"
mv "$T/sys.away" "$T/sys"

# the running bar
set_battery 85 Discharging
echo "Volume: 0.45" >"$VOL"
draws() { wc -l <"$DRAWN" | tr -d ' '; }
last() { tail -1 "$DRAWN"; }
# until N_TRIES CONDITION...: retry the condition every 0.1 s
until_() { local n=$1; shift; while ((n-- > 0)); do "$@" && return 0; sleep 0.1; done; return 1; }
drawn_more_than() { (($(draws) > $1)); }
refresh_and_wait() { local n; n=$(draws); "$bar" refresh; until_ 30 drawn_more_than "$n"; }

"$bar" &
barpid=$!
until_ 50 drawn_more_than 0
expect "starts and draws" yes "$( (($(draws) >= 1)) && echo yes)"
expect "writes its pid file" "$barpid" "$(cat "$T/run/fdwm-bar-$(id -u).pid" 2>/dev/null)"

echo "Volume: 0.90" >"$VOL"
if refresh_and_wait; then pass "refresh redraws within 3 s, not at the next minute"; else fail "refresh did not redraw within 3 s"; fi
expect_match "the redraw shows the new volume" "^󰕾  90%    " "$(last)"

set_battery 9 Discharging
refresh_and_wait
expect_match "10% or less: warns in the bar" "󰂃  9%  LOW BATTERY, PLUG IN" "$(last)"
expect "10% or less: notify-send hook called" 1 "$(grep -c '^notify-send -u critical Battery at 9%' "$ACTIONS")"
set_battery 8 Discharging
refresh_and_wait
expect "still low: hook not called again" 1 "$(grep -c '^notify-send' "$ACTIONS")"

set_battery 3 Discharging
refresh_and_wait
expect "3% or less: suspends" 1 "$(grep -c '^systemctl suspend' "$ACTIONS")"
refresh_and_wait
expect "still at 3%: doesn't suspend again" 1 "$(grep -c '^systemctl suspend' "$ACTIONS")"
set_battery 3 Charging
refresh_and_wait
expect_no_match "charging: warning gone" "LOW BATTERY" "$(last)"
set_battery 3 Discharging
refresh_and_wait
expect "unplugged again at 3%: warns again" 2 "$(grep -c '^notify-send' "$ACTIONS")"
expect "unplugged again at 3%: suspends again" 2 "$(grep -c '^systemctl suspend' "$ACTIONS")"

kill "$barpid"
wait "$barpid" 2>/dev/null
expect "on exit: removes its pid file" no "$([[ -e $T/run/fdwm-bar-$(id -u).pid ]] && echo yes || echo no)"

finish
