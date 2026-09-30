#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies and sed scripts expand later, not here
# shellcheck disable=SC2154  # fdwm_* come from the generated colors.sh
# The tty palette: .bashrc loads the palette's 16 console colors (from
# fdwm-theme's colors.sh) on a Linux console only, the kernel gets the same
# 16 from fdwm-theme kernel-args, and install.sh adds them to each kernel
# entry once.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
stub clear 'exit 0'
theme_repo "$T/repo"
HOME=$T/home bash "$T/repo/fdwm-theme" generate >/dev/null
# shellcheck source=/dev/null
. "$T/home/.config/fdwm/colors.sh"

# entries HOME TERM: the \e]P<n><rrggbb> entries an interactive .bashrc prints
entries() {
    env -i HOME="$1" TERM="$2" PATH="$T/bin:/usr/bin:/bin" \
        bash --rcfile "$ROOT/dotfiles/.bashrc" -i -c true </dev/null 2>/dev/null |
        grep -ao $'\e\\]P[0-9A-F][0-9a-f]\\{6\\}' | tr -d '\033]'
}

linux=$(entries "$T/home" linux)
expect "on a Linux console: 16 palette entries" 16 "$(wc -l <<<"$linux" | tr -d ' ')"
expect "on a Linux console: 0 is the terminal background" "P0${fdwm_term_bg#\#}" "$(sed -n 1p <<<"$linux")"
expect "on a Linux console: 7 is the terminal text" "P7${fdwm_term_fg#\#}" "$(sed -n 8p <<<"$linux")"
want=$(for i in 1 2 3 4 5 6 8 9 10 11 12 13 14 15; do
    v=fdwm_term$i
    printf 'P%X%s\n' "$i" "${!v#\#}"
done)
expect "on a Linux console: the rest are the terminal's colors" "$want" "$(sed '1d; 8d' <<<"$linux")"
expect "in st: prints nothing" "" "$(entries "$T/home" st-256color)"
mkdir "$T/fresh"
expect "no colors.sh yet: prints nothing" "" "$(entries "$T/fresh" linux)"

# the kernel's vt.default_red/grn/blu: the same colors, in decimal
args=$(bash "$ROOT/fdwm-theme" kernel-args)
for i in 0 1 2; do
    name=$(cut -d' ' -f$((i + 1)) <<<"red grn blu")
    want="vt.default_$name=$(while read -r e; do printf '%d,' "0x${e:2+2*i:2}"; done <<<"$linux" | sed 's/,$//')"
    expect "fdwm-theme kernel-args: vt.default_$name matches .bashrc" "$want" "$(grep -o "vt.default_$name=[0-9,]*" <<<"$args")"
done
expect "the README's grubby step takes them from fdwm-theme" 1 \
    "$(grep -cF 'sudo grubby --update-kernel=ALL --args="$(./fdwm-theme kernel-args)"' "$ROOT/README.md")"

# install.sh's grubby step against a fake grubby keeping kernel args in a file
export ARGS="$T/args" LOG="$T/log"
printf 'args="ro rhgb quiet"\nargs="ro rhgb quiet"\n' >"$ARGS"
stub sudo 'exec "$@"'
stub grubby '
case "$1" in
--info=ALL) cat "$ARGS" ;;
--update-kernel=ALL) echo UPDATE >>"$LOG"; sed -i "s|\"\$| ${2#--args=}\"|" "$ARGS" ;;
esac'
PATH="$T/bin:$PATH"
block=$(sed -n '/Catppuccin on the ttys from the moment/,/^    fi$/p' "$ROOT/install.sh")
run() { : >"$LOG"; (cd "$ROOT" && set -Eeuo pipefail && eval "$block") >/dev/null; }

run
expect "two kernels without colors: one grubby update" 1 "$(wc -l <"$LOG" | tr -d ' ')"
run
expect "colors present: no update" 0 "$(wc -l <"$LOG" | tr -d ' ')"
echo 'args="ro rhgb quiet"' >>"$ARGS"
run
expect "a new kernel without colors: updated again" 1 "$(wc -l <"$LOG" | tr -d ' ')"
expect "every kernel entry has all three" 3 "$(grep -c 'vt.default_red=.*vt.default_grn=.*vt.default_blu=' "$ARGS")"
expect "and fdwm-theme's values" 3 "$(grep -cF "$args" "$ARGS")"

finish
