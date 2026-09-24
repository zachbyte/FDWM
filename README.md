# FDWM

A minimal dwm, st and dmenu setup for Fedora.

## Quick install

`install.sh` runs steps 1 to 7 for you (only installing packages that are missing); run it as your normal user. Any existing `~/.xinitrc`, `~/.bashrc` or `~/.config/nvim` that differs is moved to a `.bak.<time>` copy first.

```shell
sudo dnf install -y git
git clone https://github.com/zachbyte/FDWM
cd FDWM
./install.sh
```

Then reboot: tty1 logs you in automatically and dwm starts.

## Updating

`update.sh` reclones the repo and then runs `install.sh`, so one command installs any missing packages, rebuilds dwm, st and dmenu, and reapplies the dotfiles, autologin and GRUB theme; press `Alt + Shift + W` afterwards to restart dwm on the new build. It stops without changing anything if you have uncommitted changes or unpushed commits. A dotfile you edited in your home folder is moved to a `.bak.<time>` copy before the repo's version replaces it, so make lasting changes in `dotfiles/`.

```shell
./update.sh
```

## Manual install

To do it by hand instead, follow the steps below.

### 1. Install dependencies

Installs git, the compiler, the X server, xinit, a fallback font, and the libraries dwm, st and dmenu link against.

```shell
sudo dnf install git gcc make pkgconf-pkg-config tar xz \
    xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput \
    libX11-devel libXft-devel libXrender-devel \
    fontconfig-devel freetype-devel \
    dejavu-sans-mono-fonts
```

### 2. Install the font

The configs use JetBrainsMono Nerd Font, which Fedora doesn't package, so this fetches and checks the upstream release.

```shell
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz
echo "04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf  JetBrainsMono.tar.xz" | sha256sum -c -
sudo mkdir -p /usr/local/share/fonts/JetBrainsMonoNerdFont
sudo tar -xJf JetBrainsMono.tar.xz -C /usr/local/share/fonts/JetBrainsMonoNerdFont JetBrainsMonoNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf
sudo fc-cache -f
rm JetBrainsMono.tar.xz
```

### 3. Clone the repo

```shell
git clone https://github.com/zachbyte/FDWM
cd FDWM
```

### 4. Build and install

```shell
cd suckless/dwm && sudo make clean install && cd ../..
cd suckless/st && sudo make clean install && cd ../..
cd suckless/dmenu && sudo make clean install && cd ../..
```

### 5. Set up the session

`dotfiles/.xinitrc` starts the keyring, the polkit agent, and the battery charge and clock in the bar before dwm; PipeWire gives you sound and the media keys.

```shell
sudo dnf install xsetroot gnome-keyring mate-polkit \
    pipewire wireplumber pipewire-pulseaudio brightnessctl playerctl
cp dotfiles/.xinitrc ~/.xinitrc
```

Add the autostart from `dotfiles/.bash_profile` to your own `~/.bash_profile`, so logging in on tty1 starts dwm.

```shell
sed -n '/^# Start dwm/,$p' dotfiles/.bash_profile >> ~/.bash_profile
```

To skip the login prompt too, have tty1 log you in automatically. Anyone at the machine then gets your session, and apps that use the keyring ask for your password the first time instead of it unlocking at login.

```shell
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty -o %s --noreset --noclear --autologin %s - ${TERM}\n' "'-p -f -- \\\\u'" "$USER" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf
sudo systemctl daemon-reload
```

`dotfiles/.bashrc` sets the prompt (git branch and directory), history, aliases and git shortcuts.

```shell
cp dotfiles/.bashrc ~/.bashrc
```

| Keys | Action |
| --- | --- |
| `Alt + X` / `Alt + R` | Open st / dmenu |
| `Alt + T` / `F` / `M` | Tiled / floating / monocle layout |
| `Alt + Space` | Switch to the previous layout |
| `Alt + Return` | Move the focused window into the master area |
| `Alt + Q` / `Alt + Shift + Q` | Close the window / quit dwm |

### 6. Neovim and GRUB theme

The config needs Neovim 0.12 or newer (Fedora 44 or newer) and installs its plugins, parsers and language servers the first time it starts.

```shell
sudo dnf install neovim ripgrep unzip tree-sitter-cli /usr/bin/npm java-latest-openjdk-headless
mkdir -p ~/.config
cp -r dotfiles/.config/nvim ~/.config/
```

The GRUB theme needs graphical output, and Fedora hides the menu when only one OS is installed. The rest removes the rescue entry and gives each kernel a short title such as `Fedora 6.16.7`, including future kernel updates.

```shell
sudo cp -r grub/catppuccin-mocha-grub /boot/grub2/themes/
sudo sed -i '/^GRUB_THEME=/d; /^GRUB_TERMINAL_OUTPUT=/d' /etc/default/grub
printf 'GRUB_TERMINAL_OUTPUT="gfxterm"\nGRUB_THEME="/boot/grub2/themes/catppuccin-mocha-grub/theme.txt"\n' | sudo tee -a /etc/default/grub
sudo grub2-editenv - unset menu_auto_hide
sudo dnf remove dracut-config-rescue
sudo sh -c 'rm -f /boot/loader/entries/*-0-rescue.conf /boot/vmlinuz-0-rescue-* /boot/initramfs-0-rescue-*.img'
sudo install -m 755 grub/60-fdwm-title.install /etc/kernel/install.d/
sudo sh -c 'for e in /boot/loader/entries/*.conf; do /etc/kernel/install.d/60-fdwm-title.install add "$(sed -n "s/^version[[:space:]]*//p" "$e")"; done'
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### 7. File manager

`nnn` is a terminal file manager: run `nnn`, press `?` for its keys, and text files open in Neovim.

```shell
sudo dnf install nnn
```

## Applied patches

The source already includes these, so there is nothing to apply.

- dwm: activetagindicatorbar, actualfullscreen, alwayscenter, attachbottom, centretitle, colorbar, dragmfact, noborderflicker, preserveonrestart, resizehere, restartsig, tiledmove, togglefloatingcenter, uselessgap
- st: anysize, scrollback, scrollback-mouse
