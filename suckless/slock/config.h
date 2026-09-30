/* user and group to drop privileges to (Fedora has no "nogroup") */
static const char *user  = "nobody";
static const char *group = "nobody";

/* Catppuccin Mocha, matching dwm and st */
static const char *colorname[NUMCOLS] = {
	[INIT] =   "#1e1e2e",   /* after initialization: base, dwm's background */
	[INPUT] =  "#45475a",   /* during input: surface1, a step lighter */
	[FAILED] = "#f38ba8",   /* wrong password: red */
};

/* treat a cleared input like a wrong password (color); off, so pressing
 * Shift or erasing what you typed goes back to the locked color, and only
 * a real wrong password turns red */
static const int failonclear = 0;
