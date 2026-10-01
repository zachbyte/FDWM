/* xwin TITLE [fixed]: a plain window titled TITLE, for a window manager to
 * manage, until it's closed; fixed gives it a fixed size, which dwm floats.
 * tests/test_swallow.sh compiles it to start a graphical program from st. */
#include <stdio.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

int
main(int argc, char *argv[])
{
	Display *dpy;
	Window w;
	XSizeHints *hints;
	XEvent ev;
	Atom del;

	if (argc < 2 || argc > 3 || (argc == 3 && strcmp(argv[2], "fixed"))) {
		fputs("usage: xwin TITLE [fixed]\n", stderr);
		return 2;
	}
	if (!(dpy = XOpenDisplay(NULL))) {
		fputs("xwin: cannot open display\n", stderr);
		return 1;
	}
	w = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0, 300, 200, 0, 0, 0);
	XStoreName(dpy, w, argv[1]);
	if (argc == 3 && (hints = XAllocSizeHints())) {
		hints->flags = PMinSize | PMaxSize;
		hints->min_width = hints->max_width = 300;
		hints->min_height = hints->max_height = 200;
		XSetWMNormalHints(dpy, w, hints);
		XFree(hints);
	}
	del = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
	XSetWMProtocols(dpy, w, &del, 1);
	XMapWindow(dpy, w);
	for (;;) {
		XNextEvent(dpy, &ev);
		if (ev.type == ClientMessage && (Atom)ev.xclient.data.l[0] == del)
			break;
	}
	XCloseDisplay(dpy);
	return 0;
}
