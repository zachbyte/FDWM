# FDWM

A minimal dwm, st and dmenu setup for Fedora.

## 1. Install dependencies

Installs git, the compiler, the X server, xinit, a fallback font, and the libraries dwm, st and dmenu link against.

```shell
sudo dnf install git gcc make pkgconf-pkg-config \
    xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput \
    libX11-devel libXft-devel libXinerama-devel libXrender-devel \
    libxcb-devel fontconfig-devel freetype-devel \
    dejavu-sans-mono-fonts
```

## 2. Clone the repo

```shell
git clone https://github.com/zachbyte/FDWM
cd FDWM
```

## 3. Build and install

```shell
cd suckless/dwm && sudo make clean install && cd ../..
cd suckless/st && sudo make clean install && cd ../..
cd suckless/dmenu && sudo make clean install && cd ../..
```

## 4. Start dwm

Once dwm is running, `Alt + X` opens st and `Alt + R` opens dmenu.

```shell
echo "exec dwm" > ~/.xinitrc
startx
```

## 5. Extras (optional)

The configs in `extra/` are used by copying them to where each program looks for them.

```shell
mkdir -p ~/.config/picom
cp -r extra/nvim extra/cava extra/fastfetch extra/qt5ct extra/gtk-3.0 ~/.config/
cp extra/picom.conf ~/.config/picom/
sudo cp -r extra/BreezeX-Black /usr/share/icons/
sudo cp -r extra/gtk-3.0/catppuccin-mocha /usr/share/themes/
```

The GRUB theme is enabled by copying it into place, pointing `/etc/default/grub` at it, and regenerating the GRUB config.

```shell
sudo cp -r extra/grub/catppuccin-mocha-grub /boot/grub2/themes/
echo 'GRUB_THEME="/boot/grub2/themes/catppuccin-mocha-grub/theme.txt"' | sudo tee -a /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

`extra/.xinitrc`, `extra/.zshrc` and `extra/.zprofile` are the author's own files and need their paths edited before you use them.
