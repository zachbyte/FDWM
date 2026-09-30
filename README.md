# FDWM

A minimal dwm, st, dmenu and slock setup for Fedora.

## Quick install

The commands below clone the repo (step 1), then `install.sh` runs steps 2 to 7 for you (only installing packages that are missing); run it as your normal user. Any existing `~/.xinitrc`, `~/.local/bin/fdwm-bar`, `~/.bashrc`, `~/.bashrc.d/claude.sh`, `~/.config/nvim` or `~/.config/dunst/dunstrc` that differs is moved to a `.bak.<time>` copy first.

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

## The bar

`fdwm-bar` (in `dotfiles/.local/bin`, installed to `~/.local/bin`) writes dwm's status text: volume (a muted icon when muted), screen brightness, battery and the clock. It redraws every minute, and at once when you press the volume, mute or brightness keys, which run `fdwm-bar refresh`. Anything the machine doesn't have, like a battery or a backlight on a desktop, is left out.

When the battery is discharging and reaches 10%, the bar shows `LOW BATTERY, PLUG IN`; at 3% the laptop suspends. Each happens once per discharge and re-arms when you plug in. `on_low_battery` at the top of the script is where a notification daemon hooks in: once `notify-send` is installed, the 10% warning also pops up.

To see the line it would draw, without warning or suspending:

```shell
fdwm-bar print
```

## Notifications

dunst shows notifications (anything that runs `notify-send`) in the top right corner under the bar, in dwm's font. `dotfiles/.config/dunst/dunstrc` sets the layout and how long each kind stays: 5 seconds for low urgency, 8 for normal, and critical ones until you click them. Left click closes one, right click closes them all, and middle click runs its action. The colors come from the palette (see "Colors" below): the frame is lavender, or red when critical. To try it:

```shell
notify-send "Hello" "from dunst"
```

## Colors

Every color is written down once, in `palette`: Catppuccin's dark Mocha and light Latte flavors as `rrggbb`, one column each, and which of their colors the terminal uses for its 16 colors, text, background and cursor. `fdwm-theme generate`, which `install.sh` runs before building, writes the rest from it, in the flavor saved in `~/.config/fdwm/flavor` (Mocha until there is one):

- `suckless/colors.h`, which the `config.h` of dwm, st, dmenu and slock include (`COL_BASE`, `COL_LAVENDER` and so on)
- `grub/theme/theme.txt`, the GRUB theme's colors, from `grub/theme.txt.in`, and `grub/theme/select_c.png`, the bar behind the selected boot entry (one pixel, which GRUB stretches)
- `~/.config/fdwm/colors.sh`, which `.bashrc` (the prompt and the ttys) and `.xinitrc` (the desktop behind the windows) read
- `~/.config/dunst/dunstrc.d/50-fdwm-colors.conf`, dunst's colors, from `dunst/colors.conf.in`; dunst reads it after `~/.config/dunst/dunstrc`

`fdwm-theme kernel-args` prints the kernel options that color the ttys from boot. The generated files say so at the top, and git ignores the ones in the repo. To change a color, edit `palette` and run `./install.sh`.

To switch between the dark and the light flavor:

```shell
fdwm-theme latte
fdwm-theme mocha
```

`fdwm-theme` (which `install.sh` links into `~/.local/bin`) saves the flavor and runs `install.sh`, which regenerates the colors and rebuilds dwm, st, dmenu, slock, the GRUB theme and the ttys' boot colors, so it asks for your password. Then it repaints the desktop, recolors every open st window, has dunst reload its colors and restarts dwm, keeping your windows where they are. dmenu and slock show the new flavor the next time they open, Neovim when it next starts, and the ttys and GRUB from the next boot. `install.sh` and `update.sh` keep the saved flavor, and `fdwm-theme` alone says which one is in use.

## Tests

Every push runs CI on a Fedora 44 container (`.github/workflows/ci.yml`), so a change is compiled and tested before it reaches your laptop. It installs `packages.txt`, builds dwm, st, dmenu and slock with every warning an error, runs ShellCheck on every script, runs the tests in `tests/`, and loads the Neovim config headless with every plugin.

The tests run `install.sh`, `update.sh`, the GRUB step and the dotfiles against stubbed commands and throwaway directories, so they never touch your system. `tests/test_palette_refactor.sh` shows that moving the colors into `palette` changed none of them, and `tests/test_hardcoded_colors.sh` fails if any other file spells out a color (as hex, decimal or a terminal escape). Run them yourself with:

```shell
tests/run.sh
```

`tests/build.sh`, `tests/shellcheck.sh` and `tests/nvim-load.sh` are the other CI steps, if you want to run those too.

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

