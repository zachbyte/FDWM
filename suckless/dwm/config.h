/* See LICENSE file for copyright and license details. */

/* appearance */
static const unsigned int borderpx  = 2;        /* border pixel of windows */
static const unsigned int gappx     = 10;        /* gaps between windows */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
static const int swallowfloating    = 0;        /* 1 means a floating window swallows its terminal too */
static const char *fonts[]          = { "JetBrainsMono Nerd Font:size=10" };
#include "../colors.h" /* COL_*: the palette's colors, written by fdwm-theme */
static const char col_bg[] = COL_BASE;
static const char col_fg[] = COL_UI_TEXT;
static const char col_accent[] = COL_UI_ACCENT;
static const char col_border[] = COL_UI_BORDER;
static const char *colors[][3] = {
	/*               fg          bg      border   */
	[SchemeNorm] = { col_fg,     col_bg, col_border }, /* the whole bar, the other windows' borders */
	[SchemeSel]  = { col_accent, col_bg, col_accent }, /* the focused window's border, the selected tag's underline */
};

/* scratchpads: a floating window a key shows and hides again, started the
 * first time it's wanted. Each has its own tag, SPTAG(n), which a rule
 * below gives the window by the instance name st -n sets. */
typedef struct {
	const char *name;
	const void *cmd;
} Sp;
static const float spfact = 0.6; /* their size: this share of the screen, across and down */
static const char *sptermcmd[] = { "st", "-n", "spterm", NULL };
static const char *spnotescmd[] = { "/bin/sh", "-c",
	"exec st -n spnotes -e nvim \"$HOME/notes.md\"", NULL };
