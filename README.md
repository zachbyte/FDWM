# FDWM

A minimal dwm, st and dmenu setup for Fedora.

## Quick install

`install.sh` runs steps 1 to 5 for you and never overwrites an existing `~/.xinitrc`; run it as your normal user.

```shell
sudo dnf install -y git
git clone https://github.com/zachbyte/FDWM
cd FDWM
./install.sh
startx
```

To do it by hand instead, follow the steps below.

## 1. Install dependencies

Installs git, the compiler, the X server, xinit, a fallback font, and the libraries dwm, st and dmenu link against.

```shell
sudo dnf install git gcc make pkgconf-pkg-config tar xz \
    xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput \
    libX11-devel libXft-devel libXinerama-devel libXrender-devel \
    fontconfig-devel freetype-devel \
    dejavu-sans-mono-fonts
```

## 2. Install the font

The configs use JetBrainsMono Nerd Font, which Fedora doesn't package, so this fetches and checks the upstream release.

```shell
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz
echo "04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf  JetBrainsMono.tar.xz" | sha256sum -c -
sudo mkdir -p /usr/local/share/fonts/JetBrainsMonoNerdFont
sudo tar -xJf JetBrainsMono.tar.xz -C /usr/local/share/fonts/JetBrainsMonoNerdFont JetBrainsMonoNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf
sudo fc-cache -f
rm JetBrainsMono.tar.xz
```

## 3. Clone the repo

```shell
git clone https://github.com/zachbyte/FDWM
cd FDWM
```

## 4. Build and install

```shell
cd suckless/dwm && sudo make clean install && cd ../..
cd suckless/st && sudo make clean install && cd ../..
cd suckless/dmenu && sudo make clean install && cd ../..
```

## 5. Start dwm

Once dwm is running, `Alt + X` opens st and `Alt + R` opens dmenu.

```shell
echo "exec dwm" > ~/.xinitrc
startx
```

## 6. Extras (optional)

Install the programs the configs in `extra/` are for, then copy each config to where its program looks for it.

```shell
sudo dnf install neovim cava fastfetch qt5ct
mkdir -p ~/.icons/default
cp -r extra/nvim extra/cava extra/fastfetch extra/qt5ct extra/gtk-3.0 ~/.config/
sudo cp -r extra/BreezeX-Black /usr/share/icons/
sudo cp -r extra/themes/catppuccin-mocha /usr/share/themes/
printf '[Icon Theme]\nInherits=BreezeX-Black\n' > ~/.icons/default/index.theme
```

Apply the Qt theme by putting this line above `exec dwm` in `~/.xinitrc`.

```shell
export QT_QPA_PLATFORMTHEME=qt5ct
```

The GRUB theme needs to be copied into place, set in `/etc/default/grub` (with graphical output), and the GRUB config regenerated.

```shell
sudo cp -r extra/grub/catppuccin-mocha-grub /boot/grub2/themes/
sudo sed -i '/^GRUB_THEME=/d; /^GRUB_TERMINAL_OUTPUT=/d' /etc/default/grub
printf 'GRUB_TERMINAL_OUTPUT="gfxterm"\nGRUB_THEME="/boot/grub2/themes/catppuccin-mocha-grub/theme.txt"\n' | sudo tee -a /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

`extra/.xinitrc`, `extra/.zshrc` and `extra/.zprofile` are the author's personal session and shell files (monitor layout, aliases), so read them before copying.

## Applied patches

The source already includes these, so there is nothing to apply.

- dwm: activetagindicatorbar, actualfullscreen, alwayscenter, attachbottom, centretitle, colorbar, dragmfact, noborderflicker, preserveonrestart, resizehere, restartsig, tiledmove, togglefloatingcenter, uselessgap
- st: anysize, scrollback, scrollback-mouse
