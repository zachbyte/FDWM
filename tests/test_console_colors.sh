#!/usr/bin/env bash
# The tty palette: .bashrc loads it on a Linux console only, install.sh and
# the README give the kernel the same 16 colors, and install.sh adds them to
# each kernel entry once.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox

# .bashrc's palette block, run with a given TERM; prints the \e]P entries
palette_block=$(sed -n '/if \[ "\$TERM" = linux \]; then/,/^fi$/p' "$ROOT/dotfiles/.bashrc" | grep -v '^ *clear')
entries() { TERM=$1 bash -c "$palette_block" | grep -ao $'\e\\]P[0-9A-F][0-9a-f]\\{6\\}' | tr -d '\033]'; }

linux=$(entries linux)
expect "on a Linux console: 16 palette entries" 16 "$(wc -l <<<"$linux" | tr -d ' ')"
expect "on a Linux console: background is dwm's #1e1e2e" P01e1e2e "$(sed -n 1p <<<"$linux")"
expect "on a Linux console: text is st's #cdd6f4" P7cdd6f4 "$(sed -n 8p <<<"$linux")"
expect "in st: prints nothing" 0 "$(TERM=st-256color bash -c "$palette_block" | wc -c | tr -d ' ')"

# the kernel's vt.default_red/grn/blu must be the same colors, in decimal
for i in 0 1 2; do
    name=$(cut -d' ' -f$((i + 1)) <<<"red grn blu")
    want="vt.default_$name=$(while read -r e; do printf '%d,' "0x${e:2+2*i:2}"; done <<<"$linux" | sed 's/,$//')"
    expect "install.sh's vt.default_$name matches .bashrc" "$want" "$(grep -o "vt.default_$name=[0-9,]*" "$ROOT/install.sh")"
    expect "README's vt.default_$name matches .bashrc" "$want" "$(grep -o "vt.default_$name=[0-9,]*" "$ROOT/README.md")"
done

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
run() { : >"$LOG"; (set -Eeuo pipefail; eval "$block") >/dev/null; }

run
expect "two kernels without colors: one grubby update" 1 "$(wc -l <"$LOG" | tr -d ' ')"
run
expect "colors present: no update" 0 "$(wc -l <"$LOG" | tr -d ' ')"
echo 'args="ro rhgb quiet"' >>"$ARGS"
run
expect "a new kernel without colors: updated again" 1 "$(wc -l <"$LOG" | tr -d ' ')"
expect "every kernel entry has all three" 3 "$(grep -c 'vt.default_red=.*vt.default_grn=.*vt.default_blu=' "$ARGS")"

finish
