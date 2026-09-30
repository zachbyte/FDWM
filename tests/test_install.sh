#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies and sed scripts expand later, not here
# install.sh in a sandbox: sudo, rpm, make, fc-list and nvim are stubs that
# only log their arguments, so nothing here can touch the real system.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
export LOG="$T/log" USER=tester
unset DISPLAY

stub sudo 'echo "SUDO $*" >>"$LOG"; case "$1" in tee) cat >/dev/null ;; esac; exit 0'
stub make 'echo "MAKE $*" >>"$LOG"'
stub fc-list 'exit 0'
stub nvim 'exit 0'
# rpm -q --whatprovides: fails for every name in $MISSING and exits with the
# number of failures, like the real one
stub rpm '
echo "RPM $*" >>"$LOG"
[ "$1" = -q ] && [ "$2" = --whatprovides ] || exit 0
shift 2; n=0
for p in "$@"; do
	case " $MISSING " in
	*" $p "*) echo "no package provides $p"; n=$((n + 1)) ;;
	*) echo "${p##*/}-1.0-1.fc44.x86_64" ;;
	esac
done
exit $n'
PATH="$T/bin:$PATH"

theme_repo "$T/repo"
cp "$ROOT/install.sh" "$ROOT/packages.txt" "$T/repo/"
cp -r "$ROOT/dotfiles" "$T/repo/"
npackages=$(sed 's/#.*//' "$ROOT/packages.txt" | wc -w | tr -d ' ')

# run: a fresh home and log, then install.sh; sets $out and $rc
run() {
    rm -rf "${T:?}/home" && mkdir -p "$T/home" && : >"$LOG"
    out=$(cd "$T/repo" && HOME="$T/home" MISSING=${MISSING:-} bash ./install.sh 2>&1)
    rc=$?
}

run
expect "normal run: exits 0" 0 "$rc"
expect_no_match "normal run: no ERR trap messages" "failed on line" "$out"
expect_match "normal run: finishes" "==> Done" "$out"
expect "builds each tool as you, then installs it with sudo" \
    "$(for t in dwm st dmenu slock; do printf 'MAKE -C suckless/%s clean all\nSUDO make -C suckless/%s install\n' "$t" "$t"; done)" \
    "$(grep -E '^(MAKE|SUDO make)' "$LOG")"
expect "generates colors.h before building" yes "$([[ -s $T/repo/suckless/colors.h ]] && echo yes)"
expect "generates ~/.config/fdwm/colors.sh" yes "$([[ -s $T/home/.config/fdwm/colors.sh ]] && echo yes)"
expect "every package installed: one rpm call" 1 "$(grep -c '^RPM' "$LOG")"
expect_match "every package installed: says so" "All installed" "$out"
expect "generates dunst's colors" yes "$([[ -s $T/home/.config/dunst/dunstrc.d/50-fdwm-colors.conf ]] && echo yes)"
for f in .xinitrc .bashrc .bashrc.d/claude.sh .config/nvim/init.lua .config/dunst/dunstrc; do
    expect "installs ~/$f" yes "$([[ -f $T/home/$f ]] && echo yes)"
done
expect "installs ~/.local/bin/fdwm-bar, executable" yes "$([[ -x $T/home/.local/bin/fdwm-bar ]] && echo yes)"
expect "installs ~/.local/bin/fdwm-shot, executable" yes "$([[ -x $T/home/.local/bin/fdwm-shot ]] && echo yes)"
if ln -s probe "$T/probe" 2>/dev/null && [[ -L $T/probe ]]; then
    expect "links ~/.local/bin/fdwm-theme to the checkout's" "$T/repo/fdwm-theme" "$(readlink "$T/home/.local/bin/fdwm-theme")"
else
    echo "  skip  the ~/.local/bin/fdwm-theme link (no symlinks here)"
fi
expect "installs ~/.local/bin/fdwm-menu, executable" yes "$([[ -x $T/home/.local/bin/fdwm-menu ]] && echo yes)"
expect_match "sets up suspend" "==> Setting up suspend" "$out"

MISSING=nnn run
expect_match "one package missing: names it" "Installing: nnn$" "$out"
expect "one package missing: installs just that one" "SUDO dnf install -y nnn" "$(grep '^SUDO dnf' "$LOG")"
expect "one package missing: one rpm call, then one per package" $((npackages + 1)) "$(grep -c '^RPM' "$LOG")"

MISSING='/usr/bin/npm nnn' run
expect "a path-style package missing: installed too" "SUDO dnf install -y nnn /usr/bin/npm" "$(grep '^SUDO dnf' "$LOG")"

# a failure inside a function must still reach the ERR trap (set -E)
stub cp 'exit 1'
run
rm "$T/bin/cp"
expect "cp fails in install_dotfile: exits non-zero" yes "$([[ $rc -ne 0 ]] && echo yes)"
expect_match "cp fails in install_dotfile: ERR trap names the line" "install.sh: failed on line [0-9]+: cp -r" "$out"

finish
