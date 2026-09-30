#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies and sed scripts expand later, not here
# install.sh's GRUB step with /etc and /boot moved into a sandbox: when it
# regenerates grub.cfg, and that it leaves /etc/default/grub tidy.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
SB=$T/sb
export LOG="$T/log" ARGS="$T/kernel-args"
mkdir -p "$T/repo" "$SB/etc/default" "$SB/etc/kernel/install.d" \
    "$SB/boot/grub2/themes" "$SB/boot/loader/entries"
cp -r "$ROOT/grub" "$T/repo/"
printf 'GRUB_TIMEOUT=5\nGRUB_ENABLE_BLSCFG=true\n' >"$SB/etc/default/grub"
printf 'title Fedora Linux (6.16.7-200.fc44.x86_64)\nversion 6.16.7-200.fc44.x86_64\n' \
    >"$SB/boot/loader/entries/abc-6.16.7-200.fc44.x86_64.conf"
echo 'args="ro rhgb quiet"' >"$ARGS"

# sudo runs the command: every path it can reach is inside the sandbox
stub sudo 'exec "$@"'
stub grub2-mkconfig 'echo MKCONFIG >>"$LOG"; echo "set theme=(\$root)/grub2/themes/catppuccin-mocha-grub/theme.txt" >"$2"'
stub grub2-editenv 'exit 0'
stub rpm 'exit 1'
stub dnf 'exit 0'
stub grubby '
case "$1" in
--info=ALL) cat "$ARGS" ;;
--update-kernel=ALL) echo GRUBBY >>"$LOG"; sed -i "s|\"\$| ${2#--args=}\"|" "$ARGS" ;;
esac'
PATH="$T/bin:$PATH"

# the GRUB block of install.sh and the kernel-title hook it installs, with
# every /etc/ and /boot/ path redirected
sed -n '/^echo "==> Installing the GRUB theme"/,/^fi$/p' "$ROOT/install.sh" |
    sed "s#/etc/#$SB/etc/#g; s#/boot/#$SB/boot/#g" >"$T/block.sh"
sed -i "s#/boot/#$SB/boot/#g" "$T/repo/grub/60-fdwm-title.install"
if cat "$T/block.sh" "$T/repo/grub/60-fdwm-title.install" |
    grep -E '(^|[^[:alnum:]_.-])/(etc|boot)/' | grep -vF "$SB"; then
    fail "an /etc or /boot path was not redirected; not running the block"
    finish
fi
{
    echo 'set -Eeuo pipefail'
    echo 'trap '\''echo "failed on line $LINENO: $BASH_COMMAND" >&2'\'' ERR'
    cat "$T/block.sh"
} >"$T/run.sh"

cfg=$SB/boot/grub2/grub.cfg
# step DESCRIPTION EXPECTED_MKCONFIG_RUNS
step() {
    : >"$LOG"
    out=$(cd "$T/repo" && bash "$T/run.sh" 2>&1)
    expect "$1: exits 0" 0 "$?"
    expect_no_match "$1: no ERR trap messages" "failed on line" "$out"
    expect "$1: grub2-mkconfig runs $2 time(s)" "$2" "$(grep -c MKCONFIG "$LOG")"
}
# make grub.cfg look older than anything written after this
age_cfg() { touch -d "@$(($(date +%s) - 120))" "$cfg"; }

step "first install" 1
expect "first install: kernel colors added" 1 "$(grep -c GRUBBY "$LOG")"
step "again, nothing changed" 0
step "and again" 0
expect "kernel colors not added twice" 0 "$(grep -c GRUBBY "$LOG")"
age_cfg
echo 'GRUB_TIMEOUT=3' >>"$SB/etc/default/grub"
step "after you edit /etc/default/grub" 1
step "again, nothing changed" 0
echo '# tweak' >>"$T/repo/grub/catppuccin-mocha-grub/theme.txt"
step "after the repo's theme changes" 1
rm "$cfg"
step "grub.cfg missing" 1

expect "theme settings appear exactly once" 2 "$(grep -cE '^GRUB_(THEME|TERMINAL_OUTPUT)=' "$SB/etc/default/grub")"
expect_match "kernel entry gets a short title" "^title Fedora 6\.16\.7$" "$(cat "$SB/boot/loader/entries/abc-6.16.7-200.fc44.x86_64.conf")"

finish
