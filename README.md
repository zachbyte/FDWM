# FDWM

A minimal dwm, st, dmenu and slock setup for Fedora.

## Quick install

The commands below clone the repo (step 1), then `install.sh` runs steps 2 to 7 for you (only installing packages that are missing); run it as your normal user. Any existing `~/.xinitrc`, `~/.local/bin/fdwm-bar`, `~/.local/bin/fdwm-shot`, `~/.local/bin/fdwm-menu`, `~/.local/bin/fdwm-theme-menu`, `~/.local/bin/zen`, `~/.bashrc`, `~/.bashrc.d/claude.sh`, `~/.config/nvim`, `~/.config/dunst/dunstrc`, `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini` or `~/.config/xdg-desktop-portal/portals.conf` that differs is moved to a `.bak.<time>` copy first.

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

## Screenshots

`Print` lets you drag out a region, outlined in the palette's accent color (`Escape` or a right click cancels); `Shift + Print` takes the whole screen. Either way `fdwm-shot` (in `dotfiles/.local/bin`, installed to `~/.local/bin`) saves a PNG named for the time in `~/Pictures/Screenshots` and copies it to the clipboard, so you can paste it straight away. maim takes the screenshot and xclip copies it.

## The keys

`Alt + /` opens `fdwm-keys` (in `dotfiles/.local/bin`, installed to `~/.local/bin`): every key and mouse button dwm has, in dmenu, grouped as windows, tags, layouts, apps and system, with what each does. Type a few letters to filter it; `Escape` closes it. The tag keys are one row each (`Alt+1-9` and so on).

The descriptions live in `suckless/dwm/config.h`, at the end of each key and button, as `/* group: what it does */`. `install.sh` (and `install.sh --colors`, so a theme switch too) reads them with `keys.awk` and writes the list to `~/.config/fdwm/keys`, which is all `fdwm-keys` reads. So when you add or change a key, give it a description: a key without one, an unknown group, or a line `keys.awk` can't read stops `install.sh` before it builds anything, naming the line of `config.h`.

## Scratchpads

Two floating windows that one key shows and hides again, over whatever tag you're on:

