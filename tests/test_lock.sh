#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# fdwm-lock with slock, xset, systemctl and sleep stubbed: it runs slock,
# suspends only once the screen has stayed off (no input) for 5 minutes
# while still locked, starts over after any input, and exits with slock
# once you unlock.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
lock=$ROOT/dotfiles/.local/bin/fdwm-lock
export LOG=$T/log STATES=$T/states STATE=$T/state LOCKED=$T/locked
REAL_SLEEP=$(command -v sleep)
export REAL_SLEEP

# slock: stays up until $LOCKED goes, then exits with $SLOCK_RC
stub slock 'echo slock >>"$LOG"; while [ -e "$LOCKED" ]; do "$REAL_SLEEP" 0.01; done; exit "${SLOCK_RC:-0}"'
# sleep (each 15-second check): the screen takes the next state in $STATES;
# with none left, you unlock
stub sleep '
v=$(head -n1 "$STATES")
if [ -z "$v" ]; then rm -f "$LOCKED"; exec "$REAL_SLEEP" 1; fi
sed -i 1d "$STATES"
echo "$v" >"$STATE"'
stub xset '[ "$1" = q ] && printf "DPMS (Energy Star):\n  Monitor is %s\n" "$(cat "$STATE")"'
stub systemctl 'echo "systemctl $*" >>"$LOG"'
PATH="$T/bin:$PATH"

# locked STATE...: lock while the screen goes through STATE... (On, Off,
# Standby, one per check), then unlock; sets $rc and $ran
locked() {
    : >"$LOG" && : >"$LOCKED" && echo On >"$STATE"
    printf '%s\n' "$@" >"$STATES"
    timeout 30 sh "$lock"
    rc=$?
    ran=$(cat "$LOG")
}
# n N STATE: STATE, N times
n() { for ((i = 0; i < $1; i++)); do echo "$2"; done; }

# shellcheck disable=SC2046  # one argument per check
{
locked $(n 19 Off)
expect "off for 19 checks, then unlocked: slock, no suspend" "slock" "$ran"
expect "exits with slock's status" 0 "$rc"

locked $(n 20 Off) $(n 5 Off)
expect "off for 20 checks (5 minutes): suspends once" "$(printf 'slock\nsystemctl suspend')" "$ran"

locked $(n 20 Off) $(n 20 Off)
expect "still off 5 minutes after waking: suspends again" \
    "$(printf 'slock\nsystemctl suspend\nsystemctl suspend')" "$ran"

locked $(n 15 Off) On $(n 19 Off)
expect "a key or the mouse: 5 more minutes off before suspending" "slock" "$ran"

locked $(n 10 On) $(n 20 Standby)
expect "standby counts as off" "$(printf 'slock\nsystemctl suspend')" "$ran"

locked $(n 30 On)
expect "screen kept on (typing at the lock screen): no suspend" "slock" "$ran"
}

SLOCK_RC=1 locked
expect "slock failing: its status" 1 "$rc"

finish
