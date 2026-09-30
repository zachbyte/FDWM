#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        # shellcheck source=/dev/null
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets)"
export GNOME_KEYRING_CONTROL

/usr/libexec/polkit-mate-authentication-agent-1 &

# notifications: dunst, in the palette's colors (see ~/.config/dunst)
dunst &

# the status text in dwm's bar: volume, brightness, battery and the clock
"$HOME/.local/bin/fdwm-bar" &

# the desktop behind the windows (and between them) in the palette's base;
# fdwm-theme writes colors.sh from the palette file in the repo
colors=${XDG_CONFIG_HOME:-$HOME/.config}/fdwm/colors.sh
# shellcheck source=/dev/null
[ -r "$colors" ] && . "$colors"
[ -n "${fdwm_base:-}" ] && xsetroot -solid "$fdwm_base"

# After 5 minutes without input, lock with slock and turn the screen off.
# xss-lock runs slock when X's screensaver timer fires, and also locks
# before the laptop suspends (lid closed, suspend key).
xset s 300 300
xset dpms 300 300 300
xss-lock -- slock &

exec dwm

