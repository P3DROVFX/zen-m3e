// M3 Expressive for Zen — optional runtime helper.
//
// The theme works without this script: matugen writes colors.css next to chrome.css
// and the scheme is chosen in CSS. The script only adds two things:
//  * Live palette: when colors.css changes (new wallpaper, light/dark switch in the
//    shell), it is loaded into the window as an author sheet at once, instead of on the
//    next restart. A stat every few seconds, skipped while the window is hidden.
//  * Popup motion: popups get [m3e-open] while open so their content can spring in.

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

  const prefObserver = { observe: () => { lastMtime = -2; refresh(); } };

  function init() {
    refresh().then(schedule);
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) refresh().then(schedule);
    });
    window.addEventListener("popupshowing", onPopupShowing, true);
    window.addEventListener("popuphidden", onPopupHidden, true);
    Services.prefs.addObserver(PREF_PATH, prefObserver);
    window.addEventListener("unload", () => {
      clearTimeout(timer);
      Services.prefs.removeObserver(PREF_PATH, prefObserver);
    }, { once: true });
  }

  if (document.readyState === "complete") init();
  else window.addEventListener("load", init, { once: true });
})();