- `` Alt + ` ``: a terminal (st)
- `Alt + N`: your notes, Neovim on `~/notes.md`, which is created the first time you save

The first press starts it, centered and at 60% of the screen across and down, and gives it the focus. The next press hides it and the one after brings the same window back, still centered, with whatever you left in it. Closing the window (quitting the shell, or `:q`) means the next press starts a fresh one. `Alt + 0`, which shows every tag, leaves the scratchpads out. They come from the scratchpads patch (see "Patches"): each is a tag of its own that a rule in `config.h` gives the st started with its instance name (`st -n spterm`, `st -n spnotes`), so another command or size is a change to `scratchpads[]`, `spfact` and `rules` there.

## Window swallowing

A graphical program you start from st, like an image viewer or a video, takes the terminal's place: the same spot in the layout, on the same tags, and the focus if the terminal had it. The terminal comes back where it was when the program closes. Only one program at a time takes a terminal's place: a second one started from the same st (in the background, say) opens on its own.

It is dwm that decides: it asks the X server which process made the new window and follows that process's parents in `/proc` up to an st window. Some things open on their own instead:

- a window that floats (a dialog, a fixed size, a match in `rules` that floats it); set `swallowfloating` to 1 in `config.h` to swallow those too
- anything started from a scratchpad or the theme menu, whose st isn't a terminal for this
- a window whose rule sets `noswallow`, like `xev`'s "Event Tester", which is no use without the terminal it prints to
- a program that detaches itself (a double fork, `setsid -f`), whose parent is then no longer the shell in st

A restart (`Alt + Shift + W`) keeps a program in its terminal's place. Which windows are terminals is the `isterminal` column of `rules` in `config.h`, so another terminal is one more rule (`xprop WM_CLASS` gives its class).

## The power menu

`Alt + Shift + E` opens `fdwm-menu` (in `dotfiles/.local/bin`, installed to `~/.local/bin`), a dmenu list of lock, suspend, restart dwm, log out, reboot and power off; type a few letters or use the arrow keys, then Return. Log out, reboot and power off ask `no` / `yes` first, and `Escape` leaves either list without doing anything. Lock runs slock, suspend locks too (xss-lock), restart dwm is `Alt + Shift + W` and log out is `Alt + Shift + Q`.

## The bar

On the left, dwm draws the tags. The one you're viewing is underlined in the accent (the palette's `ui_accent`), and a tag holding windows has a small square in its top left corner, in the bar's text color (`ui_text`): filled if the focused window is on it, empty otherwise. The scratchpads don't count.

On the right, `fdwm-bar` (in `dotfiles/.local/bin`, installed to `~/.local/bin`) writes dwm's status text: volume (a muted icon when muted), screen brightness, battery and the clock. It redraws every minute, at once when you press the volume, mute or brightness keys, which run `fdwm-bar refresh`, and at once when the volume or mute changes anywhere else (an app's own slider, headphones plugged in, another default output), which `pactl subscribe` reports, or a charger is plugged in or out, which `udevadm monitor` reports. Both run as long as the bar does and stop with it; if one ends, as `pactl` does when PipeWire restarts, it starts again 2 seconds later (waiting longer, up to a minute, while it keeps ending straight away). Anything the machine doesn't have, like a battery or a backlight on a desktop, is left out.

When the battery is discharging and reaches 10%, the bar shows `LOW BATTERY, PLUG IN` and dunst pops up a critical notification that stays until you click it; at 3% the laptop suspends. Each happens once per discharge and re-arms when you plug in, which also replaces the notification with a short `Charging` one. Both are hooks at the top of the script (`on_low_battery` and `on_battery_back`); without a notification daemon the bar still warns.

TLP looks after battery life: on battery it sets the CPU, Wi-Fi, USB, PCIe and disks to save power, and puts them back on the charger. `install.sh` turns it on, with the CPU and the platform leaning all the way to saving power on battery (`/etc/tlp.d/01-fdwm.conf`), and removes tuned, tuned-ppd and power-profiles-daemon, which would fight it. `sudo tlp-stat -s` shows whether it's running and on which power source. Your own settings go in a later file, such as `/etc/tlp.d/02-mine.conf`; for example, `STOP_CHARGE_THRESH_BAT0=80` and `START_CHARGE_THRESH_BAT0=75` keep a ThinkPad that's mostly plugged in from charging past 80%, which wears the battery less (`sudo tlp fullcharge` charges to 100% once, before a trip), and `CPU_BOOST_ON_BAT=0` saves more at the cost of speed. `sudo powertop` shows what's using power.

To see the line it would draw, without warning or suspending:

```shell
fdwm-bar print
```

## Notifications

dunst shows notifications (anything that runs `notify-send`) in the top right corner under the bar, in dwm's font. `dotfiles/.config/dunst/dunstrc` sets the layout and how long each kind stays: 5 seconds for low urgency, 8 for normal, and critical ones until you click them. Left click closes one, right click closes them all, and middle click runs its action. The colors come from the palette (see "Colors" below): the frame is the accent color, or red when critical. To try it:

```shell
notify-send "Hello" "from dunst"
```

## Colors

Every color is written down once, in `palette`: one column per flavor, each color as `rrggbb` under Catppuccin's names (`base`, `text`, `blue` and so on), which every flavor fills with its own colors; which of them the bar's text (`ui_text`), the accent (`ui_accent`: the selected tag's underline, the focused window's border, dmenu's selection, dunst's frame and the screenshot outline) and the other windows' borders (`ui_border`) are, and the bash prompt's branch (`prompt_branch`) and directory (`prompt_dir`); and which ones the terminal uses for its 16 colors, text, background and cursor. There is one flavor, dark like everything else (see "Dark mode" below):

- `thinkpad`: made to sit with a ThinkPad X1 Carbon: the soft black of its case behind everything, so the screen runs into the bezel, charcoal like its keys, silver like its lettering for text, and the TrackPoint's red as the one accent: the selected tag's underline, the focused window's border, dmenu's selection, notification frames, the screenshot outline, the terminal cursor, the prompt's directory and a wrong password on the lock screen. Code is in muted colors, with IBM's blue for functions.

`fdwm-theme generate`, which `install.sh` runs before building, writes the rest from it, in the flavor saved in `~/.config/fdwm/flavor` (the palette's first column, `thinkpad`, until there is one):

- `suckless/colors.h`, which the `config.h` of dwm, st, dmenu and slock include (`COL_BASE`, `COL_LAVENDER` and so on)
- `grub/theme/theme.txt`, the GRUB theme's colors, from `grub/theme.txt.in`, and `grub/theme/select_c.png`, the bar behind the selected boot entry (one pixel, which GRUB stretches)
- `~/.config/fdwm/colors.sh`, which `.bashrc` (the prompt and the ttys), `.xinitrc` (the desktop behind the windows) and Neovim read
- `~/.config/dunst/dunstrc.d/50-fdwm-colors.conf`, dunst's colors, from `dunst/colors.conf.in`; dunst reads it after `~/.config/dunst/dunstrc`

`fdwm-theme kernel-args` prints the kernel options that color the ttys from boot. The generated files say so at the top, and git ignores the ones in the repo. To change a color, edit `palette` and run `./install.sh`.

A new flavor is another column in `palette`. To switch flavors:

```shell
fdwm-theme thinkpad
```

Or press `Alt + Shift + T`: `fdwm-theme-menu` (in `dotfiles/.local/bin`, installed to `~/.local/bin`) lists the flavors in dmenu, with the one in use in the prompt, and switches to the one you pick in a small floating st, where it asks for your password and stays open until you press Return. `Escape`, or the flavor already in use, changes nothing.

`fdwm-theme` (which `install.sh` links into `~/.local/bin`) saves the flavor and runs `install.sh --colors`, which does only what a change of colors needs: it regenerates the colors, rebuilds dwm, st, dmenu and slock, and installs each of them, the GRUB theme and the ttys' boot colors only if it changed, so it asks for your password only when something needs installing. It leaves packages, the font, your dotfiles, suspend and the GRUB settings alone, and never runs `grub2-mkconfig` (`install.sh` alone does all of that). To tell what changed without your password, `install.sh` writes down the GRUB theme and boot colors it last installed in `~/.local/state/fdwm`. Then `fdwm-theme` repaints the desktop, recolors every open st window, has dunst reload its colors (or restarts it, if it won't) and restarts dwm, keeping your windows where they are: nothing there needs restarting by hand. dmenu and slock show the new flavor the next time they open, the prompt in open shells from their next prompt (they rebuild it from `colors.sh` each time), Neovim when it next starts, and the ttys and GRUB from the next boot. `install.sh` and `update.sh` keep the saved flavor, and `fdwm-theme` alone says which one is in use. A saved flavor that is no longer in the palette (Latte, Mocha and Tokyo Night, which FDWM had before) is `thinkpad` from the next `install.sh` on.

## Dark mode

Apps that can be light or dark are told to be dark, so Zen Browser, Thunar and the sites you visit (those that follow your system's preference) match the desktop. There are two ways an app asks, and `install.sh` answers both:

- GTK apps such as Thunar read `~/.config/gtk-3.0/settings.ini` (and `gtk-4.0`), which prefer the dark variant of their theme.
- Flatpak apps such as Zen ask the settings portal. `xdg-desktop-portal-gtk` answers, reading the color scheme from gsettings, which `install.sh` sets to `prefer-dark`; `~/.config/xdg-desktop-portal/portals.conf` picks it under dwm, which names no desktop for the portal to go by.

An app that is already open takes it the next time it starts. To check what the portal tells apps (`1` is dark):

```shell
gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop \
    --method org.freedesktop.portal.Settings.ReadOne org.freedesktop.appearance color-scheme
