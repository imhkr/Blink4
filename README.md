# Blink4

A small always-on-top eye that blinks every 4 seconds to remind you to blink.

Spontaneous blink rate at rest is 15-20 per minute, about one blink every 3-4
seconds. Screen work drops it to 5-7 per minute, which is what dries the eye out.

The pop rests at 16% opacity so it disappears while you work, and rises only for
the blink itself. Drag it anywhere, hover to reveal it, double-click to pause,
right-click for the interval (4/5/10/20/60s) or to quit.

## Build

    ./build.sh

Produces a universal (arm64 + x86_64) Blink4.app next to the script. macOS 12+.
