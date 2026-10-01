#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies expand later, not here
# shellcheck disable=SC2154  # fdwm_* come from the generated colors.sh
# fdwm-theme FLAVOR: saves the flavor, runs install.sh --colors, then
# recolors the desktop and the open st windows, reloads dunst (or restarts
# it) and restarts dwm. install.sh is a stand-in that generates the colors
# as the real one does first; the st windows' terminals are files, and
# xsetroot, pkill, pgrep, ps, dunstctl and setsid stubs. Then the real
# install.sh --colors, through fdwm-theme, with every command it could run
# a stub: only the colors, the four tools and nothing else, with sudo only
# to install a tool whose build changed.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
theme_repo "$T/repo"
cat >"$T/repo/install.sh" <<'EOF'
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
echo "INSTALL $*" >>"$LOG"
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
stub dunstctl 'echo "dunstctl $*" >>"$LOG"; [ -z "${DUNSTCTL_FAILS:-}" ]'
stub setsid 'echo "setsid $*" >>"$LOG"'
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
expect_match "no flavor: says mocha, and what else there is" "^mocha \(the palette has: mocha tokyonight thinkpad;" "$out"

theme nosuch
expect "an unknown flavor: fails" 1 "$rc"
expect_match "an unknown flavor: names the ones there are" "no flavor called nosuch \(the palette has: mocha tokyonight thinkpad\)" "$out"
expect "an unknown flavor: nothing saved or run" "no:" "$([[ -e $flavor_file ]] && echo yes || echo no):$(cat "$LOG")"

theme list
expect "list: the palette's flavors, one per line" "$(printf 'mocha\ntokyonight\nthinkpad')" "$out"
theme current
expect "current, none saved: mocha" mocha "$out"

DUNST=1 theme tokyonight
expect "tokyonight: exits 0" 0 "$rc"
expect "tokyonight: saved" tokyonight "$(cat "$flavor_file")"
# shellcheck source=/dev/null
. "$HOME/.config/fdwm/colors.sh"
expect "tokyonight: install.sh ran and generated tokyonight" "tokyonight" "$fdwm_flavor"
expect "tokyonight: install.sh, the desktop, dunst, then dwm" \
    "$(printf 'INSTALL --colors\nxsetroot -solid %s\ndunstctl reload\npkill -HUP -u %s -x dwm' "$fdwm_base" "$(id -u)")" "$(cat "$LOG")"
want=$(for i in {0..15}; do v=fdwm_term$i; printf '\e]4;%d;%s\a' "$i" "${!v}"; done
    printf '\e]10;%s\a\e]11;%s\a\e]12;%s\a' "$fdwm_term_fg" "$fdwm_term_bg" "$fdwm_term_cursor")
expect "tokyonight: each st window gets the 16 colors, text, background and cursor" \
    "$(od -An -c <<<"$want")" "$(od -An -c <<<"$(cat "$FDWM_DEV/pts/3")")"
expect "tokyonight: the second st window too" "$(cat "$FDWM_DEV/pts/3")" "$(cat "$FDWM_DEV/pts/4")"
expect "tokyonight: a terminal that isn't st's is left alone" 0 "$(wc -c <"$FDWM_DEV/pts/9" | tr -d ' ')"
expect_match "tokyonight: says so" "Recolored 2 open st window" "$out"
tokyonight_seq=$(cat "$FDWM_DEV/pts/3")
theme current
expect "current: the one switched to" tokyonight "$out"

theme mocha
expect "back to mocha: saved" mocha "$(cat "$flavor_file")"
# shellcheck source=/dev/null
. "$HOME/.config/fdwm/colors.sh"
expect "back to mocha: generated" mocha "$fdwm_flavor"
expect_match "back to mocha: the st windows get mocha's background" "]11;$fdwm_term_bg" "$(cat "$FDWM_DEV/pts/4")"
expect "back to mocha: not what tokyonight sent" yes "$([[ $(cat "$FDWM_DEV/pts/4") != "$tokyonight_seq" ]] && echo yes)"
expect "dunst not running: not reloaded" "" "$(grep dunstctl "$LOG")"
DUNST=1 DUNSTCTL_FAILS=1 theme tokyonight
expect "dunst won't reload: restarted instead" \
    "$(printf 'dunstctl reload\npkill -u %s -x dunst\nsetsid -f dunst' "$(id -u)")" "$(grep -E '^(dunstctl|pkill -u [0-9]+ -x dunst|setsid)' "$LOG")"

DISPLAY='' theme tokyonight
expect "outside X: exits 0" 0 "$rc"
expect "outside X: only install.sh runs" "INSTALL --colors" "$(cat "$LOG")"
expect "outside X: no terminal written to" 0 "$(cat "$FDWM_DEV"/pts/* | wc -c | tr -d ' ')"
expect_match "outside X: says when it shows" "tokyonight from the next time X starts" "$out"

