// M3 Expressive for Zen — optional runtime helper.
//
// The theme works without this script: matugen writes colors.css next to chrome.css
// and the scheme is chosen in CSS. The script only adds two things:
//  * Live palette: when colors.css changes (new wallpaper, light/dark switch in the
//    shell), it is loaded into the window as an author sheet at once, instead of on the
//    next restart. A stat every few seconds, skipped while the window is hidden.
//  * Popup motion: popups get [m3e-open] while open so their content can spring in;
//    context menus grow from the click point.
//  * Translations panel: a swap button between the two languages.
//  * Scroll edges: the tab list gets [m3e-at-start]/[m3e-at-end]/[m3e-scrolled] so its
//    edges fade only where there is something hidden (the shell's top/bottom gradient).
//  * Media cards: the Media Session artwork of each playing tab becomes its card's
//    background (--m3e-media-art), like Android's media player.
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

  // Context menus scale up from the click. A menu opened at the pointer (no anchor, not
  // a submenu or a list's dropdown) gets [m3e-point] and its content box grows from
  // 0.8 with a short, shallow fade. This runs here rather than in CSS: Sine loads the
  // mod as a user sheet, and Gecko ignores ::part() there, so the stylesheet can't reach
  // the popup's content box. The animation starts at once with the menu's usual corner
  // (top-left) as origin; on the first frame, when the popup is laid out but not yet
  // painted, the origin moves to the click point inside it (clamped to its box: near a
  // screen edge Gecko flips or slides the menu).
  const isPointMenu = (p) =>
    p.localName === "menupopup" && !p.anchorNode && !["menu", "menulist"].includes(p.parentNode?.localName);
  const token = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  const ms = (v) => (v.endsWith("ms") ? parseFloat(v) : parseFloat(v) * 1000) || 0;
  function clickPoint(e, popup) {
    if (e.screenX || e.screenY) return [e.screenX, e.screenY];
    // Page menus are opened from a synthetic event without coordinates; the content
    // process's click is still on nsContextMenu while popupshowing is dispatched.
    const c = popup.id === "contentAreaContextMenu" && window.nsContextMenu?.contentData?.context;
    if (c && Number.isFinite(c.screenXDevPx)) {
      return [c.screenXDevPx / window.devicePixelRatio, c.screenYDevPx / window.devicePixelRatio];
    }
    return null;
  }
  const menuAnimations = new WeakMap();
  const stopGrow = (popup) => {
    for (const a of menuAnimations.get(popup) ?? []) a.cancel();
    menuAnimations.delete(popup);
  };
  function growFromPoint(popup, [sx, sy]) {
    const content = popup.shadowRoot?.querySelector('[part~="content"]');
    if (!content) return;
    stopGrow(popup);
    content.style.transformOrigin = popup.matches(":-moz-locale-dir(rtl)") ? "100% 0" : "0 0";
    const grow = ms(token("--m3e-d-fast"));
    if (grow) {
      menuAnimations.set(popup, [
        content.animate([{ transform: "scale(0.8)" }, { transform: "none" }], {
          duration: grow, easing: token("--m3e-spatial") || "ease-out",
        }),
        content.animate([{ opacity: 0.5 }, { opacity: 1 }], {
          duration: ms(token("--m3e-d-effects")), easing: token("--m3e-effects") || "ease-out",
        }),
      ]);
    }
    requestAnimationFrame(() => {
      if (!popup.hasAttribute("m3e-point")) return;
      const box = content.getBoundingClientRect();
      const clamp = (v, max) => Math.round(Math.min(Math.max(v, 0), max));
      const x = clamp(sx - window.mozInnerScreenX - box.x, box.width);
      const y = clamp(sy - window.mozInnerScreenY - box.y, box.height);
      content.style.transformOrigin = `${x}px ${y}px`;
    });
  }

  const onPopupShowing = (e) => {
    const popup = e.target;
    if (!isPopup(popup)) return;
    popup.setAttribute("m3e-open", "");
    const point = isPointMenu(popup) && clickPoint(e, popup);
    if (point) {
      popup.setAttribute("m3e-point", "");
      growFromPoint(popup, point);
    }
    if (popup.id === "full-page-translations-panel") setupTranslations(popup);
  };
  const onPopupHidden = (e) => {
    const popup = e.target;
    if (!isPopup(popup)) return;
    popup.removeAttribute("m3e-open");
    if (popup.hasAttribute("m3e-point")) {
      popup.removeAttribute("m3e-point");
      stopGrow(popup);
    }
  };

  // Translations panel: a swap button between the two language pills. It drives the
  // panel through its own menulists and command handlers, so telemetry, the remembered
  // target language and the Translate button's state stay Firefox's.
  const TR = "full-page-translations-panel";
  function setupTranslations(panel) {
    const from = document.getElementById(`${TR}-from`);
    const to = document.getElementById(`${TR}-to`);
    if (!from || !to) return;
    // The chevron moves to the caption; the menulist's own dropmarker is in its shadow
    // tree, out of the stylesheet's reach (no ::part() in user sheets).
    for (const list of [from, to]) {
      list.shadowRoot?.querySelector("dropmarker")?.style.setProperty("display", "none", "important");
    }
    let swap = document.getElementById("m3e-translations-swap");
    if (!swap) {
      swap = document.createXULElement("toolbarbutton");
      swap.id = "m3e-translations-swap";
      swap.setAttribute("tooltiptext", "Swap languages");
      swap.setAttribute("aria-label", "Swap languages");
      swap.setAttribute("tabindex", "0");
      swap.setAttribute("closemenu", "none"); // a panel closes on any other toolbarbutton
      swap.addEventListener("command", () => swapLanguages(from, to, swap));
      from.after(swap);
      panel.addEventListener("command", () => requestAnimationFrame(() => updateSwap(from, to, swap)));
    }
    // The lists are filled while the panel opens; check once they are.
    requestAnimationFrame(() => updateSwap(from, to, swap));
  }
  const itemFor = (list, value) =>
    value ? list.menupopup?.querySelector(`menuitem[value="${CSS.escape(value)}"]`) : null;
  function updateSwap(from, to, swap) {
    swap.toggleAttribute("disabled", !(itemFor(to, from.value) && itemFor(from, to.value)));
  }
  function swapLanguages(from, to, swap) {
    const a = from.value, b = to.value;
    const intoFrom = itemFor(from, b), intoTo = itemFor(to, a);
    if (!intoFrom || !intoTo) return;
    from.value = b;
    to.value = a;
    intoFrom.doCommand();
    intoTo.doCommand();
    swap.toggleAttribute("m3e-swapped");
  }

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

  // Media cards. Zen's cards know their tab only internally; a card shows its
  // metadata title, so match it against the tabs' media controllers. Re-evaluated in
  // one rAF whenever the media bar's markup or labels change.
  let mediaFrame = 0;
  function artworkByTitle() {
    const map = new Map();
    for (const tab of gBrowser.tabs) {
      let meta = null;
      try {
        meta = tab.linkedBrowser?.browsingContext?.mediaController?.getMetadata();
      } catch {}
      if (!meta?.title || !meta.artwork?.length) continue;
      const size = (a) => Math.max(...String(a.sizes || "0x0").split(/[x\s]/i).map(Number).filter(Number.isFinite), 0);
      const best = [...meta.artwork].sort((a, b) => size(b) - size(a))[0];
      if (best?.src) map.set(meta.title, best.src);
    }
    return map;
  }
  function updateMedia() {
    mediaFrame = 0;
    const cards = document.querySelectorAll("#zen-media-controls-toolbar .zen-media-card");
    if (!cards.length) return;
    const art = artworkByTitle();
    for (const card of cards) {
      const title = card.querySelector(".zen-media-title")?.getAttribute("value") ||
        card.querySelector(".zen-media-title")?.textContent || "";
      const src = art.get(title);
      const value = src ? cssURL(src) : "";
      if (card.style.getPropertyValue("--m3e-media-art") === value) continue;
      if (value) card.style.setProperty("--m3e-media-art", value);
      else card.style.removeProperty("--m3e-media-art");
      card.toggleAttribute("m3e-has-art", !!value);
    }
  }
  const queueMedia = () => {
    if (!mediaFrame) mediaFrame = requestAnimationFrame(updateMedia);
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
    const mediaBar = document.getElementById("zen-media-controls-toolbar");
    if (mediaBar) {
      new MutationObserver(queueMedia).observe(mediaBar, {
        childList: true, subtree: true, attributes: true, attributeFilter: ["value", "hidden", "class"],
      });
    }
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
