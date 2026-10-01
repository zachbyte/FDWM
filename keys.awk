# keys.awk: dwm's keys and mouse buttons, from suckless/dwm/config.h, as the
# list fdwm-keys shows (Alt+/). install.sh writes it to ~/.config/fdwm/keys:
#
#   awk -f keys.awk suckless/dwm/config.h
#
# One line per binding, grouped (windows, tags, layouts, apps, system, in that
# order) and in config.h's order within a group:
#
#   windows   Alt+J                       focus the next window
#
# Every entry of keys[] and buttons[], and every line of the TAGKEYS macro,
# must end with its description, as a comment "/* group: what it does */".
# The TAGKEYS lines become one row each for all the tag keys (Alt+1-9). A
# line in those places that isn't a binding with a description, a key, a
# modifier, a button or a click place this doesn't know, stops it: it says
# which line of config.h, and exits 1, so install.sh fails there rather than
# the list going wrong.

function fail(why) {
	printf "%s:%d: %s: %s\n", FILENAME, FNR, why, $0 > "/dev/stderr"
	failed = 1
	exit 1
}

# mods(M): MODKEY|ShiftMask and the like as Alt+Shift+
function mods(m,    n, part, i, out) {
	if (m == "0")
		return ""
	n = split(m, part, "|")
	for (i = 1; i <= n; i++) {
		if (part[i] == "MODKEY") part[i] = modkey
		if (!(part[i] in modname)) fail("unknown modifier " part[i])
		out = out modname[part[i]] "+"
	}
	return out
}

# key(K): XK_x as X, XF86XK_AudioMute as Mute, and so on
function key(k) {
	if (k in keyname) return keyname[k]
	if (k ~ /^XK_[a-z]$/) return toupper(substr(k, 4))
	if (k ~ /^XK_[0-9]$/) return substr(k, 4)
	if (k ~ /^XK_[A-Za-z_]+$/) return substr(k, 4)
	if (k ~ /^XF86XK_[A-Za-z]+$/) return substr(k, 8)
	fail("unknown key " k)
}

# desc(): the trailing "/* group: what it does */"; sets group and what
function desc(    d) {
	if (!match($0, /\/\* [a-z]+: [^*]+ \*\/( \\)?$/)) fail("no \"/* group: what it does */\" at the end")
	d = substr($0, RSTART + 3, RLENGTH - 3)
	sub(/ \*\/( \\)?$/, "", d)
	group = d
	sub(/:.*/, "", group)
	what = substr(d, length(group) + 3)
	if (!(group in order)) fail("unknown group " group " (windows, tags, layouts, apps or system)")
}

# add(GROUP, KEYS, WHAT): a row of the list; KEYS is "" for a TAGKEYS line,
# whose keys are only known once every TAGKEYS has been read
function add(g, k, w) {
	n = ++count[g]
	rowkeys[g, n] = k
	rowwhat[g, n] = w
}

# fields(): the entry's comma-separated fields, before its "}," and comment,
# into f[1..]
function fields(    body) {
	body = $0
	sub(/^[ \t]*\{[ \t]*/, "", body)
	sub(/[ \t]*\}[ \t]*,[ \t]*\/\*.*$/, "", body)
	return split(body, f, /[ \t]*,[ \t]*/)
}

