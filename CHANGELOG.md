# Changelog

## 0.7.1 — 2026-10-30

- Zen Internet works with the glass: when `browser.tabs.allow_transparent_browser` is on,
  nothing opaque is painted behind pages, so sites it makes transparent show the
  Hyprland blur (before, they showed the scheme's surface colour instead).
- `install.sh --glass` turns `allow_transparent_browser` on (it is what Zen Internet
  needs); sites with their own background — and video — stay opaque.

## 0.7.0 — 2026-10-29

Glass, tested on Hyprland: the browser UI is translucent (compositor blur shows through
sidebar, top bar, gaps and empty tabs) while pages and video stay opaque, as Zen's Mica
does on Windows.
- One translucent window layer (`#zen-browser-background`), every other window-level
  layer transparent; tint presets light / medium / strong.
- Empty tabs show the glass (their about:blank isn't drawn while current).
- Floating surfaces over the page stay nearly opaque (backdrop-filter can't sample web
  content); menus nearly opaque unless popup blur is on.
- `install.sh --glass`: window alpha on, transparent pages off, and the old
  userChrome/userContent transparency rules moved out with backups.
- Glass preferences in the mod's settings (including the Zen prefs it relies on).

## 0.6.0 — 2026-10-29

- Search overlay scales up (0.86 → 1) with the emphasized-decelerate ease.
- Site panel redesigned: tonal quick-action pills, circle → rounded-square extensions,
  dashed "add", caption headers with tonal Manage/More chips, menu-style settings row,
  tonal security pill and round footer buttons.
- Micro-motion: selection pop (tabs, results, space chip), space mark pop-in, folder rows
  deal in on open, preview/count pop, close button pop on hover, FAB plus turns into a
  cross while its menu is open, menu rows stagger in, check marks pop, snackbars rise,
  library sections lift in, press feedback on small controls.

## 0.5.1 — 2026-10-29

- Folder rows share the header's column without SuperPins: Zen's 14 px per-tab indent in
  folders is cancelled (only the row content is indented).

## 0.5.0 — 2026-10-29

- Essentials no longer overflow the sidebar: the in-flow grid shares the URL field's box.
- SuperPins integrated (MIT, credited): essentials width / gap / auto-grow (the last row
  stretches too), transparent essentials, favicon size (default 20 px), dimmed unloaded
  tabs, hidden sidebar scrollbar — all as `m3e.*` preferences. SuperPins can be disabled.
- The sidebar scrollbar is hidden from the script (it lives in a shadow tree whose sheet
  marks it `!important`).

## 0.4.2 — 2026-10-29

- The new-tab chip no longer slides under the essentials: the current essentials grid is
  back in the flow and the space's inline padding-top is dropped.
- Menus: M3 checkbox (outlined → primary fill with a check) and radio (outlined →
  primary ring with a dot) in the badge column.

## 0.4.1 — 2026-10-29

- New tab is the dashed chip again, at the top of the list and outside the scroller (so
  it never scrolls away); TABS and PINNED stay as captions.
- Pinned rows, folders, the tab list, the URL field and the new-tab chip share one box
  (the spaces wrapper is clipped instead of scrollable, and each space is no wider than
  the list); pinned rows are as tall and as tightly spaced as tab rows; folders sit 8 px
  apart.
- The first and last tab get the group's outer radius again (Zen's hidden empty tab no
  longer counts).
- Closed-folder favicon preview: each icon on its own round chip with a ring.
- Spaces with an icon (not an emoji) keep a 14 px icon inside the 26 px cookie.
- The spaces strip never widens the sidebar.

## 0.4.0 — 2026-10-29

Sidebar reorganised so the tab list starts near the top:
- Space header removed; the current space's chip in the foot expands with its name and
  carries the space mark in a morphing cookie.
- Pinned tabs and folders are rows under a PINNED caption (SuperPins' grid overridden in
  the pinned section). A closed folder is one row with a three-favicon preview and a tab
  count (m3e.uc.js); an open folder lists its tabs indented, as its own group.
- The new-tab button becomes the TABS caption with a `+` at its end.
- The library button moves up to the top bar.
- Pinned section matches the tab list's box; no 25 px hole before TABS.

## 0.3.0 — 2026-10-29

- Zen Library themed: navigation rail (pill → rounded square in primary container),
  field-pill search, tonal filter button, dashed filter chips, caption group headings,
  favicon tiles, condensed subtitles, scroll fade instead of a border, space panes.
- Spaces switcher icons centred (panel row rules no longer leak onto `.subviewbutton`s
  outside panels).
- "New" menu rows centred (a two-value padding variable had become `padding-bottom`).
- Folders span the same width as the space header, with 8 px between them.
- "New tab" chip content centred.
- App menu rows keep an 8 px margin from the panel edge; zoom row rebuilt (connected
  − 100% + group, separate full-screen button).
- Search: the field ends flush with the results; the results scroller has a radius, so
  rows are clipped round instead of cut square.

## 0.2.0 — 2026-10-29

- Type: Google Sans Flex through `@font-face` so the variable axes actually apply; type
  roles (display, title, strong, caption, condensed); selected tabs/results/menu rows gain
  weight with an animated `wght`.
- Corners no longer flash square on hover: concrete pill radii and a soft morph curve.
- Sidebar: space header and folders as panes; collapse chevron and "Clear" button gone;
  tighter tab rows (2 px gap); pinned tile icons centred; the tab list fades at its edges
  while scrolling instead of drawing divider lines; update card opaque.
- Search: compact hero (caption + title, no wrapping); results as a grouped list with the
  shell's dynamic radius; hero and rows share one text column.
- Menus and app menu in the shell's style: separate rows, icon badges (Zen icons mapped
  onto context-menu items), group gaps.

## 0.1.0 — 2026-10-29

First release.

- Tokens mirroring the ii shell's `Appearance` (shape scale, M3E spring curves, surface ladder).
- matugen template with both schemes; `colors.css` imported by `chrome.css`, so the theme
  works without scripts. Scheme follows the shell, the system, or is forced (`m3e.scheme`).
- Sidebar: grouped tab list with a primary pill and notched neighbours, shape-is-state
  essentials, wide display face for the space header with a morphing cookie icon, dashed
  "new tab" chip, create FAB, media card, folders.
- Search overlay: Clover-4 → Sunny badge, field pill, "top result" hero with caption,
  springing "Open ↵" pill and clipped ornament, wide group headings, favicon tiles, pill
  selection, engine chips, spring entrance and one-shot staggered rows.
- Menus and panels: item → pill morph, gap separators, tertiary open submenu, spring from
  the anchor, title-face headers, connected zoom group, dashed/filled buttons.
- Tooltips, find bar, toasts, notifications, glance, split view, scrollbars.
- `m3e.uc.js`: live palette reload and popup entrance flag.
- `install.sh` (symlink/copy, matugen hook, uninstall) and sandboxed visual tests.
