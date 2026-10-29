# Changelog

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
