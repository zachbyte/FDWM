/* xpixels X Y W H: the root window's pixels in that rectangle, one row per
 * line, each pixel as rrggbb, separated by spaces. tests/test_tag_marker.sh
 * compiles it to read the colors dwm draws its bar in. */
#include <stdio.h>
#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

int
main(int argc, char *argv[])
{
	Display *dpy;
	XImage *img;
	XColor c;
	int x, y, w, h, i, j;

	if (argc != 5) {
		fputs("usage: xpixels X Y W H\n", stderr);
		return 2;
	}
	x = atoi(argv[1]), y = atoi(argv[2]), w = atoi(argv[3]), h = atoi(argv[4]);
	if (!(dpy = XOpenDisplay(NULL))) {
		fputs("xpixels: cannot open display\n", stderr);
		return 1;
	}
	img = XGetImage(dpy, DefaultRootWindow(dpy), x, y, w, h, AllPlanes, ZPixmap);
	if (!img) {
		fputs("xpixels: XGetImage failed\n", stderr);
		return 1;
	}
	for (j = 0; j < h; j++) {
		for (i = 0; i < w; i++) {
			c.pixel = XGetPixel(img, i, j);
			XQueryColor(dpy, DefaultColormap(dpy, DefaultScreen(dpy)), &c);
			printf("%s%02x%02x%02x", i ? " " : "", c.red >> 8, c.green >> 8, c.blue >> 8);
		}
		putchar('\n');
	}
	XDestroyImage(img);
	XCloseDisplay(dpy);
	return 0;
}
