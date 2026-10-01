#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# fdwm-theme-menu with dmenu, st and fdwm-theme stubbed: what it offers, that
# picking a flavor runs fdwm-theme on it in a floating st that waits for
# Return, and that Escape, the flavor in use or a line typed in that isn't a
# flavor run nothing.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
menu=$ROOT/dotfiles/.local/bin/fdwm-theme-menu
export LOG=$T/log HOME=$T/home

# dmenu: logs its prompt and the lines it was given, then picks $CHOICE
# (empty: Escape)
stub dmenu '
for a; do p=$a; done
echo "dmenu $p: $(paste -sd, -)" >>"$LOG"
[ -n "$CHOICE" ] || exit 1
echo "$CHOICE"'
# st: logs its options, then runs the command after -e with Return waiting
stub st '
args=
while [ "$1" != -e ]; do args="$args $1"; shift; done
shift
echo "st$args" >>"$LOG"
echo | "$@"'
PATH="$T/bin:$PATH"
# fdwm-theme, where install.sh links it: mocha in use
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/fdwm-theme" <<'EOF'
#!/bin/sh
case $1 in
list) printf '%s\n' mocha tokyonight thinkpad ;;
current) echo mocha ;;
*) echo "fdwm-theme $*" >>"$LOG"; echo "==> Switched to $1" ;;
esac
EOF
chmod +x "$HOME/.local/bin/fdwm-theme"
# pick CHOICE: run the menu; sets $rc, $out and $ran (what it ran, not the
# dmenu line)
pick() {
    : >"$LOG"
    out=$(CHOICE=$1 sh "$menu" 2>&1)
    rc=$?
    ran=$(grep -v '^dmenu' "$LOG")
}

pick thinkpad
expect "offers the flavors, the one in use in the prompt" \
    "dmenu theme (mocha): mocha,tokyonight,thinkpad" "$(head -n1 "$LOG")"
expect "a flavor: fdwm-theme switches to it in st, named for dwm's rule" \
    "$(printf 'st -n fdwm-theme -t fdwm-theme thinkpad\nfdwm-theme thinkpad')" "$ran"
expect_match "a flavor: st shows how it went, then waits for Return" \
    "==> Switched to thinkpad.*Press Return to close" "$(tr '\n' ' ' <<<"$out")"
expect "a flavor: exits 0" 0 "$rc"

pick mocha
expect "the flavor in use: nothing" "0:" "$rc:$ran"
pick ""
expect "Escape: nothing, and exits 0" "0:" "$rc:$ran"
pick "rm -rf ~"
expect "a line typed in that isn't a flavor: nothing, exit 1" "1:" "$rc:$ran"

finish