```

## Tests

Every push runs CI on a Fedora 44 container (`.github/workflows/ci.yml`), so a change is compiled and tested before it reaches your laptop. It installs `packages.txt`, builds dwm, st, dmenu and slock with every warning an error, runs ShellCheck on every script, runs the tests in `tests/`, and loads the Neovim config headless with every plugin.

The tests run `install.sh`, `update.sh`, the GRUB step and the dotfiles against stubbed commands and throwaway directories, so they never touch your system. `tests/test_palette_refactor.sh` shows that moving the colors into `palette` changed none of them, and `tests/test_hardcoded_colors.sh` fails if any other file spells out a color (as hex, decimal or a terminal escape). `tests/test_scratchpad.sh` runs the built dwm on a virtual X screen (Xvfb) and presses the scratchpad keys, and `tests/test_swallow.sh` starts a small X program (`tests/xwin.c`) from st there and checks it takes the terminal's place and gives it back. `tests/test_tag_marker.sh` builds dwm in the ThinkPad flavor, where the bar's text and the accent differ, and reads the bar's pixels on a virtual screen to check each tag's square and the underline. Run them yourself with:

```shell
tests/run.sh
```

`tests/build.sh`, `tests/shellcheck.sh`, `tests/nvim-load.sh` and `tests/patches.sh` (see "Patches" below) are the other CI steps, if you want to run those too.

## Manual install

To do it by hand instead, follow the steps below.

### 1. Clone the repo

```shell
sudo dnf install -y git
git clone https://github.com/zachbyte/FDWM
cd FDWM
```

### 2. Install dependencies

`packages.txt` lists every package FDWM uses, grouped by what needs it: building dwm, st, dmenu and slock; X and the session `.xinitrc` starts; sound and the media keys; TLP, for battery life; nnn; Thunar; flatpak, for Zen Browser; what dark mode needs; and Neovim with what its plugins need.

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

`dotfiles/.xinitrc` starts the keyring, the polkit agent, dunst for notifications and the bar script `fdwm-bar` (see "The bar" and "Notifications" above) before dwm, and locks the screen with slock and turns it off after 5 minutes idle (or before the laptop suspends); after 10 minutes idle the laptop suspends (`fdwm-lock`, which xss-lock runs to lock, does that while the screen stays locked and untouched). Typing, the mouse or the touchpad keeps it unlocked, and so does a video player that holds off the screensaver while it plays; PipeWire gives you sound and the media keys.

```shell
cp dotfiles/.xinitrc ~/.xinitrc
install -Dm755 dotfiles/.local/bin/fdwm-shot ~/.local/bin/fdwm-shot
install -Dm755 dotfiles/.local/bin/fdwm-bar ~/.local/bin/fdwm-bar
install -Dm644 dotfiles/.config/dunst/dunstrc ~/.config/dunst/dunstrc
install -Dm755 dotfiles/.local/bin/fdwm-lock ~/.local/bin/fdwm-lock
install -Dm755 dotfiles/.local/bin/fdwm-menu ~/.local/bin/fdwm-menu
install -Dm755 dotfiles/.local/bin/fdwm-theme-menu ~/.local/bin/fdwm-theme-menu
install -Dm755 dotfiles/.local/bin/fdwm-keys ~/.local/bin/fdwm-keys
mkdir -p ~/.config/fdwm && awk -f keys.awk suckless/dwm/config.h >~/.config/fdwm/keys
```

Add the autostart from `dotfiles/.bash_profile` to your own `~/.bash_profile`, so logging in on tty1 starts dwm.

```shell
sed -n '/^# Start dwm/,$p' dotfiles/.bash_profile >> ~/.bash_profile
```

To suspend when the lid closes (logind's default, spelled out here). Leave logind's `IdleAction` alone: logind judges a session started from a tty by the tty, which X never touches, so it would suspend every few minutes while you work; `fdwm-lock` suspends after 10 idle minutes instead. Earlier versions of this step wrote `/etc/systemd/logind.conf.d/fdwm-idle.conf`, which the `rm` removes.

```shell
sudo mkdir -p /etc/systemd/logind.conf.d
sudo rm -f /etc/systemd/logind.conf.d/fdwm-idle.conf
printf '[Login]\nHandleLidSwitch=suspend\nHandleLidSwitchExternalPower=suspend\n' | sudo tee /etc/systemd/logind.conf.d/fdwm-lid.conf
sudo systemctl kill -s HUP systemd-logind
```

To turn on TLP for battery life (see "The bar" above), first remove whichever of the power managers that would fight it `rpm -q` shows installed (Fedora 41 and newer have tuned and tuned-ppd; FDWM's own install may have none):

```shell
rpm -q tuned-ppd tuned power-profiles-daemon
sudo dnf remove tuned-ppd tuned    # only those rpm -q found
sudo mkdir -p /etc/tlp.d
printf 'CPU_ENERGY_PERF_POLICY_ON_BAT=power\nPLATFORM_PROFILE_ON_BAT=low-power\n' | sudo tee /etc/tlp.d/01-fdwm.conf
sudo systemctl enable --now tlp.service
```

`dotfiles/.bashrc` sets the prompt (the git branch, then the directory, in the flavor's `prompt_branch` and `prompt_dir`), history, aliases and git shortcuts, gives the ttys the same colors as st and dwm once you log in, and loads every file in `~/.bashrc.d`. `dotfiles/.bashrc.d/claude.sh` adds `cl` for Claude Code.

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
| `Alt + Shift + J` / `K` | Move the focused window down / up the stack |
| `Alt + Q` / `Alt + Shift + Q` | Close the window / quit dwm |
| `Alt + Shift + E` | Power menu: lock, suspend, restart dwm, log out, reboot or power off (see "The power menu") |
| `Alt + Shift + T` | Theme menu: switch to another flavor in `palette` (see "Colors") |
| `Alt + /` | Every key and mouse button, described (see "The keys") |
| `Alt + Shift + L` | Lock the screen (slock; type your password and press Return) |
| `` Alt + ` `` / `Alt + N` | Show or hide the terminal / notes scratchpad (see "Scratchpads") |
| `Print` / `Shift + Print` | Screenshot of a region / the whole screen, saved and copied (see "Screenshots") |

