#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

eval $(gnome-keyring-daemon --start --components=pkcs11,secrets)
export GNOME_KEYRING_CONTROL

/usr/libexec/polkit-mate-authentication-agent-1 &

while true; do
    xsetroot -name "$(date '+󰃭  %Y-%m-%d    %I:%M %p')"
    sleep $((60 - $(date +%-S)))
done &

xsetroot -solid "#1E1E2E"
exec dwm

