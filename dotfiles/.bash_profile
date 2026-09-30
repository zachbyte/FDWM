# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    # shellcheck source=/dev/null
    . ~/.bashrc
fi

# Start dwm when logging in on tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
    exec startx
fi
