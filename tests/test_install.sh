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
# flatpak and gsettings only log; flatpak info fails unless $ZEN is set (Zen
# Browser already installed)
stub flatpak 'echo "FLATPAK $*" >>"$LOG"; [ "$1" != info ] || [ -n "$ZEN" ]'
stub gsettings 'echo "GSETTINGS $*" >>"$LOG"'
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
cp "$ROOT/install.sh" "$ROOT/packages.txt" "$ROOT/keys.awk" "$T/repo/"
cp -r "$ROOT/dotfiles" "$T/repo/"
mkdir -p "$T/repo/suckless/dwm"
cp "$ROOT/suckless/dwm/config.h" "$T/repo/suckless/dwm/"
npackages=$(sed 's/#.*//' "$ROOT/packages.txt" | wc -w | tr -d ' ')

# run: a fresh home and log, then install.sh; sets $out and $rc
run() {
    rm -rf "${T:?}/home" && mkdir -p "$T/home" && : >"$LOG"
    out=$(cd "$T/repo" && HOME="$T/home" MISSING=${MISSING:-} ZEN=${ZEN:-} bash ./install.sh 2>&1)
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
expect "installs ~/.local/bin/fdwm-lock, executable" yes "$([[ -x $T/home/.local/bin/fdwm-lock ]] && echo yes)"
expect "installs ~/.local/bin/fdwm-menu, executable" yes "$([[ -x $T/home/.local/bin/fdwm-menu ]] && echo yes)"
expect "installs ~/.local/bin/fdwm-theme-menu, executable" yes "$([[ -x $T/home/.local/bin/fdwm-theme-menu ]] && echo yes)"
expect "installs ~/.local/bin/fdwm-keys, executable" yes "$([[ -x $T/home/.local/bin/fdwm-keys ]] && echo yes)"
expect "lists dwm's keys in ~/.config/fdwm/keys, from config.h" "$(awk -f "$ROOT/keys.awk" "$ROOT/suckless/dwm/config.h")" "$(cat "$T/home/.config/fdwm/keys" 2>/dev/null)"
expect "installs Zen Browser from Flathub, for you alone" \
    "$(printf '%s\n' 'FLATPAK info --user app.zen_browser.zen' \
        'FLATPAK remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo' \
        'FLATPAK install --user --noninteractive flathub app.zen_browser.zen')" "$(grep '^FLATPAK' "$LOG")"
expect "installs ~/.local/bin/zen, executable" yes "$([[ -x $T/home/.local/bin/zen ]] && echo yes)"
for f in .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini; do
    expect_match "dark mode: ~/$f prefers dark" "^gtk-application-prefer-dark-theme=true$" "$(cat "$T/home/$f" 2>/dev/null)"
done
expect_match "dark mode: the gtk portal answers Flatpak apps" "^default=gtk$" "$(cat "$T/home/.config/xdg-desktop-portal/portals.conf" 2>/dev/null)"
expect "dark mode: gsettings' color-scheme, for the portal" \
    "GSETTINGS set org.gnome.desktop.interface color-scheme prefer-dark" "$(grep '^GSETTINGS' "$LOG")"
expect_match "sets up suspend" "==> Setting up suspend" "$out"

ZEN=1 run
expect "Zen Browser already installed: only checked" "FLATPAK info --user app.zen_browser.zen" "$(grep '^FLATPAK' "$LOG")"
expect_match "suspends on lid close, not on logind's idle" "SUDO tee /etc/systemd/logind.conf.d/fdwm-lid.conf" "$(cat "$LOG")"

MISSING=nnn run
expect_match "one package missing: names it" "Installing: nnn$" "$out"
expect "one package missing: installs just that one" "SUDO dnf install -y nnn" "$(grep '^SUDO dnf' "$LOG")"
expect "one package missing: one rpm call, then one per package" $((npackages + 1)) "$(grep -c '^RPM' "$LOG")"

MISSING='/usr/bin/npm nnn' run
expect "a path-style package missing: installed too" "SUDO dnf install -y nnn /usr/bin/npm" "$(grep '^SUDO dnf' "$LOG")"

# a key in config.h without its description: install.sh stops there, naming
# the line, before building or installing anything
cp "$T/repo/suckless/dwm/config.h" "$T/config.h.good"
sed -i 's| /\* windows: close the focused window \*/||' "$T/repo/suckless/dwm/config.h"
n=$(grep -n 'killclient' "$T/repo/suckless/dwm/config.h" | cut -d: -f1)
run
cp "$T/config.h.good" "$T/repo/suckless/dwm/config.h"
expect "a key without its description: fails" yes "$([[ $rc -ne 0 ]] && echo yes)"
expect_match "a key without its description: names config.h's line" "suckless/dwm/config.h:$n: no \"/\* group: what it does \*/\" at the end" "$out"
expect "a key without its description: nothing built or installed" "" "$(grep -E '^(MAKE|SUDO make)' "$LOG")"
expect "a key without its description: no half-written list" no "$([[ -e $T/home/.config/fdwm/keys || -e $T/home/.config/fdwm/keys.tmp ]] && echo yes || echo no)"

# a failure inside a function must still reach the ERR trap (set -E)
stub cp 'exit 1'
run
rm "$T/bin/cp"
expect "cp fails in install_dotfile: exits non-zero" yes "$([[ $rc -ne 0 ]] && echo yes)"
expect_match "cp fails in install_dotfile: ERR trap names the line" "install.sh: failed on line [0-9]+: cp -r" "$out"

finish
