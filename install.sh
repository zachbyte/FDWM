#!/usr/bin/env bash
# Installs FDWM on Fedora: packages, dwm/st/dmenu, and ~/.xinitrc.
# Safe to run again; it only rebuilds and never overwrites an existing ~/.xinitrc.
set -euo pipefail
trap 'echo "install.sh: failed on line $LINENO: $BASH_COMMAND" >&2' ERR

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root; it calls sudo where needed." >&2
    exit 1
fi

cd "$(dirname "$(readlink -f "$0")")"

packages=(
    git gcc make pkgconf-pkg-config
    xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput
    libX11-devel libXft-devel libXinerama-devel libXrender-devel
    fontconfig-devel freetype-devel
    dejavu-sans-mono-fonts
)

echo "==> Installing packages"
sudo dnf install -y "${packages[@]}"

for tool in dwm st dmenu; do
    echo "==> Building and installing $tool"
    sudo make -C "suckless/$tool" clean install
done

echo "==> Setting up ~/.xinitrc"
if [[ ! -e ~/.xinitrc ]]; then
    echo "exec dwm" > ~/.xinitrc
    echo "Created ~/.xinitrc"
elif grep -qx 'exec dwm' ~/.xinitrc; then
    echo "~/.xinitrc already starts dwm, left unchanged"
else
    echo "~/.xinitrc already exists and doesn't start dwm, so it was left unchanged."
    echo "Add 'exec dwm' as its last line to use dwm."
fi

echo "==> Done. Run: startx"
