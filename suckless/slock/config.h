/* user and group to drop privileges to (Fedora has no "nogroup") */
static const char *user  = "nobody";
static const char *group = "nobody";

/* Catppuccin, matching dwm and st */
#include "../colors.h" /* COL_*: the palette's colors, written by fdwm-theme */
static const char *colorname[NUMCOLS] = {
	[INIT] =   COL_BASE,     /* after initialization: dwm's background */
	[INPUT] =  COL_SURFACE1, /* during input: a step lighter */
	[FAILED] = COL_RED,      /* wrong password */
};

/* treat a cleared input like a wrong password (color); off, so pressing
 * Shift or erasing what you typed goes back to the locked color, and only
 * a real wrong password turns red */
static const int failonclear = 0;