BEGIN {
	ngroups = split("windows tags layouts apps system", groups, " ")
	for (i = 1; i <= ngroups; i++) order[groups[i]] = i
	modname["Mod1Mask"] = "Alt"; modname["Mod4Mask"] = "Super"
	modname["ShiftMask"] = "Shift"; modname["ControlMask"] = "Ctrl"
	keyname["XK_Return"] = "Return"; keyname["XK_space"] = "Space"
	keyname["XK_Tab"] = "Tab"; keyname["XK_grave"] = "`"
	keyname["XK_slash"] = "/"; keyname["XK_Print"] = "Print"
	keyname["XF86XK_MonBrightnessUp"] = "Brightness Up"
	keyname["XF86XK_MonBrightnessDown"] = "Brightness Down"
	keyname["XF86XK_AudioRaiseVolume"] = "Volume Up"
	keyname["XF86XK_AudioLowerVolume"] = "Volume Down"
	keyname["XF86XK_AudioMute"] = "Mute"
	keyname["XF86XK_AudioPlay"] = "Play"
	keyname["XF86XK_AudioNext"] = "Next Track"
	keyname["XF86XK_AudioPrev"] = "Previous Track"
	button["Button1"] = "Left click"; button["Button2"] = "Middle click"
	button["Button3"] = "Right click"
	button["Button4"] = "Scroll up"; button["Button5"] = "Scroll down"
	place["ClkTagBar"] = "on a tag"; place["ClkLtSymbol"] = "on the layout"
	place["ClkStatusText"] = "on the status"; place["ClkWinTitle"] = "on the title"
	place["ClkClientWin"] = "on a window"; place["ClkRootWin"] = "on the desktop"
}

/^#define MODKEY / { modkey = $3; next }

# the TAGKEYS macro's lines, kept for its uses in keys[]
/^#define TAGKEYS\(/ { inmacro = 1; next }
inmacro {
	if ($0 !~ /^[ \t]*\{/) fail("not a key in TAGKEYS")
	desc()
	fields()
	if (f[2] != "KEY") fail("TAGKEYS's key isn't KEY")
	mods(f[1])  # (checked here, for this line's number)
	ntag++
	tagmods[ntag] = f[1]; taggroup[ntag] = group; tagwhat[ntag] = what
	if ($0 !~ /\\$/) inmacro = 0
	next
}

/^static const Key keys\[\] = \{/ { inkeys = 1; next }
/^static const Button buttons\[\] = \{/ { inbuttons = 1; next }
(inkeys || inbuttons) && /^\};/ { inkeys = inbuttons = 0; next }
(inkeys || inbuttons) && (/^[ \t]*$/ || /^[ \t]*\/\*.*\*\/[ \t]*$/) { next }

inkeys && /^[ \t]*TAGKEYS\(/ {
	if (!match($0, /XK_[0-9]/)) fail("TAGKEYS without a number key")
	tagkey = substr($0, RSTART + 3, 1)
	if (firsttag == "") firsttag = tagkey
	lasttag = tagkey
	if (!tagsat) {
		# the rows go where the first TAGKEYS is
		tagsat = 1
		if (!ntag) fail("TAGKEYS used, but its definition wasn't found above")
		for (i = 1; i <= ntag; i++) {
			add(taggroup[i], "", tagwhat[i])
			rowtag[taggroup[i], count[taggroup[i]]] = i
		}
	}
	next
}

inkeys {
	if ($0 !~ /^[ \t]*\{/) fail("not a key")
	desc()
	if (fields() < 4) fail("not a key")
	add(group, mods(f[1]) key(f[2]), what)
	next
}

inbuttons {
	if ($0 !~ /^[ \t]*\{/) fail("not a button")
	desc()
	if (fields() < 5) fail("not a button")
	if (!(f[1] in place)) fail("unknown click place " f[1])
	if (!(f[3] in button)) fail("unknown button " f[3])
	add(group, mods(f[2]) button[f[3]] " " place[f[1]], what)
	next
}

END {
	if (failed) exit 1
	if (!count["system"] && !count["windows"]) {
		printf "%s: no keys[] found\n", FILENAME > "/dev/stderr"
		exit 1
	}
	for (g = 1; g <= ngroups; g++) {
		name = groups[g]
		for (i = 1; i <= count[name]; i++) {
			k = rowkeys[name, i]
			if ((name, i) in rowtag)
				k = mods(tagmods[rowtag[name, i]]) firsttag "-" lasttag
			printf "%-9s %-31s %s\n", name, k, rowwhat[name, i]
		}
	}
}
