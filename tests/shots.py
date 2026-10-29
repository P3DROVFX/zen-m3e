#!/usr/bin/env python3
"""Visual test scenes for a sandboxed Zen (see tests/README.md).

Drives Zen over Marionette (chrome context) and grabs the X root of the headless
display with ImageMagick `import`, so popups and the floating URL bar are captured.

usage: shots.py OUT_DIR [scene ...]   scenes: setup sidebar urlbar urlbar-typing
                                              context appmenu light
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from marionette import Marionette  # noqa: E402

DISPLAY = os.environ.get("M3E_DISPLAY", ":97")
OUT = sys.argv[1]
SCENES = sys.argv[2:] or ["setup", "sidebar", "context", "appmenu", "urlbar", "urlbar-typing", "light"]

m = Marionette()


def grab(name, delay=1.4):
    time.sleep(delay)
    # Without a compositor the X root can lag a repaint behind; a 1px resize flushes it.
    if not name.startswith(("urlbar", "context", "appmenu", "light-urlbar")):
        js("return new Promise(r => { window.resizeTo(1399, 860); setTimeout(() => { window.resizeTo(1400, 860); setTimeout(r, 700); }, 200); })")
    path = os.path.join(OUT, f"{name}.png")
    subprocess.run(["import", "-display", DISPLAY, "-window", "root", path], check=True)
    print(path)


def js(src):
    return m.js(src)


def close_all():
    js("""
      for (const p of document.querySelectorAll('menupopup, panel')) {
        try { if (p.state === 'open') p.hidePopup(); } catch {}
      }
      try { gURLBar.handleRevert(); } catch {}
      try { gURLBar.view.close(); } catch {}
      try { gZenUIManager.onUrlbarClose(); } catch {}
      gURLBar.blur();
      gBrowser.selectedBrowser.focus();
    """)
    time.sleep(0.3)


def setup():
    js("""
      return new Promise(async done => {
        window.moveTo(0, 0); window.resizeTo(1400, 860);
        try { gZenCompactModeManager.preference = false; } catch {}
        const sys = Services.scriptSecurityManager.getSystemPrincipal();
        const page = (t, c) => 'data:text/html,' + encodeURIComponent(
          `<title>${t}</title><body style="margin:0;background:${c};font:600 42px sans-serif;display:grid;place-items:center;height:100vh;color:#0008">${t}</body>`);
        const pages = [['Material 3 Expressive', '#f6dccb'], ['Zen Browser Docs', '#e8e0d4'],
                       ['GitHub — P3DROVFX', '#dfe6ee'], ['Quickshell', '#e3efe1'], ['Matugen', '#efe3f1']];
        // Start clean: Zen keeps pins in its own store across sessions.
        for (const t of [...gBrowser.tabs]) { if (t.hasAttribute('zen-essential')) gZenPinnedTabManager.removeEssentials?.(t); if (t.pinned) gBrowser.unpinTab(t); }
        gBrowser.removeAllTabsBut(gBrowser.selectedTab);
        for (const [t, c] of pages) gBrowser.addTab(page(t, c), { triggeringPrincipal: sys });
        await new Promise(r => setTimeout(r, 800));
        const tabs = gBrowser.tabs.filter(t => !t.pinned);
        gBrowser.pinTab(tabs[1]);
        gBrowser.selectedTab = tabs[3];
        const now = Date.now() * 1000;
        const visits = [['https://github.com/', 'GitHub'], ['https://github.com/P3DROVFX/zen-m3e', 'P3DROVFX/zen-m3e'],
                        ['https://m3.material.io/', 'Material Design 3'], ['https://gitlab.com/', 'GitLab'],
                        ['https://git-scm.com/docs', 'Git - Reference'], ['https://docs.zen-browser.app/', 'Zen Docs']];
        await PlacesUtils.history.insertMany(visits.map(([url, title], i) => ({ url, title,
          visits: [{ date: new Date(Date.now() - i * 60000), transition: PlacesUtils.history.TRANSITIONS.TYPED }] })));
        for (const el of document.querySelectorAll('#zen-sidebar-notification, .zen-sidebar-notification')) el.remove();
        setTimeout(() => done(true), 1500);
      });
    """)


def sidebar():
    close_all()
    grab("sidebar")


def urlbar(text=""):
    close_all()
    js(f"""
      return new Promise(async r => {{
        window.focus(); document.getElementById('urlbar').focus();
        gURLBar.select();
        {"gURLBar.search(" + repr(text) + ");" if text else "gURLBar.startQuery();"}
        setTimeout(() => r(true), 700);
      }});
    """)
    grab("urlbar-typing" if text else "urlbar")


LABEL_FIX = """
  // Fluent strings don't resolve in the sandbox profile; label items from their ids.
  for (const it of document.querySelectorAll('menupopup > menuitem, menupopup > menu')) {
    if (!it.getAttribute('label') && it.id) it.setAttribute('label',
      it.id.replace(/^(context|menu|toggle)_?/i, '').replace(/([a-z])([A-Z])/g, '$1 $2').replace(/^./, c => c.toUpperCase()));
  }
"""


def context():
    close_all()
    js(LABEL_FIX)
    js("""
      const tab = gBrowser.selectedTab;
      const r = tab.getBoundingClientRect();
      const menu = document.getElementById('tabContextMenu');
      menu.openPopupAtScreen(window.screenX + r.x + 60, window.screenY + r.y + r.height / 2, true);
      setTimeout(() => document.getElementById('context_reloadTab')?.setAttribute('_moz-menuactive', 'true'), 500);
    """)
    grab("context", 2.5)
    close_all()
    js("""
      const b = gBrowser.selectedBrowser.getBoundingClientRect();
      document.getElementById('contentAreaContextMenu').openPopupAtScreen(window.screenX + b.x + 300, window.screenY + b.y + 200, true);
    """)
    grab("context-page")


def appmenu():
    close_all()
    js("return new Promise(r => setTimeout(() => { PanelUI.show(); r(true); }, 500));")
    grab("appmenu", 2)


def light():
    close_all()
    js("Services.prefs.setStringPref('m3e.scheme', 'light');")
    grab("light-sidebar", 2.5)
    urlbar("git")
    os.replace(os.path.join(OUT, "urlbar-typing.png"), os.path.join(OUT, "light-urlbar.png"))
    close_all()
    js("Services.prefs.setStringPref('m3e.scheme', 'shell');")


SCENE_FNS = {
    "setup": setup, "sidebar": sidebar, "urlbar": urlbar,
    "urlbar-typing": lambda: urlbar("git"), "context": context, "appmenu": appmenu, "light": light,
}

for s in SCENES:
    SCENE_FNS[s]()
