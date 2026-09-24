# FDWM

A minimal dwm, st, dmenu and slock setup for Fedora.

## Quick install

`install.sh` runs steps 1 to 6 for you; run it as your normal user. Any existing `~/.xinitrc`, `~/.bashrc` or `~/.config/nvim` that differs is moved to a `.bak.<time>` copy first.

```shell
sudo dnf install -y git
git clone https://github.com/zachbyte/FDWM
cd FDWM
./install.sh
```

Then log out and back in on tty1, and dwm starts.

## Updating

`update.sh` installs any packages that are missing, reclones the repo, and rebuilds dwm, st, dmenu and slock; press `Alt + Shift + W` afterwards to restart dwm on the new build. It stops without changing anything if you have uncommitted changes or unpushed commits, and it doesn't touch your dotfiles or the GRUB theme (run `./install.sh` for those).

```shell
./update.sh
```

## Manual install

To do it by hand instead, follow the steps below.

### 1. Install dependencies

Installs git, the compiler, the X server, xinit, a fallback font, and the libraries dwm, st, dmenu and slock link against.

```shell
sudo dnf install git gcc make pkgconf-pkg-config tar xz \
    xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput \
    libX11-devel libXft-devel libXinerama-devel libXrender-devel \
    fontconfig-devel freetype-devel libXext-devel libXrandr-devel libxcrypt-devel \
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
cd suckless/slock && sudo make clean install && cd ../..
```

### 5. Set up the session

`dotfiles/.xinitrc` starts the keyring, the polkit agent, the battery charge and clock in the bar, and a screen lock after 15 minutes idle or on suspend before dwm; PipeWire gives you sound and the media keys.

```shell
sudo dnf install xsetroot xset xss-lock gnome-keyring mate-polkit \
    pipewire wireplumber pipewire-pulseaudio brightnessctl playerctl
cp dotfiles/.xinitrc ~/.xinitrc
```

Add the autostart from `dotfiles/.bash_profile` to your own `~/.bash_profile`, so logging in on tty1 starts dwm.

```shell
sed -n '/^# Start dwm/,$p' dotfiles/.bash_profile >> ~/.bash_profile
```

`dotfiles/.bashrc` sets the prompt (git branch and directory), history, aliases and git shortcuts.

```shell
cp dotfiles/.bashrc ~/.bashrc
```

| Keys | Action |
| --- | --- |
| `Alt + X` / `Alt + R` | Open st / dmenu |
| `Alt + Shift + L` | Lock the screen (also locks itself after 15 minutes idle) |
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

The GRUB theme needs graphical output, and Fedora hides the menu when only one OS is installed.

```shell
sudo cp -r grub/catppuccin-mocha-grub /boot/grub2/themes/
sudo sed -i '/^GRUB_THEME=/d; /^GRUB_TERMINAL_OUTPUT=/d' /etc/default/grub
printf 'GRUB_TERMINAL_OUTPUT="gfxterm"\nGRUB_THEME="/boot/grub2/themes/catppuccin-mocha-grub/theme.txt"\n' | sudo tee -a /etc/default/grub
sudo grub2-editenv - unset menu_auto_hide
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

## Applied patches

The source already includes these, so there is nothing to apply. slock is unpatched upstream 1.5.

- dwm: activetagindicatorbar, actualfullscreen, alwayscenter, attachbottom, centretitle, colorbar, dragmfact, noborderflicker, preserveonrestart, resizehere, restartsig, tiledmove, togglefloatingcenter, uselessgap
- st: anysize, scrollback, scrollback-mouse
