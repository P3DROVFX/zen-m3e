# Changelog

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
