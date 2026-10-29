// M3 Expressive for Zen — optional runtime helper.
//
// The theme works without this script: matugen writes colors.css next to chrome.css
// and the scheme is chosen in CSS. The script only adds two things:
//  * Live palette: when colors.css changes (new wallpaper, light/dark switch in the
//    shell), it is loaded into the window as an author sheet at once, instead of on the
//    next restart. A stat every few seconds, skipped while the window is hidden.
//  * Popup motion: popups get [m3e-open] while open so their content can spring in.
//  * Scroll edges: the tab list gets [m3e-at-start]/[m3e-at-end]/[m3e-scrolled] so its
//    edges fade only where there is something hidden (the shell's top/bottom gradient).
//  * Folder rows: each folder header gets [m3e-count] and up to three favicons as CSS
//    variables, so a closed folder previews what it holds.

(() => {
  "use strict";

  if (window.__m3eLoaded) return;
  window.__m3eLoaded = true;

  const PREF_PATH = "m3e.colors-path";
  const POLL_MS = 2500;

  const utils = window.windowUtils;
  let sheetURI = null;
  let lastMtime = -1;
  let timer = 0;

  function colorsPath() {
    let p = "";
    try {
      p = Services.prefs.getStringPref(PREF_PATH, "").trim();
    } catch {}
    if (!p) {
      const chrome = Services.dirsvc.get("UChrm", Ci.nsIFile).path;
      return PathUtils.join(chrome, "sine-mods", "m3-expressive", "colors.css");
    }
    return p.startsWith("~/") ? PathUtils.join(Services.dirsvc.get("Home", Ci.nsIFile).path, p.slice(2)) : p;
  }

  function unloadSheet() {
    if (!sheetURI) return;
    try {
      utils.removeSheetUsingURIString(sheetURI, utils.AUTHOR_SHEET);
    } catch {}
    sheetURI = null;
  }

  async function refresh() {
    const path = colorsPath();
    try {
      if (!(await IOUtils.exists(path))) {
        unloadSheet();
        lastMtime = -1;
        return;
      }
      const { lastModified } = await IOUtils.stat(path);
      if (lastModified === lastMtime) return;
      const first = lastMtime === -1 && !Services.prefs.prefHasUserValue(PREF_PATH);
      lastMtime = lastModified;
      // On the first pass the file is the same one chrome.css already imported.
      if (first) return;

      const css = await IOUtils.readUTF8(path);
      const next = "data:text/css;charset=utf-8," + encodeURIComponent(css);
      utils.loadSheetUsingURIString(next, utils.AUTHOR_SHEET);
      unloadSheet();
      sheetURI = next;
    } catch (e) {
      console.warn("[M3E] could not load palette:", e);
    }
  }

  function schedule() {
    clearTimeout(timer);
    // A hidden window skips the stat but keeps the (idle) timer: some compositors map
    // the window without ever sending visibilitychange.
    timer = setTimeout(() => (document.hidden ? Promise.resolve() : refresh()).then(schedule), POLL_MS);
  }

  const isPopup = (el) => el?.localName === "menupopup" || el?.localName === "panel";
  const onPopupShowing = (e) => isPopup(e.target) && e.target.setAttribute("m3e-open", "");
  const onPopupHidden = (e) => isPopup(e.target) && e.target.removeAttribute("m3e-open");

  // Scroll edges of the spaces' tab lists. One rAF per burst of scroll events, and an
  // attribute write only when a state flips.
  const EDGE = 2;
  let edgeFrame = 0;
  const pendingEdges = new Set();

  // The list's scrollbar lives in the arrowscrollbox's shadow tree, which mod CSS can't
  // reach (its own sheet sets scrollbar-width/colour). Hide it inline unless asked not to.
  const hideScrollbar = () => !Services.prefs.getBoolPref("m3e.show-sidebar-scrollbar", false);

  function updateEdges(box) {
    const sb = box.scrollbox;
    if (!sb) return;
    // !important: Zen's shadow sheet sets the active space's scrollbar with !important.
    if (hideScrollbar()) {
      if (sb.style.getPropertyPriority("scrollbar-width") !== "important") {
        sb.style.setProperty("scrollbar-width", "none", "important");
      }
    } else if (sb.style.scrollbarWidth) {
      sb.style.removeProperty("scrollbar-width");
    }
    const top = sb.scrollTop <= EDGE;
    const end = sb.scrollTop + sb.clientHeight >= sb.scrollHeight - EDGE;
    box.toggleAttribute("m3e-at-start", top);
    box.toggleAttribute("m3e-at-end", end);
    box.toggleAttribute("m3e-scrolled", true);
  }

  function queueEdges(box) {
    if (!box?.classList?.contains("workspace-arrowscrollbox")) return;
    pendingEdges.add(box);
    if (edgeFrame) return;
    edgeFrame = requestAnimationFrame(() => {
      edgeFrame = 0;
      for (const b of pendingEdges) updateEdges(b);
      pendingEdges.clear();
    });
  }

  const onScroll = (e) => queueEdges(e.target);
  const onOverflow = (e) => queueEdges(e.target);
  // Tab changes scroll the list programmatically (sometimes after a smooth scroll), so
  // re-check once things settle.
  const onTabsChanged = () => {
    setTimeout(() => {
      for (const b of document.querySelectorAll(".workspace-arrowscrollbox")) queueEdges(b);
    }, 400);
  };

  // Folder previews. Rebuilt in one rAF after any tab/folder change; attribute and
  // property writes only when the value differs.
  let folderFrame = 0;
  const cssURL = (u) => `url("${u.replace(/["\\\n]/g, encodeURIComponent)}")`;

  function updateFolders() {
    folderFrame = 0;
    for (const folder of document.querySelectorAll("zen-folder")) {
      const header = folder.querySelector(":scope > .tab-group-label-container");
      if (!header) continue;
      const tabs = [...folder.querySelectorAll(":scope > .tab-group-container > .tabbrowser-tab:not([zen-empty-tab])")];
      const count = String(tabs.length);
      if (header.getAttribute("m3e-count") !== count) header.setAttribute("m3e-count", count);
      const icons = tabs.map((t) => t.getAttribute("image")).filter(Boolean).slice(0, 3);
      // Each favicon: a 12px icon over a 22px chip with a 2px ring (radial gradient),
      // 15px apart so neighbours overlap by a ring's width. The first one is on top.
      const STEP = 15, CHIP = 22, ICON = 12;
      const ring = "radial-gradient(circle closest-side, var(--m3e-fav-chip) 0 9px, var(--m3e-fav-ring) 9px 11px, transparent 11px)";
      const layers = [], positions = [], sizes = [];
      icons.forEach((icon, i) => {
        const x = i * STEP;
        layers.push(cssURL(icon), ring);
        positions.push(`${x + (CHIP - ICON) / 2}px ${(CHIP - ICON) / 2}px`, `${x}px 0`);
        sizes.push(`${ICON}px ${ICON}px`, `${CHIP}px ${CHIP}px`);
      });
      const vars = {
        "--m3e-fav-layers": layers.join(", "),
        "--m3e-fav-positions": positions.join(", "),
        "--m3e-fav-sizes": sizes.join(", "),
        "--m3e-fav-width": icons.length ? `${CHIP + STEP * (icons.length - 1)}px` : "",
      };
      for (const [name, value] of Object.entries(vars)) {
        if (header.style.getPropertyValue(name) === value) continue;
        if (value) header.style.setProperty(name, value);
        else header.style.removeProperty(name);
      }
    }
  }
  const queueFolders = () => {
    if (!folderFrame) folderFrame = requestAnimationFrame(updateFolders);
  };
  const onTabAttr = (e) => {
    if (e.detail?.changed?.includes("image") && e.target.closest?.("zen-folder")) queueFolders();
  };

  const prefObserver = { observe: () => { lastMtime = -2; refresh(); } };

  function init() {
    refresh().then(schedule);
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) refresh().then(schedule);
    });
    window.addEventListener("popupshowing", onPopupShowing, true);
    window.addEventListener("popuphidden", onPopupHidden, true);
    window.addEventListener("scroll", onScroll, { capture: true, passive: true });
    window.addEventListener("overflow", onOverflow, true);
    window.addEventListener("underflow", onOverflow, true);
    window.addEventListener("scrollend", onScroll, { capture: true, passive: true });
    for (const type of ["TabSelect", "TabOpen", "TabClose", "TabPinned", "TabUnpinned", "ZenWorkspaceChanged"]) {
      window.addEventListener(type, onTabsChanged);
    }
    onTabsChanged();
    for (const type of ["TabOpen", "TabClose", "TabMove", "TabGrouped", "TabUngrouped", "TabPinned", "TabUnpinned", "TabGroupCreate", "TabGroupRemoved", "ZenWorkspaceChanged"]) {
      window.addEventListener(type, queueFolders);
    }
    window.addEventListener("TabAttrModified", onTabAttr);
    setTimeout(queueFolders, 1500);
    Services.prefs.addObserver(PREF_PATH, prefObserver);
    Services.prefs.addObserver("m3e.show-sidebar-scrollbar", onTabsChanged);
    window.addEventListener("unload", () => {
      clearTimeout(timer);
      Services.prefs.removeObserver(PREF_PATH, prefObserver);
      Services.prefs.removeObserver("m3e.show-sidebar-scrollbar", onTabsChanged);
    }, { once: true });
  }

  if (document.readyState === "complete") init();
  else window.addEventListener("load", init, { once: true });
})();
