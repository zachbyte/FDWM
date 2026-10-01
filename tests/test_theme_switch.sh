#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# shellcheck disable=SC2154  # fdwm_* come from the generated colors.sh
# fdwm-theme FLAVOR: saves the flavor, runs install.sh, then recolors the
# desktop and the open st windows, reloads dunst and restarts dwm.
# install.sh is a stand-in that generates the colors as the real one does
# first; the st windows' terminals are files, and xsetroot, pkill, pgrep,
# ps and dunstctl stubs.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
theme_repo "$T/repo"
cat >"$T/repo/install.sh" <<'EOF'
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
echo INSTALL >>"$LOG"
[ -z "${FAIL_INSTALL:-}" ] || exit 1
./fdwm-theme generate >/dev/null
EOF
chmod +x "$T/repo/install.sh" "$T/repo/fdwm-theme"
export LOG=$T/log HOME=$T/home FDWM_DEV=$T/dev DISPLAY=:0
mkdir -p "$HOME/.local/bin" "$FDWM_DEV/pts"
# through the link install.sh makes, as it runs from ~/.local/bin (where
# there are no symlinks, as in Git for Windows, the checkout's own)
cmd=$HOME/.local/bin/fdwm-theme
ln -s "$T/repo/fdwm-theme" "$cmd" 2>/dev/null
if [[ ! -L $cmd ]]; then
    echo "  (no symlinks here: running the checkout's fdwm-theme)"
    cmd=$T/repo/fdwm-theme
fi

# two st windows (pids 100 and 200, on pts/3 and pts/4) and another
# terminal, pts/9, that isn't st's; dunst runs when $DUNST is set
stub pgrep '
case "$*" in
"-u $(id -u) -x st") echo 100; echo 200 ;;
"-u $(id -u) -x dunst") [ -n "${DUNST:-}" ] && echo 300 ;;
*) exit 1 ;;
esac'
stub ps 'case "$4" in 100) echo "pts/3" ;; 200) echo "pts/4" ;; esac'
stub xsetroot 'echo "xsetroot $*" >>"$LOG"'
stub pkill 'echo "pkill $*" >>"$LOG"'
stub dunstctl 'echo "dunstctl $*" >>"$LOG"'
PATH="$T/bin:$PATH"
# theme ARGS...: fdwm-theme ARGS; sets $out and $rc, with a fresh log and
# empty terminals
theme() {
    : >"$LOG"
    for t in 3 4 9; do : >"$FDWM_DEV/pts/$t"; done
    out=$("$cmd" "$@" 2>&1)
    rc=$?
}
flavor_file=$HOME/.config/fdwm/flavor

theme
expect "no flavor: exits 0" 0 "$rc"
expect_match "no flavor: says mocha, and what else there is" "^mocha \(the palette has: mocha tokyonight;" "$out"

theme nosuch
expect "an unknown flavor: fails" 1 "$rc"
expect_match "an unknown flavor: names the ones there are" "no flavor called nosuch \(the palette has: mocha tokyonight\)" "$out"
expect "an unknown flavor: nothing saved or run" "no:" "$([[ -e $flavor_file ]] && echo yes || echo no):$(cat "$LOG")"

DUNST=1 theme tokyonight
expect "tokyonight: exits 0" 0 "$rc"
expect "tokyonight: saved" tokyonight "$(cat "$flavor_file")"
# shellcheck source=/dev/null
. "$HOME/.config/fdwm/colors.sh"
expect "tokyonight: install.sh ran and generated tokyonight" "tokyonight" "$fdwm_flavor"
expect "tokyonight: install.sh, the desktop, dunst, then dwm" \
    "$(printf 'INSTALL\nxsetroot -solid %s\ndunstctl reload\npkill -HUP -u %s -x dwm' "$fdwm_base" "$(id -u)")" "$(cat "$LOG")"
want=$(for i in {0..15}; do v=fdwm_term$i; printf '\e]4;%d;%s\a' "$i" "${!v}"; done
    printf '\e]10;%s\a\e]11;%s\a\e]12;%s\a' "$fdwm_term_fg" "$fdwm_term_bg" "$fdwm_term_cursor")
expect "tokyonight: each st window gets the 16 colors, text, background and cursor" \
    "$(od -An -c <<<"$want")" "$(od -An -c <<<"$(cat "$FDWM_DEV/pts/3")")"
expect "tokyonight: the second st window too" "$(cat "$FDWM_DEV/pts/3")" "$(cat "$FDWM_DEV/pts/4")"
expect "tokyonight: a terminal that isn't st's is left alone" 0 "$(wc -c <"$FDWM_DEV/pts/9" | tr -d ' ')"
expect_match "tokyonight: says so" "Recolored 2 open st window" "$out"
tokyonight_seq=$(cat "$FDWM_DEV/pts/3")

theme mocha
expect "back to mocha: saved" mocha "$(cat "$flavor_file")"
# shellcheck source=/dev/null
. "$HOME/.config/fdwm/colors.sh"
expect "back to mocha: generated" mocha "$fdwm_flavor"
expect_match "back to mocha: the st windows get mocha's background" "]11;$fdwm_term_bg" "$(cat "$FDWM_DEV/pts/4")"
expect "back to mocha: not what tokyonight sent" yes "$([[ $(cat "$FDWM_DEV/pts/4") != "$tokyonight_seq" ]] && echo yes)"
expect "dunst not running: not reloaded" "" "$(grep dunstctl "$LOG")"

DISPLAY='' theme tokyonight
expect "outside X: exits 0" 0 "$rc"
expect "outside X: only install.sh runs" INSTALL "$(cat "$LOG")"
expect "outside X: no terminal written to" 0 "$(cat "$FDWM_DEV"/pts/* | wc -c | tr -d ' ')"
expect_match "outside X: says when it shows" "tokyonight from the next time X starts" "$out"

FAIL_INSTALL=1 theme mocha
expect "install.sh fails: fails too" 1 "$rc"
expect_match "install.sh fails: says what to do" "install.sh failed; mocha is saved, so run fdwm-theme mocha again" "$out"
expect "install.sh fails: nothing restarted or recolored" INSTALL "$(cat "$LOG")"

theme --help
expect "an option: usage, exit 2" 2 "$rc"

finish
