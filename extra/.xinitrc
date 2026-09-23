#!/bin/sh

xrandr --output HDMI-1 --primary --mode 2560x1440 --pos 0x0 --output eDP-1 --mode 1920x1080 --pos 2560x0

pamixer &
/usr/lib/polkit-kde-authentication-agent-1 &

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

/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

prev_date=""
prev_time=""

while true; do
    current_date=$(date "+%Y-%m-%d")
    current_time=$(date "+%I:%M %p")

    if [ "$current_date $current_time" != "$prev_date $prev_time" ]; then
        date_status="󰃭  $current_date"
        time_status="  $current_time"
        xsetroot -name "$date_status  $time_status"
        prev_date=$current_date
        prev_time=$current_time
    fi

    sleep 1
done &

picom --config ~/.config/picom/picom.conf &

hsetroot -solid "#1E1E2E"
exec dwm

