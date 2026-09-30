# FDWM

A minimal dwm, st, dmenu and slock setup for Fedora.

## Quick install

The commands below clone the repo (step 1), then `install.sh` runs steps 2 to 7 for you (only installing packages that are missing); run it as your normal user. Any existing `~/.xinitrc`, `~/.bashrc`, `~/.bashrc.d/claude.sh` or `~/.config/nvim` that differs is moved to a `.bak.<time>` copy first.

```shell
sudo dnf install -y git
git clone https://github.com/zachbyte/FDWM
cd FDWM
./install.sh
```

Then reboot and log in on tty1: dwm starts. (Earlier versions logged tty1 in automatically; `install.sh` now removes that.)

## Updating

`update.sh` pulls the latest commits into your checkout and then runs `install.sh`, so one command installs any missing packages, rebuilds dwm, st, dmenu and slock, and reapplies the dotfiles and GRUB theme; press `Alt + Shift + W` afterwards to restart dwm on the new build. It stops without changing anything if you have uncommitted changes or unpushed commits, or if your branch has no upstream; your stashes and other branches are never touched. A dotfile you edited in your home folder is moved to a `.bak.<time>` copy before the repo's version replaces it, so make lasting changes in `dotfiles/`.

```shell
./update.sh
```

## Manual install

To do it by hand instead, follow the steps below.

### 1. Clone the repo

```shell
sudo dnf install -y git
git clone https://github.com/zachbyte/FDWM
cd FDWM
```

### 2. Install dependencies

`packages.txt` lists every package FDWM uses, grouped by what needs it: building dwm, st, dmenu and slock; X and the session `.xinitrc` starts; sound and the media keys; nnn; and Neovim with what its plugins need.

```shell
sudo dnf install $(sed 's/#.*//' packages.txt)
```

### 3. Install the font

The configs use JetBrainsMono Nerd Font, which Fedora doesn't package, so this fetches and checks the upstream release.

```shell
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz
echo "04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf  JetBrainsMono.tar.xz" | sha256sum -c -
sudo mkdir -p /usr/local/share/fonts/JetBrainsMonoNerdFont
sudo tar -xJf JetBrainsMono.tar.xz -C /usr/local/share/fonts/JetBrainsMonoNerdFont JetBrainsMonoNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf
sudo fc-cache -f
rm JetBrainsMono.tar.xz
```

### 4. Build and install

Each tool is built as you and only installed as root (slock's install makes it setuid root, which it needs to check your password).

```shell
for tool in dwm st dmenu slock; do
    make -C suckless/$tool clean all
    sudo make -C suckless/$tool install
done
```

### 5. Set up the session

`dotfiles/.xinitrc` starts the keyring, the polkit agent, and the battery charge and clock in the bar before dwm; PipeWire gives you sound and the media keys.

```shell
cp dotfiles/.xinitrc ~/.xinitrc
```

Add the autostart from `dotfiles/.bash_profile` to your own `~/.bash_profile`, so logging in on tty1 starts dwm.

```shell
sed -n '/^# Start dwm/,$p' dotfiles/.bash_profile >> ~/.bash_profile
```

`dotfiles/.bashrc` sets the prompt (git branch and directory), history, aliases and git shortcuts, gives the ttys the same Catppuccin colors as st and dwm once you log in, and loads every file in `~/.bashrc.d`. `dotfiles/.bashrc.d/claude.sh` adds `cl` for Claude Code.

```shell
cp dotfiles/.bashrc ~/.bashrc
mkdir -p ~/.bashrc.d
cp dotfiles/.bashrc.d/claude.sh ~/.bashrc.d/
```

| Keys | Action |
| --- | --- |
| `Alt + X` / `Alt + R` | Open st / dmenu |
| `Alt + T` / `F` / `M` | Tiled / floating / monocle layout |
| `Alt + Space` | Switch to the previous layout |
| `Alt + Return` | Move the focused window into the master area |
| `Alt + Q` / `Alt + Shift + Q` | Close the window / quit dwm |
| `Alt + Shift + L` | Lock the screen (slock; type your password and press Return) |

### 6. Neovim and GRUB theme

The config needs Neovim 0.12 or newer (Fedora 44 or newer) and installs its plugins, parsers and language servers the first time it starts.

```shell
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
sudo grubby --update-kernel=ALL --args="vt.default_red=30,203,166,249,137,243,148,205,88,203,166,249,137,243,148,166 vt.default_grn=30,166,227,226,180,139,226,214,91,166,227,226,180,139,226,173 vt.default_blu=46,247,161,175,250,168,213,244,112,247,161,175,250,168,213,200"
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

The `grubby` line gives the ttys the Catppuccin palette from boot, login prompt included (the `vt.default_*` numbers are the red, green and blue of the same 16 colors `.bashrc` uses).

### 7. File manager

`nnn`, installed in step 2, is a terminal file manager: run `nnn`, press `?` for its keys, and text files open in Neovim.

## Applied patches

The source already includes these, so there is nothing to apply.

- dwm: activetagindicatorbar, actualfullscreen, alwayscenter, attachbottom, centretitle, colorbar, dragmfact, noborderflicker, preserveonrestart, resizehere, restartsig, tiledmove, togglefloatingcenter, uselessgap
- st: anysize, scrollback, scrollback-mouse, scrollback-mouse-altscreen
- slock: no patches; `config.h` sets Catppuccin colors (base #1e1e2e while locked, surface1 #45475a while you type, red #f38ba8 only after a wrong password) and drops privileges to Fedora's `nobody` group

How dwm behaves with these:

- A new floating window (a dialog, or a match in `rules`) keeps the size it asks for and opens centered. `Alt + Shift + Space` floats the focused window at 800×500, centered.
- Floating windows stay within their size hints (minimum, maximum, aspect ratio) when resized with the mouse, and can't be dragged completely off screen.
- tiledmove: dragging a tiled window with `Alt + left mouse button` over another swaps their places in the stack; each window keeps its own size hints and tags.
- preserveonrestart: windows that are open when dwm restarts (`Alt + Shift + W`) keep their tags; a new window gets the tags from its match in `rules` in `config.h`, or else the tags you're viewing.
