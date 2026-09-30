#!/usr/bin/env bash
# Installs FDWM on Fedora: packages, the Nerd Font, dwm/st/dmenu/slock, dotfiles and
# the GRUB theme. update.sh runs it after pulling, so it must stay safe to run again:
# existing dotfiles that differ are backed up first, never silently replaced.
set -Eeuo pipefail  # -E: the ERR trap below also fires inside functions
trap 'echo "install.sh: failed on line $LINENO: $BASH_COMMAND" >&2' ERR

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root; it calls sudo where needed." >&2
    exit 1
fi

cd "$(dirname "$(readlink -f "$0")")"

mapfile -t packages < <(sed 's/#.*//' packages.txt | xargs -n1)

# rpm is quick; dnf only runs (and refreshes its metadata) when something is missing.
# One rpm call answers the usual "everything is installed"; only when it fails
# is each package checked on its own to find out which ones are missing.
echo "==> Checking packages"
missing=()
if ! rpm -q --whatprovides "${packages[@]}" >/dev/null 2>&1; then
    for p in "${packages[@]}"; do
        rpm -q --whatprovides "$p" >/dev/null 2>&1 || missing+=("$p")
    done
fi
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
    trap 'rm -rf "$tmp"' EXIT  # also clean up if the download or checksum fails
    curl -fL -o "$tmp/font.tar.xz" "$font_url"
    echo "$font_sha256  $tmp/font.tar.xz" | sha256sum -c -
    sudo mkdir -p "$font_dir"
    sudo tar -xJf "$tmp/font.tar.xz" -C "$font_dir" \
        JetBrainsMonoNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf
    sudo fc-cache -f "$font_dir"
    rm -rf "$tmp"
    trap - EXIT
fi

# Build as you and only install as root, so the compiler never runs as root
# and no root-owned build files are left in the checkout.
for tool in dwm st dmenu slock; do
    echo "==> Building and installing $tool"
    make -C "suckless/$tool" clean all
    sudo make -C "suckless/$tool" install
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
install_dotfile .bashrc.d/claude.sh

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

# Earlier versions logged tty1 in without a password; remove that so tty1
# asks for your password again (.bash_profile still starts dwm after login).
autologin=/etc/systemd/system/getty@tty1.service.d/autologin.conf
if [[ -e $autologin ]]; then
    echo "==> Removing autologin on tty1"
    sudo rm -f "$autologin"
    sudo rmdir --ignore-fail-on-non-empty "${autologin%/*}"
    sudo systemctl daemon-reload
    echo "tty1 asks for your password again from the next boot"
fi

# Suspend after 10 minutes without use, and when the lid closes. .xinitrc
# locks the screen after 5 idle minutes, and xss-lock then marks the session
# idle in logind; logind suspends once everything has been idle for
# IdleActionSec more. Lid-close suspend is logind's default already; it is
# spelled out so an edit elsewhere in logind's config can't turn it off.
echo "==> Setting up suspend (10 minutes idle, lid closed)"
idle_conf=/etc/systemd/logind.conf.d/fdwm-idle.conf
idle_want=$'[Login]\nIdleAction=suspend\nIdleActionSec=5min\nHandleLidSwitch=suspend\nHandleLidSwitchExternalPower=suspend'
if [[ $(cat "$idle_conf" 2>/dev/null || true) != "$idle_want" ]]; then
    sudo mkdir -p "${idle_conf%/*}"
    printf '%s\n' "$idle_want" | sudo tee "$idle_conf" >/dev/null
    # SIGHUP makes logind reload its settings; a restart would end your session
    sudo systemctl kill -s HUP systemd-logind
    echo "Installed $idle_conf"
else
    echo "Already set up"
fi

echo "==> Installing the GRUB theme"
if [[ -f /etc/default/grub ]] && command -v grub2-mkconfig >/dev/null; then
    theme=/boot/grub2/themes/catppuccin-mocha-grub
    # grub2-mkconfig is slow, so it only runs at the end if this changes the
    # GRUB settings or theme, or grub.cfg is missing the theme or is older than
    # /etc/default/grub (an edit of yours it hasn't picked up yet).
    # (sudo sh -c: /boot/grub2 and grub.cfg are readable only by root)
    grub_state() {
        sudo sh -c 'cat /etc/default/grub; cd /boot/grub2/themes 2>/dev/null &&
            find catppuccin-mocha-grub -type f -exec cksum {} + | sort; true'
    }
    grub_before=$(grub_state)
    grub_stale=$(sudo sh -c 'grep -q catppuccin-mocha-grub/theme.txt /boot/grub2/grub.cfg 2>/dev/null &&
        [ ! /etc/default/grub -nt /boot/grub2/grub.cfg ] || echo yes')

    sudo mkdir -p "$theme"
    sudo cp -r grub/catppuccin-mocha-grub/. "$theme"
    [[ -e /etc/default/grub.fdwm.bak ]] || sudo cp /etc/default/grub /etc/default/grub.fdwm.bak
    # Rewrite the two settings only when they differ, so the file's timestamp
    # (checked above) only moves when something really changed.
    grub_want=$(printf 'GRUB_TERMINAL_OUTPUT="gfxterm"\nGRUB_THEME="%s/theme.txt"' "$theme")
    if [[ $(grep -E '^GRUB_(TERMINAL_OUTPUT|THEME)=' /etc/default/grub || true) != "$grub_want" ]]; then
        sudo sed -i '/^GRUB_THEME=/d; /^GRUB_TERMINAL_OUTPUT=/d' /etc/default/grub
        printf '%s\n' "$grub_want" | sudo tee -a /etc/default/grub >/dev/null
    fi
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

    # Catppuccin on the ttys from the moment the kernel starts, login prompt
    # included: the kernel's console palette, the same 16 colors .bashrc loads
    # after login (0 = background #1e1e2e, 7 = text #cdd6f4). grubby adds them
    # to every kernel entry and keeps them for future kernels.
    vt_red='vt.default_red=30,203,166,249,137,243,148,205,88,203,166,249,137,243,148,166'
    vt_grn='vt.default_grn=30,166,227,226,180,139,226,214,91,166,227,226,180,139,226,173'
    vt_blu='vt.default_blu=46,247,161,175,250,168,213,244,112,247,161,175,250,168,213,200'
    # (grep reads everything rather than -q, which could SIGPIPE the pipeline
    # and make pipefail report a failure even when a kernel needs the colors)
    if sudo grubby --info=ALL | grep '^args=' | grep -vF "$vt_blu" >/dev/null; then
        sudo grubby --update-kernel=ALL --args="$vt_red $vt_grn $vt_blu"
        echo "Console colors set for every kernel; they apply from the next boot"
    fi

    if [[ $grub_stale || $(grub_state) != "$grub_before" ]]; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        echo "GRUB settings and theme unchanged; grub.cfg left as it is"
    fi
else
    echo "GRUB 2 not found, skipped"
fi

if [[ -n ${DISPLAY:-} ]]; then
    echo "==> Done. Press Alt+Shift+W to restart dwm on the new build."
else
    echo "==> Done. Reboot, or log in on tty1, to start dwm."
fi
