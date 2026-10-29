# Visual tests

Screenshots of a **sandboxed** Zen: a copy of a profile, on a headless display, so it
never touches the browser you are using.

1. Headless display: KWin's virtual backend hosting a rootful Xwayland on `:97`.

   ```sh
   kwin_wayland --virtual --socket wayland-m3e --width 1440 --height 900 &
   WAYLAND_DISPLAY=wayland-m3e Xwayland :97 -geometry 1400x860 &
   ```

2. Sandbox profile: copy `chrome/` and `prefs.js` from your profile into a scratch
   directory, symlink this repo to `chrome/sine-mods/m3-expressive`, add it to
   `mods.json`, and in `user.js` set `marionette.port` to `2829` and
   `sine.allow-unsafe-js` to `true`.

3. Run Zen on that display in X11 mode (so popups are composited into the root window):

   ```sh
   DISPLAY=:97 GDK_BACKEND=x11 MOZ_ENABLE_WAYLAND=0 zen --marionette \
     -remote-allow-system-access --no-remote -profile /path/to/sandbox &
   ```

4. Scenes:

   ```sh
   python3 tests/shots.py OUT_DIR setup sidebar urlbar urlbar-typing context appmenu light
   ```

`marionette.py` is a dependency-free Marionette client (chrome context). Fluent strings
don't resolve in the sandbox, so `shots.py` labels menu items from their ids. Without a
compositor on `:97`, popups show a black frame instead of transparent corners and some
repaints lag a frame; neither happens on a real desktop.
