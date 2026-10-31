# Compatibility

M3 Expressive was built alongside the **ii** Quickshell shell on **Hyprland** (Fedora),
but almost all of it is plain Zen + Sine CSS. This page says what is generic, what is
tied to that setup, and what was actually tested.

**Tested on:** Zen 1.22.x (native tarball build) with Sine, Fedora, Hyprland 0.56,
matugen 4.1, Google Sans Flex (variable). Nothing else has been run.

## Requirements (everyone)

| Need | Why | Without it |
|---|---|---|
| Zen Browser + **Sine** | loads the mod, its preferences and its script | nothing works |
| A recent Zen (1.22-era markup) | selectors target Zen's DOM, which changes between releases | parts can break after a Zen update |
| **matugen** (tested 4.1) | writes `colors.css` from your wallpaper | a built-in amber palette is used |
| **Google Sans Flex**, variable | the expressive width/weight axes | fetched by the installer; with `--no-font-download` or offline: system font, plain weights |
| `sine.allow-unsafe-js = true` (local installs) | runs `m3e.uc.js` | see "Without the script" below |

Google Sans Flex (SIL OFL 1.1): `install.sh` uses your installed variable copy or, if
there is none, downloads the official one from google/fonts (pinned, checksum-verified)
into `~/.local/share/fonts`, then copies it into the mod (`fonts/`):
Gecko ignores `font-variation-settings` in the browser UI for a font that only comes from
fontconfig, so it must be loaded through the mod's `@font-face`.

## Works the same for any Linux user

Everything visual in the browser:

- tokens, type, shapes and motion; light/dark (system or forced)
- sidebar layout: grouped tab rows, PINNED / TABS, folders as rows with preview and
  count, essentials, collapsed sidebar, new-tab chip, spaces switcher
- search overlay, menus and app menu (with Zen icons), site panel, library, media
  player (album art from the Media Session), tooltips, find bar, toasts, no shadows
- the SuperPins-derived options

These depend only on Zen + Sine, not on the desktop.

## Colours: matugen outside ii

The template (`matugen/zen-m3e.css`) is ordinary matugen; it does not read anything from
ii. What differs is *who runs matugen*:

- **ii** runs matugen on every wallpaper change, so `colors.css` follows the wallpaper
  and its light/dark mode by itself.
- **Anyone else** runs it themselves, e.g. `matugen image ~/wall.jpg -m dark`, or from
  their wallpaper tool. `install.sh` adds the template to `~/.config/matugen/config.toml`
  (creating the file if needed), so any later run updates the browser too.
- **First palette:** matugen keeps no state, so the installer looks for a source:
  `--source IMAGE|#hex`, else ii's colour (`~/.local/state/quickshell/user/generated/color.txt`),
  else the current wallpaper from swww/awww, hyprpaper, waypaper, KDE Plasma or GNOME
  (GNOME's setting can be stale when another tool draws the wallpaper — the installer
  prints its source so you can rerun with `--source`). Nothing found: `colors.css`
  appears the next time matugen runs.
- **Light/dark — "Follow the shell"** means "the mode matugen was last run with" (`-m`).
  If your desktop switches light/dark without re-running matugen, use **"Follow the
  system"** instead (prefers-color-scheme).
- The installer guesses the first palette's mode from GNOME's `color-scheme` setting
  (also set by many other desktops via the portal); defaults to dark.

## Glass (translucent window)

The browser side is generic: `zen.widget.linux.transparency` gives the window alpha, the
mod paints one translucent layer and keeps pages opaque. **Whether you see blur is up to
your compositor**, which must blur behind translucent windows on its own:

| Compositor | Result | Notes |
|---|---|---|
| Hyprland | ✅ tested | `decoration:blur:enabled`; popups need `blur:popups` |
| SwayFX, Wayfire (blur plugin), picom (X11) | likely ✅ | they blur behind translucent windows; untested |
| KDE Plasma (KWin) | translucent, **no blur** | KWin only blurs windows that ask for it; Firefox doesn't. A "force blur" KWin script can help. Untested |
| GNOME (Mutter) | translucent, **no blur** | Mutter doesn't blur app windows. Prefer glass off |
| sway, niri, others without blur | translucent, no blur | prefer glass off |

Without blur the desktop shows through sharp; keep glass off (or use the *strong* tint).

Always true, any compositor: Gecko's `backdrop-filter` can't blur web content, so things
that float over the page (search overlay, compact sidebar, find bar) stay nearly opaque.

Zen Internet works the same everywhere once transparent pages are allowed.

## Made for the ii setup (optional elsewhere)

| Piece | ii / Hyprland tie | Elsewhere |
|---|---|---|
| First palette from `color.txt` | reads ii's generated source colour | the detected wallpaper, or `--source` |
| Palette updates on wallpaper change | ii runs matugen | run matugen yourself / from your wallpaper tool |
| `--ii-page-radius` | honours the author's own "ii Dynamic Page Radius" mod if present | ignored; page radius = 23 px |
| Glass defaults, popup-blur advice | written against Hyprland | see the table above |
| Design tokens | mirror ii's `Appearance` (radii, curves) | no dependency — values are in `02-tokens.css` |
| `docs/design.md` | refers to ii's design guide | informational only |
| Font fallback path | Fedora's Google Sans Flex location | the copy in `fonts/` is used first |

## Installer notes

- Finds profiles by reading `profiles.ini` / `installs.ini` (relative and absolute
  paths) in `~/.zen` (native tarball, AUR), `~/.config/zen`, the Flatpak's
  `~/.var/app/app.zen_browser.zen/zen` (and the older `.zen` / `config/zen`), and the
  Snap's `~/snap/zen-browser/common/.zen`. It keeps only profiles with Sine
  (`chrome/JS/sine.sys.mjs`), picks the most recently used, and asks when several have
  Sine. Anything else: `--profile DIR` (*about:support → Profile Folder*).
- Needs `bash`, `python3`, `fc-list` (fontconfig), `curl` (only to fetch the font) and
  `matugen` (or `--no-matugen`).
- `--glass` and installing must happen with Zen closed (Zen rewrites `prefs.js` and Sine
  rewrites `mods.json`).
- `--copy` copies the mod (including the matugen template) so the repo can be deleted;
  the default symlink makes `git pull` + restart an update.

## Without the script (`m3e.uc.js`)

Sine runs scripts of locally installed mods only with `sine.allow-unsafe-js`. Without it
everything above still works except:

- live palette reload — the palette updates on restart instead
- closed-folder favicon preview and count
- album art in the media player
- scroll-edge fades that react to the scroll position (a fixed small fade remains), and
  hiding the sidebar scrollbar
- menu content spring on open