FAIL_INSTALL=1 theme mocha
expect "install.sh fails: fails too" 1 "$rc"
expect_match "install.sh fails: says what to do" "install.sh --colors failed; mocha is saved, so run fdwm-theme mocha again" "$out"
expect "install.sh fails: nothing restarted or recolored" "INSTALL --colors" "$(cat "$LOG")"

theme --help
expect "an option: usage, exit 2" 2 "$rc"

# The real install.sh --colors, run by the real fdwm-theme from a copy of the
# repo, outside X. make builds a stand-in for each tool from colors.h and
# installs it under $PREFIX_DIR, or under DESTDIR when given one; sudo runs
# make and only logs anything else; every other command install.sh's full
# run uses only logs.
real=$T/real
theme_repo "$real"
cp "$ROOT/install.sh" "$ROOT/packages.txt" "$real/"
cp -r "$ROOT/dotfiles" "$real/"
mkdir -p "$real/suckless/"{dwm,st,dmenu,slock}
export PREFIX_DIR=$T/prefix
stub make '
dir=$2 tool=${2##*/} dest=
for a; do case $a in DESTDIR=*) dest=${a#DESTDIR=} ;; esac; done
case $3 in
clean) cksum <"$dir/../colors.h" >"$dir/built"; echo "MAKE build $tool" >>"$LOG" ;;
install)
    mkdir -p "$dest$PREFIX_DIR/bin"
    cp "$dir/built" "$dest$PREFIX_DIR/bin/$tool"
    [ -n "$dest" ] || echo "MAKE install $tool" >>"$LOG" ;;
esac'
stub sudo 'echo "SUDO $*" >>"$LOG"; [ "$1" = make ] && exec "$@"; exit 0'
for c in rpm dnf curl fc-list systemctl grubby grub2-editenv nvim xset; do
    stub "$c" "echo \"$c \$*\" >>\"\$LOG\"; exit 0"
done
# realtheme ARGS...: the copy's fdwm-theme ARGS outside X, in a home of
# its own; sets $out and $rc
realtheme() {
    : >"$LOG"
    out=$(HOME=$T/home2 DISPLAY='' "$real/fdwm-theme" "$@" 2>&1)
    rc=$?
}
# others: whatever the log has besides building and installing the tools
others() { grep -vE '^(MAKE (build|install) [a-z]+|SUDO make -C suckless/[a-z]+ install)$' "$LOG" || true; }
tools=$(printf '%s\n' dwm st dmenu slock)

realtheme tokyonight
expect "--colors, first switch: exits 0" 0 "$rc"
expect_no_match "--colors, first switch: no ERR trap messages" "failed on line" "$out"
expect "--colors: builds the four tools" "$tools" "$(sed -n 's/^MAKE build //p' "$LOG")"
expect "--colors, first switch: installs each, with sudo" "$tools" "$(sed -n 's/^SUDO make -C suckless\/\([a-z]*\) install$/\1/p' "$LOG")"
expect "--colors: nothing else (no packages, font, dotfiles, logind, GRUB settings)" "" "$(others)"
expect "--colors: no dotfile installed" "" "$(cd "$T/home2" && find . -path ./.config/fdwm -prune -o -path ./.config/dunst -prune -o -path ./.local/state -prune -o -type f -print)"
expect "--colors: dunst's colors generated" yes "$([[ -s $T/home2/.config/dunst/dunstrc.d/50-fdwm-colors.conf ]] && echo yes)"
expect "--colors: the tools installed are tokyonight's" "$(cksum <"$real/suckless/colors.h")" "$(cat "$PREFIX_DIR/bin/dwm")"

realtheme tokyonight
expect "--colors, the same flavor again: exits 0" 0 "$rc"
expect "--colors, nothing changed: builds the four tools" "$tools" "$(sed -n 's/^MAKE build //p' "$LOG")"
expect "--colors, nothing changed: no sudo at all" "" "$(grep '^SUDO' "$LOG")"
expect_match "--colors, nothing changed: says so" "The same as the installed dwm; left as it is" "$out"

realtheme mocha
expect "--colors, another flavor: installs each tool again" "$tools" "$(sed -n 's/^MAKE install //p' "$LOG")"
expect "--colors, another flavor: still nothing else" "" "$(others)"

out=$(cd "$real" && bash ./install.sh --bogus 2>&1)
expect "install.sh with an unknown option: exit 2" 2 "$?"
expect_match "install.sh with an unknown option: usage" "usage: install.sh \[--colors\]" "$out"

finish
