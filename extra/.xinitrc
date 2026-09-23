#!/bin/sh

xrandr --output HDMI-1 --primary --mode 2560x1440 --pos 0x0 --output eDP-1 --mode 1920x1080 --pos 2560x0

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
    eval $(dbus-launch --exit-with-session --sh-syntax)
fi

eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
export GNOME_KEYRING_CONTROL
export GNOME_KEYRING_PID

/usr/libexec/polkit-gnome-authentication-agent-1 &

while true; do
    xsetroot -name "$(date '+󰃭  %Y-%m-%d    %I:%M %p')"
    sleep $((60 - $(date +%-S)))
done &

hsetroot -solid "#1E1E2E"
exec dwm

