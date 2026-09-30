#!/usr/bin/env bash
# dwm's swapclients() (tiledmove) compiled straight out of dwm.c and run on
# every pair of windows in lists of 2 to 5, neighbours and ends included.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox

cc=${CC:-cc}
if ! command -v "$cc" >/dev/null; then
    echo "  skip  no C compiler"
    exit 0
fi

# the function as it is in dwm.c, return type included
awk '/^swapclients\(Client \*a, Client \*b\)$/ { print prev; p = 1 }
     p { print } p && /^}$/ { exit } { prev = $0 }' "$ROOT/suckless/dwm/dwm.c" >"$T/swapclients.c"
expect "swapclients() found in dwm.c" yes "$([[ -s $T/swapclients.c ]] && echo yes)"

cat >"$T/test.c" <<'EOF'
#include <stdio.h>
#include <string.h>

/* just the fields swapclients() uses */
typedef struct Monitor Monitor;
typedef struct Client Client;
struct Client { Client *next; Monitor *mon; char name; };
struct Monitor { Client *clients; };

#include "swapclients.c"

int
main(void)
{
	Monitor m;
	Client c[5], *p;
	char want[6], got[8];
	int n, i, j, k, cases = 0, failures = 0;

	for (n = 2; n <= 5; n++)
		for (i = 0; i < n; i++)
			for (j = 0; j < n; j++) {
				if (i == j)
					continue;
				for (k = 0; k < n; k++) {
					c[k].name = 'a' + k;
					c[k].mon = &m;
					c[k].next = k + 1 < n ? &c[k + 1] : NULL;
					want[k] = 'a' + k;
				}
				want[n] = '\0';
				want[i] = 'a' + j;
				want[j] = 'a' + i;
				m.clients = &c[0];
				swapclients(&c[i], &c[j]);
				for (k = 0, p = m.clients; p && k < 6; p = p->next)
					got[k++] = p->name;
				got[k] = '\0';
				if (p)
					strcpy(got, "cycle");
				cases++;
				if (strcmp(want, got)) {
					printf("swap(%c,%c) in %d: want %s, got %s\n", 'a' + i, 'a' + j, n, want, got);
					failures++;
				}
			}
	printf("%d cases, %d failures\n", cases, failures);
	return failures != 0;
}
EOF
if "$cc" -std=c99 -Wall -Werror -o "$T/test" "$T/test.c" 2>"$T/cc.err"; then
    out=$("$T/test")
    expect "every swap leaves the right order" "40 cases, 0 failures" "$(tail -1 <<<"$out")"
else
    fail "harness does not compile: $(cat "$T/cc.err")"
fi

finish
