#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies and sed scripts expand later, not here
# install.sh's GRUB step with /etc and /boot moved into a sandbox: when it
# regenerates grub.cfg, that it leaves /etc/default/grub tidy, and that it
# moves an earlier install from the theme's old folder to themes/fdwm. Then
# what install.sh --colors does there (grub_colors): the theme and the
# console's colors only where they changed, sudo only then, and never
# grub2-mkconfig.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
SB=$T/sb
export LOG="$T/log" ARGS="$T/kernel-args"
mkdir -p "$SB/etc/default" "$SB/etc/kernel/install.d" \
    "$SB/boot/grub2/themes" "$SB/boot/loader/entries"
# the repo's grub/ and fdwm-theme, with the theme's colors generated as
# install.sh does before this step
theme_repo "$T/repo"
# a second flavor, other, for --colors to switch to (the real palette has
# thinkpad alone)
other_flavor "$T/repo"
HOME=$T/home bash "$T/repo/fdwm-theme" generate >/dev/null
# installed by an earlier version, in the theme's old folder
old_theme=$SB/boot/grub2/themes/catppuccin-mocha-grub
mkdir -p "$old_theme"
echo 'desktop-color: "black"' >"$old_theme/theme.txt"
printf 'GRUB_TIMEOUT=5\nGRUB_ENABLE_BLSCFG=true\nGRUB_TERMINAL_OUTPUT="gfxterm"\nGRUB_THEME="%s"\n' \
    "$old_theme/theme.txt" >"$SB/etc/default/grub"
echo "set theme=$old_theme/theme.txt" >"$SB/boot/grub2/grub.cfg"
printf 'title Fedora Linux (6.16.7-200.fc44.x86_64)\nversion 6.16.7-200.fc44.x86_64\n' \
    >"$SB/boot/loader/entries/abc-6.16.7-200.fc44.x86_64.conf"
echo 'args="ro rhgb quiet"' >"$ARGS"

# sudo runs the command: every path it can reach is inside the sandbox
stub sudo 'echo SUDO >>"$LOG"; exec "$@"'
stub grub2-mkconfig 'echo MKCONFIG >>"$LOG"; echo "set theme=(\$root)/grub2/themes/fdwm/theme.txt" >"$2"'
stub grub2-editenv 'exit 0'
stub rpm 'exit 1'
stub dnf 'exit 0'
stub grubby '
case "$1" in
--info=ALL) cat "$ARGS" ;;
--update-kernel=ALL) echo GRUBBY >>"$LOG"; sed -i "s|\"\$| ${2#--args=}\"|" "$ARGS" ;;
esac'
PATH="$T/bin:$PATH"

# the GRUB block of install.sh, the functions it shares with --colors, and
# the kernel-title hook it installs, with every /etc/ and /boot/ path
# redirected
sed -n '/^grub_theme=/p; /^theme_sum() {/p; /^copy_grub_theme() {/,/^}/p; /^console_colors() {/,/^}/p; /^grub_colors() {/,/^}/p' "$ROOT/install.sh" |
    sed "s#/etc/#$SB/etc/#g; s#/boot/#$SB/boot/#g" >"$T/funcs.sh"
sed -n '/^echo "==> Installing the GRUB theme"/,/^fi$/p' "$ROOT/install.sh" |
    sed "s#/etc/#$SB/etc/#g; s#/boot/#$SB/boot/#g" >"$T/block.sh"
expect "found install.sh's GRUB functions" 5 "$(grep -cE '^(grub_theme=|theme_sum\(\)|copy_grub_theme\(\)|console_colors\(\)|grub_colors\(\))' "$T/funcs.sh")"
sed -i "s#/boot/#$SB/boot/#g" "$T/repo/grub/60-fdwm-title.install"
if cat "$T/funcs.sh" "$T/block.sh" "$T/repo/grub/60-fdwm-title.install" |
    grep -E '(^|[^[:alnum:]_.-])/(etc|boot)/' | grep -vF "$SB"; then
    fail "an /etc or /boot path was not redirected; not running the block"
    finish
