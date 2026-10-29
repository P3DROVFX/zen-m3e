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
| Grouped list (joins + notch around the selection) | sidebar tabs | the rail of the browser, like `ClockRail` |
| Shape is state (circle ↔ rounded square) | essentials, icon buttons, create FAB | small, frequent state changes |
| Polygon morph (equal-vertex `clip-path`) | search badge (Clover-4 → Sunny while typing), space icon (Cookie-9 → 12 on hover) | the two identity marks of the window |
| Clipped ornament | the search overlay's top-result card | the one hero on screen |
| Dashed unselected chip | "New tab", secondary buttons | an action that is not a state |
| Wide display face (`wdth 128`) | space name, result group headings, panel titles | headings only, never body text |
| Caption over value | "TOP RESULT" | forms vocabulary from the timetable rail |
| Pill selection | menu items, results, subview buttons | keyboard/hover target |
| Staggered entrance | search results, first reveal only | never replayed while typing |

## Motion

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