### 6. Neovim and GRUB theme

The config needs Neovim 0.12 or newer (Fedora 44 or newer) and installs its plugins, parsers and language servers the first time it starts. Its colors are the desktop's: the Catppuccin colorscheme (Mocha) with each of its colors replaced by the palette's entry of the same name, as `fdwm-theme` last generated them, so it matches whichever flavor is in use from its next start.

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

The `grubby` line gives the ttys the palette's colors from boot, login prompt included (`fdwm-theme kernel-args` prints the red, green and blue of the same 16 colors `.bashrc` uses, as `vt.default_*` options).

### 7. File managers, Zen Browser and dark mode

`nnn`, installed in step 2, is a terminal file manager: run `nnn`, press `?` for its keys, and text files open in Neovim. Thunar, also from step 2, is the graphical one: run `thunar` (`Alt + R` finds it).

Fedora doesn't package Zen Browser, so it comes from Flathub, installed for you alone (no sudo), with a `zen` command that `Alt + R` finds:

```shell
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user --noninteractive flathub app.zen_browser.zen
install -Dm755 dotfiles/.local/bin/zen ~/.local/bin/zen
```

Then dark mode (see "Dark mode" above):

```shell
for f in gtk-3.0/settings.ini gtk-4.0/settings.ini xdg-desktop-portal/portals.conf; do
    install -Dm644 dotfiles/.config/$f ~/.config/$f
done
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
```

