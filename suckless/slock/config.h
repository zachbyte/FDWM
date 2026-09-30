/* user and group to drop privileges to (Fedora has no "nogroup") */
static const char *user  = "nobody";
static const char *group = "nobody";

/* Catppuccin Mocha, matching dwm and st */
static const char *colorname[NUMCOLS] = {
	[INIT] =   "#1e1e2e",   /* after initialization: dwm's background */
	[INPUT] =  "#b4befe",   /* during input: dwm's bar lavender */
	[FAILED] = "#f38ba8",   /* wrong password: red */
};

/* treat a cleared input like a wrong password (color) */
static const int failonclear = 1;