fi
# what install.sh writes down, for --colors to compare with
export state=$T/state
header() {
    echo 'set -Eeuo pipefail'
    echo 'trap '\''echo "failed on line $LINENO: $BASH_COMMAND" >&2'\'' ERR'
    cat "$T/funcs.sh"
}
{ header; cat "$T/block.sh"; } >"$T/run.sh"
{ header; echo grub_colors; } >"$T/colors.sh"

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

theme=$SB/boot/grub2/themes/fdwm
step "first install" 1
expect "first install: kernel colors added" 1 "$(grep -c GRUBBY "$LOG")"
expect "first install: the theme is an exact copy of grub/theme" "" "$(diff -r "$T/repo/grub/theme" "$theme")"
expect_match "first install: GRUB_THEME names the new folder" "^GRUB_THEME=\"$theme/theme.txt\"$" "$(cat "$SB/etc/default/grub")"
expect "first install: the old theme folder is gone" no "$([[ -e $old_theme ]] && echo yes || echo no)"
expect_match "first install: says so" "Removed the old theme folder" "$out"
step "again, nothing changed" 0
touch "$theme/stale.png"
step "a file the repo no longer has" 1
expect "it is removed from /boot" no "$([[ -e $theme/stale.png ]] && echo yes || echo no)"
expect "and no copy is left beside the theme" no "$([[ -e $theme.new ]] && echo yes || echo no)"
step "and again" 0
expect "kernel colors not added twice" 0 "$(grep -c GRUBBY "$LOG")"
age_cfg
echo 'GRUB_TIMEOUT=3' >>"$SB/etc/default/grub"
step "after you edit /etc/default/grub" 1
step "again, nothing changed" 0
echo '# tweak' >>"$T/repo/grub/theme/theme.txt"
step "after the repo's theme changes" 1
rm "$cfg"
step "grub.cfg missing" 1

expect "theme settings appear exactly once" 2 "$(grep -cE '^GRUB_(THEME|TERMINAL_OUTPUT)=' "$SB/etc/default/grub")"
expect_match "kernel entry gets a short title" "^title Fedora 6\.16\.7$" "$(cat "$SB/boot/loader/entries/abc-6.16.7-200.fc44.x86_64.conf")"
expect "the full step writes down the theme it installed" "$(cd "$T/repo/grub" && find theme -type f -exec cksum {} + | sort)" "$(cat "$state/grub-theme")"
expect "and the console colors" "$(cd "$T/repo" && bash ./fdwm-theme kernel-args)" "$(cat "$state/kernel-args")"

# --colors: colors_step DESCRIPTION, with HOME (the flavor) at $T/home
colors_step() {
    : >"$LOG"
    out=$(cd "$T/repo" && HOME=$T/home bash "$T/colors.sh" 2>&1)
    expect "$1: exits 0" 0 "$?"
    expect_no_match "$1: no ERR trap messages" "failed on line" "$out"
    expect "$1: grub2-mkconfig doesn't run" 0 "$(grep -c MKCONFIG "$LOG")"
}
colors_step "--colors, nothing changed"
expect "--colors, nothing changed: no sudo at all" 0 "$(grep -c SUDO "$LOG")"
expect "--colors, nothing changed: says so, twice" 2 "$(grep -c '^Unchanged$' <<<"$out")"
echo '# another tweak' >>"$T/repo/grub/theme/theme.txt"
colors_step "--colors, the theme changed"
expect "--colors, the theme changed: copied to /boot" "" "$(diff -r "$T/repo/grub/theme" "$theme")"
expect "--colors, the theme changed: console colors left alone" 0 "$(grep -c GRUBBY "$LOG")"
colors_step "--colors, then nothing changed"
expect "--colors, then nothing changed: no sudo" 0 "$(grep -c SUDO "$LOG")"
mkdir -p "$T/home/.config/fdwm"
echo other >"$T/home/.config/fdwm/flavor"
HOME=$T/home bash "$T/repo/fdwm-theme" generate >/dev/null
colors_step "--colors, another flavor"
expect "--colors, another flavor: its theme in /boot" "" "$(diff -r "$T/repo/grub/theme" "$theme")"
expect "--colors, another flavor: its console colors on every kernel" 1 "$(grep -c GRUBBY "$LOG")"
expect "--colors, another flavor: and written down" "$(cd "$T/repo" && HOME=$T/home bash ./fdwm-theme kernel-args)" "$(cat "$state/kernel-args")"

finish
