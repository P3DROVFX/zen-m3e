# M3 Expressive for Zen

A [Sine](https://github.com/CosmoCreeper/Sine) mod that brings Material 3 Expressive to
[Zen Browser](https://zen-browser.app): the colours come from **matugen** (light and dark),
the type is **Google Sans Flex** with its variable axes, shapes morph instead of spinning,
and motion uses the M3E spring curves.

It is the browser half of the ii shell's design language: same tokens, same surface
ladder, same curves (`Appearance.animationCurves`), same rules (`docs/design.md`).

| Dark | Light |
|---|---|
| ![search overlay, dark](docs/screenshots/urlbar-dark.png) | ![search overlay, light](docs/screenshots/urlbar-light.png) |
| ![sidebar and menu](docs/screenshots/context-dark.png) | ![sidebar, light](docs/screenshots/sidebar-light.png) |

## What it themes

- **Sidebar** — tabs as one grouped shape per section (joins 5 px, outer corners 23 px);
  the current tab becomes a primary pill and its neighbours round towards it. Essentials
  are pills at rest and rounded squares when current. The space header uses the wide
  display face (`wdth 128`, `wght 760`) with its icon in a cookie that morphs 9 → 12 sides
  on hover. "New tab" is the dashed unselected chip; "create" is a small FAB.
- **Search overlay** (floating URL bar) — a sheet with a Clover-4 badge that morphs into
  Sunny while you type, the query in a filled pill, the first result as a **top result**
  hero card (primary container, caption, big title, an "Open ↵" pill that springs in, a
  clipped scallop ornament), group headings in the wide face, favicon tiles, pill
  selection, engine chips. The overlay springs in; the first reveal staggers its rows.
- **Menus** — one rounded container, items morph to a pill when active, separators are
  gaps, open submenus stay lit in the tertiary voice, content springs from the anchor.
- **Panels** — app menu, extensions, site info: same item morph, title-face headers,
  connected zoom button group, dashed secondary / filled primary buttons.
- **Also** — tooltips (inverse surface), find bar, toasts as snackbars, notifications,
  glance and split view, scrollbars, focus rings.

## Install

Requirements: Zen with Sine, `matugen` ≥ 4, the Google Sans Flex variable font.

```sh
git clone https://github.com/P3DROVFX/zen-m3e ~/Projects/zen-m3e
cd ~/Projects/zen-m3e
# close Zen first
./install.sh            # symlinks the repo into the default profile, hooks matugen
```

`install.sh` adds the mod to `sine-mods/mods.json`, appends a marked block to
`~/.config/matugen/config.toml` (backup next to it) and renders a first palette from the
shell's current source colour. `./install.sh --uninstall` reverts both.

Then disable **MatugenZen** and **Transparent Zen** in Sine: this mod replaces them.

## Colour and light/dark

matugen writes `colors.css` (both palettes + the shell's mode) next to `chrome.css`,
which imports it. No script is needed for that; the palette updates on the next start.

`m3e.uc.js` adds a live reload (a cheap `stat` every 2.5 s, paused while the window is
hidden) and the popup entrance flag. Sine runs scripts of locally installed mods only when
`sine.allow-unsafe-js` is `true`.

| Preference | Values |
|---|---|
| `m3e.scheme` | `shell` (matugen mode), `system`, `light`, `dark` |
| `m3e.colors-path` | another palette file (empty = the mod's `colors.css`) |
| `m3e.translucent` | translucent surfaces, for compositor blur with a transparent window |
| `m3e.system-font` | use the system font instead of Google Sans Flex |
| `m3e.reduced-motion` | no springs or staggered entrances (the OS setting is honoured too) |

## Weight

`chrome.css` is ~65 KiB of plain CSS parsed once. No `backdrop-filter`, no infinite
animations, no broad `:has()`; transitions are on transform, opacity, colour and radius.
The script does one `stat` per 2.5 s while visible.

## Develop

```sh
./build.py          # src/*.css -> chrome.css; regenerates the matugen template,
                    # the fallback palette and the shape polygons
```

Edit `src/`, never `chrome.css`. Visual tests run in a sandboxed, headless Zen — see
[`tests/README.md`](tests/README.md).
