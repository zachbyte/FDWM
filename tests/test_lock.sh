#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# fdwm-lock with slock, xprintidle, systemctl and sleep stubbed: it runs
# slock, suspends only after 10 minutes without input while still locked,
# again after each 5 more, starts over after any input, and exits with
# slock once you unlock.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
lock=$ROOT/dotfiles/.local/bin/fdwm-lock
export LOG=$T/log IDLES=$T/idles IDLE=$T/idle LOCKED=$T/locked
REAL_SLEEP=$(command -v sleep)
export REAL_SLEEP

# slock: stays up until $LOCKED goes, then exits with $SLOCK_RC
stub slock 'echo slock >>"$LOG"; while [ -e "$LOCKED" ]; do "$REAL_SLEEP" 0.01; done; exit "${SLOCK_RC:-0}"'
# sleep: each call moves X's idle time to the next line of $IDLES; with
# none left, you unlock
stub sleep '
v=$(head -n1 "$IDLES")
if [ -z "$v" ]; then rm -f "$LOCKED"; exec "$REAL_SLEEP" 1; fi
sed -i 1d "$IDLES"
echo "$v" >"$IDLE"'
stub xprintidle 'cat "$IDLE"'
stub systemctl 'echo "systemctl $* at $(cat "$IDLE")" >>"$LOG"'
PATH="$T/bin:$PATH"

# locked IDLE...: lock while X's idle time steps through IDLE... (ms), then
# unlock; sets $rc and $ran
locked() {
    : >"$LOG" && : >"$LOCKED" && echo 0 >"$IDLE"
    printf '%s\n' "$@" >"$IDLES"
    timeout 20 sh "$lock"
    rc=$?
    ran=$(cat "$LOG")
}

locked 300000 400000 599000
expect "unlocked before 10 minutes: slock, no suspend" "slock" "$ran"
expect "exits with slock's status" 0 "$rc"

locked 300000 585000 600000 615000 630000
expect "10 minutes without input: suspends once" \
    "$(printf 'slock\nsystemctl suspend at 600000')" "$ran"

locked 300000 600000 615000 899000 900000
expect "still untouched 5 minutes after waking: suspends again" \
    "$(printf 'slock\nsystemctl suspend at 600000\nsystemctl suspend at 900000')" "$ran"

locked 300000 600000 5000 300000 599000 600000
expect "a key or the mouse after waking: 10 more minutes before the next" \
    "$(printf 'slock\nsystemctl suspend at 600000\nsystemctl suspend at 600000')" "$ran"

locked 300000 500000 2000 300000 500000
expect "typing at the lock screen: no suspend" "slock" "$ran"

SLOCK_RC=1 locked
expect "slock failing: its status" 1 "$rc"

finish