Each tool is built as you and only installed as root (slock's install makes it setuid root, which it needs to check your password). `fdwm-theme generate` first writes the colors from `palette` (see "Colors" above): the tools' `colors.h`, the GRUB theme, `~/.config/fdwm/colors.sh` and dunst's colors.

```shell
./fdwm-theme generate
for tool in dwm st dmenu slock; do
    make -C suckless/$tool clean all
    sudo make -C suckless/$tool install
done
```

### 5. Set up the session

`dotfiles/.xinitrc` starts the keyring, the polkit agent, dunst for notifications and the bar script `fdwm-bar` (see "The bar" and "Notifications" above) before dwm, and locks the screen with slock and turns it off after 5 minutes idle (or before the laptop suspends); after 10 minutes idle the laptop suspends (see the logind step below); PipeWire gives you sound and the media keys.

```shell
cp dotfiles/.xinitrc ~/.xinitrc
install -Dm755 dotfiles/.local/bin/fdwm-bar ~/.local/bin/fdwm-bar
install -Dm644 dotfiles/.config/dunst/dunstrc ~/.config/dunst/dunstrc
```

Add the autostart from `dotfiles/.bash_profile` to your own `~/.bash_profile`, so logging in on tty1 starts dwm.

```shell
sed -n '/^# Start dwm/,$p' dotfiles/.bash_profile >> ~/.bash_profile
```

To suspend after 10 minutes without use, have logind act once the session has been idle (xss-lock marks it idle when the screen locks at 5 minutes) for 5 more minutes, and to suspend when the lid closes (logind's default, spelled out here):

```shell
sudo mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nIdleAction=suspend\nIdleActionSec=5min\nHandleLidSwitch=suspend\nHandleLidSwitchExternalPower=suspend\n' | sudo tee /etc/systemd/logind.conf.d/fdwm-idle.conf
sudo systemctl kill -s HUP systemd-logind
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

The config needs Neovim 0.12 or newer (Fedora 44 or newer) and installs its plugins, parsers and language servers the first time it starts. Its colors are Catppuccin in the flavor `fdwm-theme` last switched to.

```shell
mkdir -p ~/.config
cp -r dotfiles/.config/nvim ~/.config/
```

The GRUB theme needs graphical output, and Fedora hides the menu when only one OS is installed. The rest removes the rescue entry and gives each kernel a short title such as `Fedora 6.16.7`, including future kernel updates.

```shell
sudo rm -rf /boot/grub2/themes/fdwm
sudo cp -r grub/theme /boot/grub2/themes/fdwm
sudo sed -i '/^GRUB_THEME=/d; /^GRUB_TERMINAL_OUTPUT=/d' /etc/default/grub
printf 'GRUB_TERMINAL_OUTPUT="gfxterm"\nGRUB_THEME="/boot/grub2/themes/fdwm/theme.txt"\n' | sudo tee -a /etc/default/grub
sudo grub2-editenv - unset menu_auto_hide
sudo dnf remove dracut-config-rescue
sudo sh -c 'rm -f /boot/loader/entries/*-0-rescue.conf /boot/vmlinuz-0-rescue-* /boot/initramfs-0-rescue-*.img'
sudo install -m 755 grub/60-fdwm-title.install /etc/kernel/install.d/
sudo sh -c 'for e in /boot/loader/entries/*.conf; do /etc/kernel/install.d/60-fdwm-title.install add "$(sed -n "s/^version[[:space:]]*//p" "$e")"; done'
sudo grubby --update-kernel=ALL --args="$(./fdwm-theme kernel-args)"
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

The `grubby` line gives the ttys the Catppuccin palette from boot, login prompt included (`fdwm-theme kernel-args` prints the red, green and blue of the same 16 colors `.bashrc` uses, as `vt.default_*` options).

### 7. File manager

`nnn`, installed in step 2, is a terminal file manager: run `nnn`, press `?` for its keys, and text files open in Neovim.

## Applied patches

The source already includes these, so there is nothing to apply.

- dwm: activetagindicatorbar, actualfullscreen, alwayscenter, attachbottom, centretitle, colorbar, dragmfact, noborderflicker, preserveonrestart, resizehere, restartsig, tiledmove, togglefloatingcenter, uselessgap
- st: anysize, scrollback, scrollback-mouse, scrollback-mouse-altscreen
- slock: no patches; `config.h` sets Catppuccin colors (base while locked, surface1 while you type, red only after a wrong password) and drops privileges to Fedora's `nobody` group

How dwm behaves with these:

- A new floating window (a dialog, or a match in `rules`) keeps the size it asks for and opens centered. `Alt + Shift + Space` floats the focused window at 800×500, centered.
- Floating windows stay within their size hints (minimum, maximum, aspect ratio) when resized with the mouse, and can't be dragged completely off screen.
- tiledmove: dragging a tiled window with `Alt + left mouse button` over another swaps their places in the stack; each window keeps its own size hints and tags.
- preserveonrestart: windows that are open when dwm restarts (`Alt + Shift + W`) keep their tags; a new window gets the tags from its match in `rules` in `config.h`, or else the tags you're viewing.
