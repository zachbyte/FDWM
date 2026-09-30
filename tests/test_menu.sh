#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# fdwm-menu with dmenu, slock, systemctl and pkill stubbed: what it offers,
# what each choice runs, and that log out, reboot and power off only go
# ahead after a "yes".
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
menu=$ROOT/dotfiles/.local/bin/fdwm-menu
export LOG=$T/log

# dmenu: logs its prompt and the lines it was given, then picks $CHOICE in
# the menu and $ANSWER when asked to confirm (empty: Escape)
stub dmenu '
for a; do p=$a; done
echo "dmenu $p: $(paste -sd, -)" >>"$LOG"
if [ "$p" = power ]; then out=$CHOICE; else out=$ANSWER; fi
[ -n "$out" ] || exit 1
echo "$out"'
for c in slock systemctl pkill; do stub "$c" "echo \"$c \$*\" >>\"\$LOG\""; done
PATH="$T/bin:$PATH"
# pick CHOICE [ANSWER]: run the menu; sets $rc and $ran (what it ran, not
# the dmenu lines)
pick() {
    : >"$LOG"
    CHOICE=$1 ANSWER=${2:-} sh "$menu" 2>/dev/null
    rc=$?
    ran=$(grep -v '^dmenu' "$LOG")
}
uid=$(id -u)

pick lock
expect "offers the six, in order" \
    "dmenu power: lock,suspend,restart dwm,log out,reboot,power off" "$(head -n1 "$LOG")"
expect "lock: slock" "slock " "$ran"
pick suspend
expect "suspend: systemctl suspend" "systemctl suspend" "$ran"
pick "restart dwm"
expect "restart dwm: SIGHUP to dwm, as Alt+Shift+W" "pkill -HUP -u $uid -x dwm" "$ran"

for c in "log out:pkill -TERM -u $uid -x dwm" "reboot:systemctl reboot" "power off:systemctl poweroff"; do
    what=${c%%:*} cmd=${c#*:}
    pick "$what" yes
    expect "$what: asks first" "dmenu $what?: no,yes" "$(sed -n 2p "$LOG")"
    expect "$what, then yes: $cmd" "$cmd" "$ran"
    pick "$what" no
    expect "$what, then no: nothing" "0:" "$rc:$ran"
    pick "$what" ""
    expect "$what, then Escape: nothing" "0:" "$rc:$ran"
done

pick ""
expect "Escape: nothing, and exits 0" "0:" "$rc:$ran"
pick "rm -rf ~"
expect "a line typed in that isn't in the menu: nothing, exit 1" "1:" "$rc:$ran"

finish