## Patches

The source in `suckless/` already includes every patch, so there is nothing to apply. It is also kept as a record: the upstream releases pinned in `patches/upstream` (dwm 6.5, st 0.9.2, dmenu 5.3, slock 1.5), and every change made to them since as a `.diff` in `patches/<tool>/`, applied in file-name order. Each diff starts with a few lines on what it is and where it came from. `tests/patches.sh`, which CI runs, downloads the releases, applies the diffs with `git apply` and fails unless the result is `suckless/` file for file. So a change to `suckless/` needs its diff in `patches/` too, as the last one for that tool.

The order:

- dwm (50)
  - 01–14: the upstream patches activetagindicatorbar, actualfullscreen, alwayscenter, attachbottom, centretitle, colorbar, dragmfact, noborderflicker, preserveonrestart, resizehere, restartsig, tiledmove, togglefloatingcenter and uselessgap, as they apply to 6.5. The three that needed fixing by hand (attachbottom, colorbar, resizehere) say how.
  - 15: FDWM's `config.h`.
  - 16: `import-edits`, the hand edits made when the patched dwm was first imported, before the repo had history.
  - 17–39: FDWM's changes since, one per commit: the floating window sizes (#2, #3), swapclients in tiledmove (#4), the preserveonrestart fix for `rules` (#6), the drw.c sync (#15), the Makefile and cleanup changes, the slock, bar-refresh, screenshot and power-menu keys, and the palette.
  - 40: the upstream scratchpads patch, merged by hand, with FDWM's two scratchpads.
  - 41: FDWM's scratchpad size and centering (60% of the screen, on the window's real size).
  - 42: the bar's text, the accent (the selected tag's underline and the focused window's border) and the other windows' borders, each from its own palette entry.
  - 43: the theme menu's key, `Alt + Shift + T`, and the rule that floats its st.
  - 44: cleanup: colorbar's extra color schemes, which all drew in the same colors as the normal one (the bar looks the same without them), `dmenumon`, unused since dmenu stopped being given a monitor, and the rule for feh, which FDWM doesn't install.
  - 45: a small square on each tag holding windows, in the bar's text color, filled on the focused window's tags: upstream dwm's marker, which activetagindicatorbar had turned into the underline and `import-edits` had taken out.
  - 46: each key and mouse button described in a comment, `/* group: what it does */`, for the list `fdwm-keys` shows, and `Alt + /`, which opens it; the man page says so.
  - 47: movestack, after the upstream patch of that name (https://dwm.suckless.org/patches/movestack/) but written on swapclients(): `Alt + Shift + J` / `K` swap the focused window with the next / previous tiled one, wrapping at the ends; a floating window stays put.
  - 48: pertag, after the upstream patch of that name (https://dwm.suckless.org/patches/pertag/): each tag's own layout, master area and bar, saved whenever one changes (`setlayout`, `setmfact`, `resetmfact`, `incnmaster`, `togglebar` and dragmfact's drag in `resizemouse`) and restored by `view` and `toggleview`; the scratchpads' tags never pick the slot.
  - 49: window swallowing, after bakkeby's version of the upstream swallow patch (https://dwm.suckless.org/patches/swallow/), which puts the program in the terminal's place in the lists rather than swapping their windows: `isterminal` and `noswallow` in `rules`, the process found through the X-Resource extension (xcb-res, so `libxcb-devel` in `packages.txt`) and its parents through `/proc`, Linux only. FDWM's own: st's rule comes first so the scratchpads' and the theme menu's rules turn it off again, a swallowed program isn't recentered by alwayscenter, and `scan()` manages the terminals before the other windows so a restart swallows again.
  - 50: the tags as EWMH desktops, after the upstream ewmhtags patch (https://dwm.suckless.org/patches/ewmhtags/): nine desktops named after the tags, the current one (the lowest tag in view), each window's (`_NET_WM_DESKTOP`), and requests to switch or move from a pager or `xdotool`; the scratchpads' tags aren't desktops.
- st (10): the upstream patches anysize, scrollback and scrollback-mouse; `config.h`; `upstream-csi-colon`, a fix from st's development version after 0.9.2; `import-edits`; then FDWM's changes: scrollback-mouse-altscreen (the wheel scrolls pagers on the alternate screen, #7), the Makefile changes and the palette.
- dmenu (11): `config.h`; `upstream-drw-utf8`, drw.c from dmenu's development version after 5.3; `import-edits`; then FDWM's changes: one monitor, the version fixed to 5.3, the Makefile changes, the palette, and its text and selection from the same palette entries as dwm's.
- slock (4): `config.h` (Catppuccin colors, dropping privileges to Fedora's `nobody` group) and the Makefile, as slock was built from source; the softer colors (base while locked, surface1 while you type, red only after a wrong password); and the palette.

### Moving to a new upstream release

1. Download the new release and put its version, URL and `sha256sum` in `patches/upstream`, and its version in `suckless/<tool>/config.mk`.
2. Rebuild it from the diffs, keeping the result:

   ```shell
   tests/patches.sh --keep ~/fdwm-upgrade
   ```

   For each tool it stops at the first diff that no longer applies, and leaves `~/fdwm-upgrade/<tool>` as a git repository with the new release and one commit per diff that did apply.
3. In that folder, apply the failing diff by hand with `patch -p1 --merge < ~/FDWM/patches/<tool>/NN-name.diff`, and fix the conflicts it marks. Then `git diff` is the diff's new version: write it over the old one, keeping the lines at its top, and run step 2 again. A diff that the new release already contains, such as an `upstream-*` one, can simply be deleted.
4. Once every tool rebuilds, copy the rebuilt trees into `suckless/`, then check that the record and the sources agree:

   ```shell
   for t in dwm st dmenu slock; do rm -rf suckless/$t && cp -r ~/fdwm-upgrade/$t suckless/$t && rm -rf suckless/$t/.git; done
   tests/patches.sh
   ```

How dwm behaves with these:

- A new floating window (a dialog, or a match in `rules`) keeps the size it asks for and opens centered. `Alt + Shift + Space` floats the focused window at 800×500, centered.
- Floating windows stay within their size hints (minimum, maximum, aspect ratio) when resized with the mouse, and can't be dragged completely off screen.
- tiledmove: dragging a tiled window with `Alt + left mouse button` over another swaps their places in the stack; each window keeps its own size hints and tags.
- preserveonrestart: windows that are open when dwm restarts (`Alt + Shift + W`) keep their tags; a new window gets the tags from its match in `rules` in `config.h`, or else the tags you're viewing.
- pertag: each tag keeps its own layout, master area size and number of master windows, and whether the bar shows, however you set them (keys, or dragging the master area's edge with `Alt + right mouse button`); `Alt + 0`, the view of every tag, has its own too. Going back with `Alt + Tab` brings back the previous tag's, and `Alt + Ctrl + N` keeps the current tag's while it stays in view. The scratchpads have none of their own and never change whose are in force. The settings last until dwm restarts (`Alt + Shift + W`, or a theme switch), which starts every tag from `config.h`'s again.

## Roadmap

Done:

- movestack: `Alt + Shift + J` / `K` move the focused window down or up the stack (patch 47).
- pertag: each tag remembers its own layout, master area and bar, the scratchpads' tags left out (patch 48).
- Window swallowing for st: a graphical program started from st (a video, an image) takes the terminal's place until it closes (patch 49, see "Window swallowing").
- EWMH desktops: other programs (a pager, an external bar, `xdotool set_desktop`) see the tags as desktops and which window is on which, and can switch tags and move windows (patch 50).

Quickshell, a Qt/QML toolkit for bars and widgets, is deferred: dwm's bar, `fdwm-bar` and dmenu already cover what FDWM needs, and Quickshell would add a resident Qt process, QML to maintain, and a dwm patch for dock windows (the EWMH desktops it would also need are in already) just to work with dwm on X11. Wanting a system tray or clickable widgets (sliders, a calendar, notification history) would change that.
