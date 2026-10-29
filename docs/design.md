# Design notes

How the ii shell's Material 3 Expressive guide maps onto Zen. Read the shell's
`docs/design/material3-expressive.md` first; this file only records the decisions.

## Tokens

`src/02-tokens.css` mirrors the shell's `Appearance`:

| Shell | Mod |
|---|---|
| `rounding.small/normal/large/verylarge/full` (12/17/23/32/full) | `--m3e-r-sm/md/lg/xl/full` |
| `expressiveFastSpatial` 350 ms | `--m3e-spatial-fast`, `--m3e-d-fast` |
| `expressiveDefaultSpatial` 500 ms | `--m3e-spatial`, `--m3e-d` |
| `expressiveEffects` 200 ms | `--m3e-effects`, `--m3e-d-effects` |
| `emphasizedDecel` 400 ms / `emphasizedAccel` 200 ms | `--m3e-decel`, `--m3e-accel` |
| `colLayer0/1/2`, sheet, field | `--m3e-window/layer1/layer2/sheet/field` |
| matugen roles | `--m3-<role>` (both schemes as `--m3-light-*` / `--m3-dark-*`) |

Nothing outside the tokens file hard-codes a colour, radius or duration.

## One technique, one place

The guide asks not to repeat a technique. Where each one lives:

| Technique | Where | Why there |
|---|---|---|
| Grouped list (joins + notch around the selection) | sidebar tabs, pinned rows and folders, search results | the browser's rail, and the list under the hero (asked for explicitly) |
| Separate rows with a gap + icon badge | menus, app menu | the shell's own menu style |
| Section caption (caption face, no surface) | PINNED, TABS (the + is the new-tab button) | sections split by type and space, not panes |
| Expanding chip | the current space in the foot | names the space without a header block |
| Edge fade on scroll | the tab list, library history | shell technique; replaces divider lines |
| Shape is state (circle ↔ rounded square) | essentials, icon buttons, create FAB | small, frequent state changes |
| Polygon morph (equal-vertex `clip-path`) | search badge (Clover-4 → Sunny while typing), space mark in the foot chip (Cookie-9 → 12 on hover) | the two identity marks of the window |
| Clipped ornament | the search overlay's top-result card | the one hero on screen |
| Dashed unselected chip | "New tab", secondary buttons, library filters | an action that is not a state |
| Wide display face (`wdth 140`) | space name, result group headings, panel titles | headings only, never body text |
| Caption over value | "TOP RESULT" | forms vocabulary from the timetable rail |
| Pill selection | menu items, results, subview buttons | keyboard/hover target |
| Weight change on selection (animated `wght`) | tabs, results, menu rows | "animate weight, don't swap it" |
| Staggered entrance | search results, first reveal only | never replayed while typing |

## Type

Google Sans Flex is loaded through `@font-face` (`fonts/GoogleSansFlex.ttf`): with the
fontconfig face Gecko ignores `font-variation-settings` in chrome. Roles in
`02-tokens.css` always list `wght, wdth, ROND` in that order so weights interpolate:
body 440, label 560, strong 760/104, title 780, display 840/140 (wide), caption 820/118
uppercase, condensed 600/74 for urls and shortcuts.

## Motion

- Corner morphs use `--m3e-morph` (a soft spring) between concrete radii. Animating to
  or from `999px` with the spatial springs dips through 0 — a square flash — so animated
  pills use half their height instead.

- Springs (`--m3e-spatial*`) only for shape and position; colour and opacity use the
  effects curve.
- The overlay springs from 0.94 with a 10 px lift; menus spring from 0.92 towards their
  anchor side. On Linux the popup *window* can only fade, so the content animates inside it.
- No loops, no pulses, no decorative rotation. Hover 1.02 / press 0.95 is the only scale
  (press only here; hover scale would blur text in Gecko).
- `prefers-reduced-motion` and `m3e.reduced-motion` zero the spatial durations.

## Colour pipeline

```
wallpaper ─ matugen ─▶ sine-mods/m3-expressive/colors.css  (both schemes + {{ mode }})
                         │
chrome.css ── @import ───┘   unlayered: wins over the fallback palette (@layer)
           └─ -moz-pref("m3e.scheme", …) blocks (!important) force light/dark/system
m3e.uc.js  ── reloads colors.css as an author sheet when it changes (optional)
```

## Sidebar order

```
top bar · library        ← moved up from the foot (absolute, no layout change saved)
URL field
essentials tiles
[ + New Tab ]            dashed chip, outside the scroller (always visible)
PINNED                   caption only when there are pins
  pins / folders         closed folder = 1 row: icon · name · favicons · count
TABS                     caption
  tab list
foot: (◆ Space) ◇ ◇   [+] current space expands with its name; FAB
```

SuperPins' icon grid for pinned tabs is overridden inside the pinned section (doubled-id
selectors); essentials keep their tiles.
