#!/usr/bin/env bash
# Installs FDWM on Fedora: packages, the Nerd Font, dwm/st/dmenu, dotfiles, autologin and
# the GRUB theme. update.sh runs it after recloning, so it must stay safe to run again:
# existing dotfiles that differ are backed up first, never silently replaced.
set -euo pipefail
trap 'echo "install.sh: failed on line $LINENO: $BASH_COMMAND" >&2' ERR

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root; it calls sudo where needed." >&2
    exit 1
fi

cd "$(dirname "$(readlink -f "$0")")"

mapfile -t packages < <(sed 's/#.*//' packages.txt | xargs -n1)

# rpm is quick; dnf only runs (and refreshes its metadata) when something is missing.
echo "==> Checking packages"
missing=()
for p in "${packages[@]}"; do
    rpm -q --whatprovides "$p" >/dev/null 2>&1 || missing+=("$p")
done
if (( ${#missing[@]} )); then
    echo "Installing: ${missing[*]}"
    sudo dnf install -y "${missing[@]}"
else
    echo "All installed"
fi

# JetBrainsMono Nerd Font isn't packaged by Fedora; fetch the pinned upstream release.
font_url=https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz
font_sha256=04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf
font_dir=/usr/local/share/fonts/JetBrainsMonoNerdFont

echo "==> Installing JetBrainsMono Nerd Font"
if fc-list -q "JetBrainsMono Nerd Font"; then
    echo "Already installed"
else
    tmp=$(mktemp -d)
    curl -fL -o "$tmp/font.tar.xz" "$font_url"
    echo "$font_sha256  $tmp/font.tar.xz" | sha256sum -c -
    sudo mkdir -p "$font_dir"
    sudo tar -xJf "$tmp/font.tar.xz" -C "$font_dir" \
        JetBrainsMonoNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf
    sudo fc-cache -f "$font_dir"
    rm -rf "$tmp"
fi

for tool in dwm st dmenu; do
    echo "==> Building and installing $tool"
    sudo make -C "suckless/$tool" clean install
done

# Copy dotfiles/<path> to ~/<path>. Anything different already there is moved to
# ~/<path>.bak.<time> first. lazy-lock.json is ignored because neovim rewrites it.
install_dotfile() {
    local src=dotfiles/$1 dest=$HOME/$1
    if [[ -e $dest ]] && diff -rq -x lazy-lock.json "$src" "$dest" >/dev/null; then
        echo "~/$1 is up to date"
        return
    fi
    if [[ -e $dest || -L $dest ]]; then
        local backup
        backup=$dest.bak.$(date +%Y%m%d-%H%M%S)
        mv "$dest" "$backup"
        echo "Moved your old ~/$1 to $backup"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -r "$src" "$dest"
    echo "Installed ~/$1"
}

echo "==> Setting up ~/.xinitrc"
install_dotfile .xinitrc

echo "==> Setting up ~/.bashrc"
install_dotfile .bashrc

echo "==> Setting up neovim"
if nvim --clean --headless +'if !has("nvim-0.12") | cquit | endif' +quit; then
    install_dotfile .config/nvim
else
    echo "Skipped: the neovim config needs Neovim 0.12 or newer (Fedora 44 or newer)"
fi

# Fedora already gives every user a ~/.bash_profile, so add the autostart to it
# instead of replacing it.
echo "==> Setting up ~/.bash_profile"
if [[ ! -e ~/.bash_profile ]]; then
    cp dotfiles/.bash_profile ~/.bash_profile
    echo "Installed ~/.bash_profile"
elif grep -q 'exec startx' ~/.bash_profile; then
    echo "~/.bash_profile already starts X"
else
    { echo; sed -n '/^# Start dwm/,$p' dotfiles/.bash_profile; } >> ~/.bash_profile
    echo "Added the tty1 autostart to ~/.bash_profile"
fi

# Log in on tty1 without a password prompt; .bash_profile then runs startx.
echo "==> Setting up autologin on tty1"
autologin=/etc/systemd/system/getty@tty1.service.d/autologin.conf
sudo mkdir -p "${autologin%/*}"
sudo tee "$autologin" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\\\u' --noreset --noclear --autologin $USER - \${TERM}
EOF
sudo systemctl daemon-reload
echo "tty1 now logs in $USER automatically"

echo "==> Installing the GRUB theme"
if [[ -f /etc/default/grub ]] && command -v grub2-mkconfig >/dev/null; then
    theme=/boot/grub2/themes/catppuccin-mocha-grub
    sudo mkdir -p "$theme"
    sudo cp -r grub/catppuccin-mocha-grub/. "$theme"
    [[ -e /etc/default/grub.fdwm.bak ]] || sudo cp /etc/default/grub /etc/default/grub.fdwm.bak
    sudo sed -i '/^GRUB_THEME=/d; /^GRUB_TERMINAL_OUTPUT=/d' /etc/default/grub
    printf 'GRUB_TERMINAL_OUTPUT="gfxterm"\nGRUB_THEME="%s/theme.txt"\n' "$theme" \
        | sudo tee -a /etc/default/grub >/dev/null
    # Fedora hides the boot menu when only one OS is installed; show it so the theme is visible.
    sudo grub2-editenv - unset menu_auto_hide

    # Drop the rescue entry (titled with the machine id) and stop new ones being made.
    if rpm -q dracut-config-rescue >/dev/null; then
        sudo dnf remove -y dracut-config-rescue
    fi
    # (inside sudo sh -c: only root can list /boot/loader/entries, so only root can expand the *)
    sudo sh -c 'rm -f /boot/loader/entries/*-0-rescue.conf /boot/vmlinuz-0-rescue-* /boot/initramfs-0-rescue-*.img'

    # Short "Fedora <kernel version>" titles, now and for every kernel update.
    sudo install -m 755 grub/60-fdwm-title.install /etc/kernel/install.d/60-fdwm-title.install
    sudo sh -c 'for entry in /boot/loader/entries/*.conf; do
        /etc/kernel/install.d/60-fdwm-title.install add "$(sed -n "s/^version[[:space:]]*//p" "$entry")"
    done'
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
else
    echo "GRUB 2 not found, skipped"
fi

if [[ -n ${DISPLAY:-} ]]; then
    echo "==> Done. Press Alt+Shift+W to restart dwm on the new build."
else
    echo "==> Done. Reboot, or log in on tty1, to start dwm."
fi
