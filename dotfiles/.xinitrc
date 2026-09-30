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
    # battery: an icon for the charge level (or charging), then e.g. "85%";
    # stays empty on machines without a battery
    bat=""
    for d in /sys/class/power_supply/BAT*; do
        [ -r "$d/capacity" ] || continue
        read -r cap < "$d/capacity"
        read -r state < "$d/status"
        if [ "$state" = Charging ]; then
            icon=󰂄
        else
            case $((cap / 10)) in
                0) icon=󰂎 ;; 1) icon=󰁺 ;; 2) icon=󰁻 ;; 3) icon=󰁼 ;; 4) icon=󰁽 ;;
                5) icon=󰁾 ;; 6) icon=󰁿 ;; 7) icon=󰂀 ;; 8) icon=󰂁 ;; 9) icon=󰂂 ;; *) icon=󰁹 ;;
            esac
        fi
        bat="$icon  $cap%    "
        break
    done
    xsetroot -name "$bat$(date '+󰃭  %Y-%m-%d    %I:%M %p')"
    sleep $((60 - $(date +%-S)))
done &

xsetroot -solid "#1E1E2E"
exec dwm