static Sp scratchpads[] = {
	/* name          cmd  */
	{ "spterm",      sptermcmd },   /* Alt+`: a terminal */
	{ "spnotes",     spnotescmd },  /* Alt+N: Neovim on ~/notes.md */
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9"};

static const Rule rules[] = {
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* a window started from a terminal (isterminal) takes its place until
	 * it closes, unless it floats or has noswallow. The later rules unset
	 * isterminal for the scratchpads' and fdwm-theme-menu's st. */
	/* class         instance      title           tags mask  isfloating  isterminal  noswallow  monitor */
	{ "st-256color", NULL,         NULL,           0,         0,          1,          0,         -1 }, /* st */
	{ NULL,          "spterm",     NULL,           SPTAG(0),  1,          0,          0,         -1 },
	{ NULL,          "spnotes",    NULL,           SPTAG(1),  1,          0,          0,         -1 },
	{ NULL,          "fdwm-theme", NULL,           0,         1,          0,          0,         -1 }, /* fdwm-theme-menu's st */
	{ NULL,          NULL,         "Event Tester", 0,         0,          0,          1,         -1 }, /* xev */
 };

/* layout(s) */
static const float mfact     = 0.55; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 1;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */

static const Layout layouts[] = {
    /* symbol     arrange function */
    { "",      tile },
    { "",      NULL },    /* no layout function means floating behavior */
    { "",      monocle },
};

/* key definitions. Each key and button ends with a comment of its own,
 * "group: what it does" between comment marks, which install.sh lists in
 * ~/.config/fdwm/keys for fdwm-keys (Alt+/); the groups are windows, tags,
 * layouts, apps and system. */
#define MODKEY Mod1Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, /* tags: view the tag */ \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, /* tags: view the tag too */ \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, /* tags: put the focused window on the tag */ \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} }, /* tags: put the focused window on the tag too */

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* after a volume, mute or brightness key, redraw the bar at once (fdwm-bar) */
#define BARREFRESH "; \"$HOME/.local/bin/fdwm-bar\" refresh"

/* screenshots (fdwm-shot): a region, or the whole screen */
#define SHOT(what) SHCMD ("\"$HOME/.local/bin/fdwm-shot\" " what)

/* commands */
static const char *dmenucmd[] = { "dmenu_run", NULL };
static const char *termcmd[] = { "st", NULL };
static const char *lockcmd[] = { "slock", NULL };
/* lock, suspend, restart dwm, log out, reboot, power off (fdwm-menu) */
static const char *menucmd[] = { "/bin/sh", "-c", "exec \"$HOME/.local/bin/fdwm-menu\"", NULL };
/* pick the flavor in dmenu, switched in a floating st (fdwm-theme-menu) */
static const char *themecmd[] = { "/bin/sh", "-c", "exec \"$HOME/.local/bin/fdwm-theme-menu\"", NULL };
/* every key and mouse button here, described, in dmenu (fdwm-keys) */
static const char *keyscmd[] = { "/bin/sh", "-c", "exec \"$HOME/.local/bin/fdwm-keys\"", NULL };

static const Key keys[] = {
	/* modifier                     key        function        argument */
	{ MODKEY,                       XK_r,      spawn,          {.v = dmenucmd } }, /* apps: run a program (dmenu) */
	{ MODKEY,                       XK_x,      spawn,          {.v = termcmd } }, /* apps: open a terminal (st) */
	{ MODKEY,                       XK_b,      togglebar,      {0} }, /* windows: show or hide the bar */
	{ MODKEY,                       XK_j,      focusstack,     {.i = +1 } }, /* windows: focus the next window */
	{ MODKEY,                       XK_k,      focusstack,     {.i = -1 } }, /* windows: focus the previous window */
	{ MODKEY|ShiftMask,             XK_j,      movestack,      {.i = +1 } }, /* windows: move the focused window down the stack */
	{ MODKEY|ShiftMask,             XK_k,      movestack,      {.i = -1 } }, /* windows: move the focused window up the stack */
	{ MODKEY,                       XK_i,      incnmaster,     {.i = +1 } }, /* layouts: one more window in the master area */
	{ MODKEY,                       XK_d,      incnmaster,     {.i = -1 } }, /* layouts: one fewer window in the master area */
	{ MODKEY,                       XK_h,      setmfact,       {.f = -0.05} }, /* layouts: shrink the master area */
	{ MODKEY,                       XK_l,      setmfact,       {.f = +0.05} }, /* layouts: grow the master area */
	{ MODKEY,                       XK_Return, zoom,           {0} }, /* windows: move the focused window to the master area */
	{ MODKEY,                       XK_Tab,    view,           {0} }, /* tags: back to the tags viewed before */
	{ MODKEY,                       XK_q,      killclient,     {0} }, /* windows: close the focused window */
	{ MODKEY,                       XK_t,      setlayout,      {.v = &layouts[0]} }, /* layouts: tiled */
	{ MODKEY,                       XK_f,      setlayout,      {.v = &layouts[1]} }, /* layouts: floating */
	{ MODKEY,                       XK_m,      setlayout,      {.v = &layouts[2]} }, /* layouts: monocle */
	{ MODKEY,                       XK_space,  setlayout,      {0} }, /* layouts: back to the previous layout */
	{ MODKEY|ShiftMask,             XK_space,  togglefloating, {0} }, /* windows: float or tile the focused window */
	{ MODKEY|ShiftMask,             XK_f,      togglefullscr,  {0} }, /* windows: fullscreen on or off */
	{ MODKEY,                       XK_0,      view,           {.ui = ~SPTAGMASK } }, /* tags: view every tag */
	{ MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~SPTAGMASK } }, /* tags: put the focused window on every tag */
	TAGKEYS(                        XK_1,                      0)
	TAGKEYS(                        XK_2,                      1)
	TAGKEYS(                        XK_3,                      2)
	TAGKEYS(                        XK_4,                      3)
	TAGKEYS(                        XK_5,                      4)
	TAGKEYS(                        XK_6,                      5)
	TAGKEYS(                        XK_7,                      6)
	TAGKEYS(                        XK_8,                      7)
	TAGKEYS(                        XK_9,                      8)
	{ MODKEY|ShiftMask,             XK_q,      quit,           {0} }, /* system: quit dwm (log out) */
	{ MODKEY|ShiftMask,             XK_w,      quit,           {1} }, /* system: restart dwm, windows kept */
	{ MODKEY|ShiftMask,             XK_r,      resetmfact,     {0} }, /* layouts: reset the master area */
	{ MODKEY|ShiftMask,             XK_l,      spawn,          {.v = lockcmd } }, /* system: lock the screen */
	{ MODKEY|ShiftMask,             XK_e,      spawn,          {.v = menucmd } }, /* system: power menu */
	{ MODKEY|ShiftMask,             XK_t,      spawn,          {.v = themecmd } }, /* system: theme menu */
	{ MODKEY,                       XK_slash,  spawn,          {.v = keyscmd } }, /* system: these keys and buttons (fdwm-keys) */
	{ MODKEY,                       XK_grave,  togglescratch,  {.ui = 0 } }, /* apps: show or hide the terminal scratchpad */
	{ MODKEY,                       XK_n,      togglescratch,  {.ui = 1 } }, /* apps: show or hide the notes scratchpad */
	{ 0,                            XF86XK_MonBrightnessUp,    spawn,          SHCMD ("brightnessctl set +10%" BARREFRESH)}, /* system: brightness up */
	{ 0,                            XF86XK_MonBrightnessDown,  spawn,          SHCMD ("brightnessctl set 10%-" BARREFRESH)}, /* system: brightness down */
	{ 0,                            XF86XK_AudioLowerVolume,   spawn,          SHCMD ("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" BARREFRESH)}, /* system: volume down */
	{ 0,                            XF86XK_AudioMute,          spawn,          SHCMD ("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" BARREFRESH)}, /* system: mute on or off */
	{ 0,                            XF86XK_AudioRaiseVolume,   spawn,          SHCMD ("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+" BARREFRESH)}, /* system: volume up */
	{ 0,                            XF86XK_AudioPlay,          spawn,          SHCMD ("playerctl play-pause")}, /* apps: play or pause */
	{ 0,                            XF86XK_AudioNext,          spawn,          SHCMD ("playerctl next")}, /* apps: next track */
	{ 0,                            XF86XK_AudioPrev,          spawn,          SHCMD ("playerctl previous")}, /* apps: previous track */
	{ 0,                            XK_Print,                  spawn,          SHOT ("region")}, /* apps: screenshot of a region */
	{ ShiftMask,                    XK_Print,                  spawn,          SHOT ("screen")}, /* apps: screenshot of the whole screen */
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} }, /* windows: move the window to the master area */
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } }, /* apps: open a terminal (st) */
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} }, /* windows: move the window */
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} }, /* windows: float or tile the window */
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} }, /* windows: resize the window */
	{ ClkTagBar,            0,              Button1,        view,           {0} }, /* tags: view the tag */
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} }, /* tags: view the tag too */
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} }, /* tags: put the focused window on the tag */
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} }, /* tags: put the focused window on the tag too */
};
