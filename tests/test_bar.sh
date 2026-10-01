#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# fdwm-bar against a fake /sys and stubbed wpctl, xsetroot, systemctl,
# notify-send, pactl and udevadm: what it shows, that "refresh" redraws at
# once, as do pactl's volume events and udevadm's power supply events, and
# nothing else of theirs; the 10% warning and 3% suspend, each once per
# discharge; and that the watchers go with the bar, however it ends.
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
# notify-send: prints id 42 when asked (-p), or fails when $NO_DUNST is set,
# as it does with no notification daemon running
stub notify-send '
[ -f "$NO_DUNST" ] && exit 1
echo "notify-send $*" >>"$ACTIONS"
[ "$1" = -p ] && echo 42
exit 0'
export NO_DUNST=$T/no-dunst
# pactl subscribe and udevadm monitor: each prints the lines appended to its
# events file from when it starts. They ignore SIGPIPE and write errors, as
# pactl may, so a watcher whose bar is gone only stops if the bar's side
# stops it.
export PACTL_EVENTS=$T/pactl-events UDEV_EVENTS=$T/udev-events
: >"$PACTL_EVENTS" && : >"$UDEV_EVENTS"
for watcher in "pactl subscribe PACTL_EVENTS" "udevadm monitor UDEV_EVENTS"; do
    read -r name arg file <<<"$watcher"
    stub "$name" '[ "$1" = '"$arg"' ] || exit 1
trap "" PIPE
n=$(wc -l <"$'"$file"'")
while :; do
    now=$(wc -l <"$'"$file"'")
    [ "$now" -gt "$n" ] && tail -n +$((n + 1)) "$'"$file"'" 2>/dev/null
    n=$now
    sleep 0.1
done'
done
PATH="$T/bin:$PATH"

# print: the line itself
clock='󰃭  [0-9]{4}-[0-9]{2}-[0-9]{2}      [0-9]{2}:[0-9]{2} [AP]M$'
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
# shellcheck disable=SC2329  # called through until_
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
expect "10% or less: a critical notification through dunst" 1 \
    "$(grep -c '^notify-send -p -a fdwm-bar -u critical Battery at 9%' "$ACTIONS")"
set_battery 8 Discharging
refresh_and_wait
expect "still low: not notified again" 1 "$(grep -c '^notify-send' "$ACTIONS")"

set_battery 3 Discharging
refresh_and_wait
expect "3% or less: suspends" 1 "$(grep -c '^systemctl suspend' "$ACTIONS")"
refresh_and_wait
expect "still at 3%: doesn't suspend again" 1 "$(grep -c '^systemctl suspend' "$ACTIONS")"
set_battery 3 Charging
refresh_and_wait
expect_no_match "charging: warning gone" "LOW BATTERY" "$(last)"
expect "charging: the warning notification replaced, for 3 s" \
    "notify-send -r 42 -a fdwm-bar -t 3000 Battery at 3% Charging" "$(tail -1 "$ACTIONS")"
refresh_and_wait
expect "still charging: not replaced again" 1 "$(grep -c '^notify-send -r' "$ACTIONS")"
set_battery 3 Discharging
refresh_and_wait
expect "unplugged again at 3%: warns again" 2 "$(grep -c '^notify-send .*-u critical' "$ACTIONS")"
expect "unplugged again at 3%: suspends again" 2 "$(grep -c '^systemctl suspend' "$ACTIONS")"

# with no notification daemon notify-send fails: the bar still warns, and
# neither retries every minute nor replaces anything on plugging in
set_battery 50 Charging
refresh_and_wait
: >"$ACTIONS" && touch "$NO_DUNST"
set_battery 9 Discharging
refresh_and_wait
expect_match "no dunst: warns in the bar" "󰂃  9%  LOW BATTERY, PLUG IN" "$(last)"
rm "$NO_DUNST"
refresh_and_wait
set_battery 20 Charging
refresh_and_wait
expect "no dunst: nothing retried or replaced" "" "$(cat "$ACTIONS")"

# pactl's and udevadm's events. Away from the minute's turn, when the bar
# redraws anyway, so a redraw within these few seconds is the event's.
away_from_minute() { while ((10#$(date +%S) >= 50)); do sleep 1; done; }
# event FILE LINE: append LINE to the events FILE and wait up to 3 s for a
# redraw
event_and_wait() { local n; n=$(draws); echo "$2" >>"$1"; until_ 30 drawn_more_than "$n"; }
away_from_minute
echo "Volume: 0.30" >"$VOL"
if event_and_wait "$PACTL_EVENTS" "Event 'change' on sink #56"; then
    pass "pactl: a sink's volume changed elsewhere: redraws within 3 s"
else
    fail "pactl: a sink's volume changed elsewhere: no redraw within 3 s"
fi
expect_match "the redraw shows the new volume" "^󰖀  30%    " "$(last)"
echo "Volume: 0.35" >"$VOL"
if event_and_wait "$PACTL_EVENTS" "Event 'change' on server #-1"; then
    pass "pactl: the default sink changed: redraws within 3 s"
else
    fail "pactl: the default sink changed: no redraw within 3 s"
fi
n=$(draws)
printf '%s\n' "Event 'new' on sink-input #12" "Event 'change' on client #7" "Event 'remove' on source-output #3" >>"$PACTL_EVENTS"
printf '%s\n' "monitor will print the received events for:" "UDEV - the event which udev sends out after rule processing" >>"$UDEV_EVENTS"
sleep 1.5
expect "other pactl events, and udevadm's header, don't redraw" "$n" "$(draws)"
set_battery 85 Charging
if event_and_wait "$UDEV_EVENTS" "UDEV  [5123.456789] change   /devices/LNXSYSTM:00/LNXSYBUS:00/ACPI0003:00/power_supply/AC (power_supply)"; then
    pass "udevadm: a charger plugged in: redraws within 3 s"
else
    fail "udevadm: a charger plugged in: no redraw within 3 s"
fi
expect_match "the redraw shows the battery charging" "    󰂄  85%    " "$(last)"

# leftovers: the bar, its two watchers ("fdwm-bar watch ...") and their
# loops (which run as the watchers too), and the stubbed pactl and udevadm,
# if any are still running; "no pgrep" without pgrep, so that the checks
# below fail rather than count nothing
leftovers() {
    command -v pgrep >/dev/null || { echo "no pgrep"; return; }
    { pgrep -f " $bar( |\$)" || true; pgrep -f "$T/bin/(pactl|udevadm)" || true; } | wc -l | tr -d ' '
}
# shellcheck disable=SC2329  # called through until_
none_left() { [[ $(leftovers) == 0 ]]; }
# shellcheck disable=SC2329  # called through until_
all_running() { [[ $(leftovers) == 7 ]]; }
expect "running: the bar, two watchers, their loops, pactl and udevadm" 7 "$(leftovers)"

# PipeWire restarting: pactl ends, and the watcher starts a new one (after
# 2 s), which still redraws the bar
pactl_pid() { pgrep -f "$T/bin/pactl" | head -n1; }
first=$(pactl_pid)
kill "$first"
# shellcheck disable=SC2329  # called through until_
new_pactl() { local p; p=$(pactl_pid); [[ -n $p && $p != "$first" ]]; }
if until_ 60 new_pactl; then
    pass "pactl ended: a new one within 6 s"
else
    fail "pactl ended: no new one within 6 s"
fi
until_ 30 all_running
expect "and nothing else started twice" 7 "$(leftovers)"
away_from_minute
echo "Volume: 0.40" >"$VOL"
if event_and_wait "$PACTL_EVENTS" "Event 'change' on sink #57"; then
    pass "the new pactl's events redraw the bar"
else
    fail "the new pactl's events don't redraw the bar"
fi
expect_match "and show the new volume" "^󰖀  40%    " "$(last)"

kill "$barpid"
wait "$barpid" 2>/dev/null
expect "on exit: removes its pid file" no "$([[ -e $T/run/fdwm-bar-$(id -u).pid ]] && echo yes || echo no)"
until_ 20 none_left
expect "killed (TERM, as pkill does): no watcher left" 0 "$(leftovers)"

# logging out: xinit hangs up on the session (HUP)
"$bar" &
barpid=$!
until_ 30 all_running
kill -HUP "$barpid"
wait "$barpid" 2>/dev/null
until_ 20 none_left
expect "hung up (HUP, as at logout): no watcher left" 0 "$(leftovers)"

# killed outright, so its exit can't run: each watcher, finding the bar gone
# at its command's next event, stops it and itself
"$bar" &
barpid=$!
until_ 30 all_running
kill -KILL "$barpid"
wait "$barpid" 2>/dev/null
echo "Event 'change' on sink #56" >>"$PACTL_EVENTS"
echo "UDEV  [5124.0] change   /devices/LNXSYSTM:00/LNXSYBUS:00/ACPI0003:00/power_supply/AC (power_supply)" >>"$UDEV_EVENTS"
until_ 30 none_left
expect "killed outright (kill -9): the watchers go at their next event" 0 "$(leftovers)"

finish
