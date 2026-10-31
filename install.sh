#!/usr/bin/env bash
# Install M3 Expressive into a Zen profile that uses Sine, and hook it into matugen.
#
#   ./install.sh                 symlink this repo into the default Zen profile
#   ./install.sh --copy          copy instead of symlink
#   ./install.sh --profile DIR   pick the profile explicitly (about:support > Profile Folder).
#                                Without it: every Zen profile with Sine — native ~/.zen,
#                                ~/.config/zen, Flatpak, Snap — most recently used first;
#                                asks when there is more than one.
#   ./install.sh --no-matugen    skip the matugen template
#   ./install.sh --no-font-download
#                                don't fetch Google Sans Flex when it isn't installed
#   ./install.sh --source SRC    colours from a specific image or #hex colour, e.g.
#                                  ./install.sh --source ~/Pictures/wall.jpg
#                                  ./install.sh --source '#8c4a00'
#                                without it: the ii shell's colour, else the detected
#                                wallpaper (swww/awww, hyprpaper, waypaper, KDE, GNOME).
#                                Re-run with it any time to change the palette.
#   ./install.sh --uninstall     remove the mod and the matugen template block
#   ./install.sh --glass         translucent window (Linux "Mica"): window alpha on, pages
#                                opaque; moves out userChrome/userContent rules that make
#                                every page transparent (backups kept). Zen must be closed.
#
# Close Zen first: Sine rewrites mods.json while it runs.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ID="m3-expressive"
MATUGEN_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml"
MARK_BEGIN="# >>> zen-m3e >>>"
MARK_END="# <<< zen-m3e <<<"

mode=symlink profile="" matugen=1 uninstall=0 glass=0 source="" download_font=1
while (($#)); do
    case "$1" in
        --copy) mode=copy ;;
        --profile) profile="$2"; shift ;;
        --no-matugen) matugen=0 ;;
        --uninstall) uninstall=1 ;;
        --glass) glass=1 ;;
        --source) source="$2"; shift ;;
        --no-font-download) download_font=0 ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

die() { echo "error: $*" >&2; exit 1; }

# ---------------------------------------------------------------- profile
# Every Zen profile on this machine, one per line: path<TAB>sine(0/1)<TAB>label.
# Reads profiles.ini / installs.ini under each place Zen keeps them: native (~/.zen),
# XDG (~/.config/zen), Flatpak (~/.var/app/<id>/zen, and the older .zen / config/zen),
# Snap. Sine profiles first, then the most recently used (prefs.js is written on exit).
list_profiles() {
    python3 - <<'EOF'
import configparser, os, time
home = os.path.expanduser("~")
xdg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config")
roots = [os.path.join(home, ".zen"), os.path.join(xdg, "zen")]
for app in ("app.zen_browser.zen", "io.github.zen_browser.zen"):
    base = os.path.join(home, ".var/app", app)
    roots += [os.path.join(base, "zen"), os.path.join(base, ".zen"), os.path.join(base, "config/zen")]
roots += [os.path.join(home, "snap/zen-browser/common/.zen"), os.path.join(home, "snap/zen-browser/current/.zen")]

def ini(path):
    cp = configparser.RawConfigParser(strict=False)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
    except configparser.Error:
        pass
    return cp

found, seen = [], set()
for root in roots:
    if not os.path.isdir(root):
        continue
    prof = ini(os.path.join(root, "profiles.ini"))
    defaults = {s.get("Default") for s in (ini(os.path.join(root, "installs.ini")), prof)
                for s in s.values() if s.get("Default") not in (None, "1", "0")}
    paths = []
    for name in prof.sections():
        sec = prof[name]
        if name.startswith("Profile") and sec.get("Path"):
            rel = sec.get("IsRelative", "1") == "1"
            paths.append((os.path.join(root, sec["Path"]) if rel else sec["Path"], sec.get("Path") in defaults))
    # Profiles a broken or missing profiles.ini doesn't list.
    for entry in os.listdir(root):
        if os.path.isfile(os.path.join(root, entry, "prefs.js")):
            paths.append((os.path.join(root, entry), entry in defaults))
    for path, default in paths:
        real = os.path.realpath(path)
        if real in seen or not os.path.isdir(real):
            continue
        seen.add(real)
        chrome = os.path.join(path, "chrome")
        sine = os.path.isfile(os.path.join(chrome, "JS", "sine.sys.mjs")) or os.path.isdir(os.path.join(chrome, "sine-mods"))
        try:
            used = os.path.getmtime(os.path.join(path, "prefs.js"))
        except OSError:
            used = 0
        label = "used " + time.strftime("%Y-%m-%d", time.localtime(used)) if used else "never used"
        if default:
            label += ", install default"
        found.append((sine, used, path, label))
for sine, used, path, label in sorted(found, key=lambda f: (f[0], f[1]), reverse=True):
    print(f"{path}\t{int(sine)}\t{label}")
EOF
}

if [[ -z "$profile" ]]; then
    mapfile -t profiles < <(list_profiles)
    ((${#profiles[@]})) || die "no Zen profile found (looked in ~/.zen, ~/.config/zen, the Flatpak and the Snap).
Open about:support in Zen, copy \"Profile Folder\" and run: $0 --profile DIR"
    sine_profiles=()
    for line in "${profiles[@]}"; do
        [[ $(cut -f2 <<<"$line") == 1 ]] && sine_profiles+=("$line")
    done
    if ((${#sine_profiles[@]} == 0)); then
        echo "Zen profiles found, but none has Sine installed:" >&2
        for line in "${profiles[@]}"; do printf '  %s  (%s)\n' "$(cut -f1 <<<"$line")" "$(cut -f3 <<<"$line")" >&2; done
        die "install Sine (https://github.com/CosmoCreeper/Sine) and start Zen once, or pass --profile DIR"
    fi
    profile="$(cut -f1 <<<"${sine_profiles[0]}")"
    if ((${#sine_profiles[@]} > 1)); then
        echo "Zen profiles with Sine:"
        for i in "${!sine_profiles[@]}"; do
            printf '  %d) %s  (%s)\n' $((i + 1)) "$(cut -f1 <<<"${sine_profiles[i]}")" "$(cut -f3 <<<"${sine_profiles[i]}")"
        done
        if [[ -t 0 ]]; then
            read -rp "Install into which? [1] " pick
            if [[ -n "$pick" ]]; then
                [[ "$pick" =~ ^[0-9]+$ ]] && ((pick >= 1 && pick <= ${#sine_profiles[@]})) || die "no profile $pick"
                profile="$(cut -f1 <<<"${sine_profiles[pick - 1]}")"
            fi
        else
            echo "using the most recently used one (pass --profile DIR for another)"
        fi
    fi
fi
profile="${profile%/}"
[[ -d "$profile" ]] || die "$profile is not a directory"
[[ -f "$profile/chrome/JS/sine.sys.mjs" || -d "$profile/chrome/sine-mods" ]] \
    || die "$profile has no Sine (chrome/JS/sine.sys.mjs). Install Sine and start Zen once."
echo "profile: $profile"
mods_dir="$profile/chrome/sine-mods"
mkdir -p "$mods_dir"
target="$mods_dir/$MOD_ID"

if pgrep -x zen >/dev/null || pgrep -f '/zen/zen$' >/dev/null; then
    echo "warning: Zen is running; Sine may overwrite mods.json. Close Zen and run again." >&2
fi

# ---------------------------------------------------------------- mods.json
edit_mods_json() {
    python3 - "$mods_dir/mods.json" "$REPO/theme.json" "$1" <<'EOF'
import json, sys
path, theme_path, action = sys.argv[1:]
try:
    mods = json.load(open(path))
except FileNotFoundError:
    mods = {}
if action == "add":
    theme = json.load(open(theme_path))
    theme.update(enabled=True, origin="local")
    mods[theme["id"]] = theme
else:
    mods.pop("m3-expressive", None)
json.dump(mods, open(path, "w"), indent=2)
EOF
}

# ---------------------------------------------------------------- matugen
remove_matugen_block() {
    [[ -f "$MATUGEN_CFG" ]] || return 0
    python3 - "$MATUGEN_CFG" "$MARK_BEGIN" "$MARK_END" <<'EOF'
import sys, re
path, begin, end = sys.argv[1:]
text = open(path).read()
text = re.sub(r"\n?" + re.escape(begin) + r".*?" + re.escape(end) + r"\n?", "\n", text, flags=re.S)
open(path, "w").write(text)
EOF
}

add_matugen_block() {
    command -v matugen >/dev/null || die "matugen not found (install it, or use --no-matugen)"
    if [[ ! -f "$MATUGEN_CFG" ]]; then
        mkdir -p "$(dirname "$MATUGEN_CFG")"
        printf '[config]\n' >"$MATUGEN_CFG"
        echo "created $MATUGEN_CFG"
    fi
    cp "$MATUGEN_CFG" "$MATUGEN_CFG.bak-zen-m3e"
    remove_matugen_block
    cat >>"$MATUGEN_CFG" <<EOF

$MARK_BEGIN
[templates.zen-m3e]
input_path = '$target/matugen/zen-m3e.css'
output_path = '$target/colors.css'
$MARK_END
EOF
}

# First palette now, without re-running the user's whole matugen config. matugen keeps
# no state of its own, so the source comes from (first match wins): --source, the ii
# shell's current colour, or the wallpaper the desktop is showing.
detect_wallpaper() {   # prints "<file>|<where from>", nothing if unknown
    local f
    f="$( (swww query || awww query) 2>/dev/null | sed -n 's/.*image: *//p' | head -1 || true)"
    [[ -f "$f" ]] && { echo "$f|swww"; return; }
    f="$(hyprctl hyprpaper listactive 2>/dev/null | sed -n 's/^[^=]* = *//p' | head -1 || true)"
    [[ -f "$f" ]] && { echo "$f|hyprpaper"; return; }
    f="$(sed -n 's/^wallpaper *= *//p' "${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini" 2>/dev/null | head -1 || true)"
    f="${f/#\~/$HOME}"
    [[ -f "$f" ]] && { echo "$f|waypaper"; return; }
    f="$(sed -n 's|^Image=file://||p' "${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | head -1 || true)"
    [[ -f "$f" ]] && { echo "$f|KDE Plasma"; return; }
    local key=picture-uri
    [[ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" == *dark* ]] && key=picture-uri-dark
    f="$(gsettings get org.gnome.desktop.background "$key" 2>/dev/null | sed "s|^'file://||; s|'$||" || true)"
    [[ -f "$f" ]] && { echo "$f|GNOME ($key)"; return; }
}

render_now() {
    local src="$source" from="--source" mode tmp found
    if [[ -z "$src" ]]; then
        src="$(cat "$HOME/.local/state/quickshell/user/generated/color.txt" 2>/dev/null || true)"
        from="the ii shell"
    fi
    if [[ -z "$src" ]]; then
        found="$(detect_wallpaper)"
        src="${found%%|*}" from="${found#*|}"
    fi
    if [[ -z "$src" ]]; then
        echo "note: couldn't find your wallpaper; pass --source IMAGE, or colors.css appears the next time you run matugen."
        return 0
    fi
    mode=dark
    [[ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" == *light* ]] && mode=light
    tmp="$(mktemp -d)"
    printf "[config]\n[templates.m3e]\ninput_path = '%s'\noutput_path = '%s'\n" \
        "$target/matugen/zen-m3e.css" "$target/colors.css" >"$tmp/config.toml"
    if [[ "$src" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        matugen color hex "$src" -c "$tmp/config.toml" -m "$mode" -q
    elif [[ -f "$src" ]]; then
        matugen image "$src" -c "$tmp/config.toml" -m "$mode" -q --prefer saturation
    else
        rm -rf "$tmp"; die "--source must be an image file or a #rrggbb colour"
    fi
    rm -rf "$tmp"
    echo "palette: $src ($mode, from $from) -> $target/colors.css"
    [[ "$from" == --source || "$from" == "the ii shell" ]] || \
        echo "         not the right wallpaper? run again with --source IMAGE"
}

# ---------------------------------------------------------------- glass
set_pref() {   # set_pref NAME VALUE  (prefs.js; Zen must be closed)
    python3 - "$profile/prefs.js" "$1" "$2" <<'EOF'
import re, sys
path, name, value = sys.argv[1:]
text = open(path).read()
line = f'user_pref("{name}", {value});'
pat = re.compile(r'^user_pref\("' + re.escape(name) + r'",.*\);$', re.M)
text = pat.sub(line, text) if pat.search(text) else text.rstrip("\n") + "\n" + line + "\n"
open(path, "w").write(text)
EOF
}

neutralise() {  # keep a backup, leave a note instead of rules that make pages transparent
    local f="$1"
    [[ -f "$f" ]] || return 0
    grep -qi "transparent" "$f" || return 0
    cp "$f" "$f.bak-zen-m3e"
    printf '/* Transparency rules moved out by zen-m3e --glass (backup: %s).\n   They made every web page transparent; M3 Expressive keeps pages opaque\n   and makes only the browser UI translucent. */\n' "$(basename "$f").bak-zen-m3e" >"$f"
    echo "neutralised $f (backup kept)"
}

if ((glass)); then
    if pgrep -f '/zen/zen$' >/dev/null || pgrep -x zen >/dev/null; then
        die "close Zen first: it rewrites prefs.js on exit"
    fi
    cp "$profile/prefs.js" "$profile/prefs.js.bak-zen-m3e"
    set_pref zen.widget.linux.transparency true
    # Pages may be transparent: Zen Internet's per-site styles let the glass through.
    set_pref browser.tabs.allow_transparent_browser true
    set_pref m3e.translucent true
    neutralise "$profile/chrome/userChrome.css"
    neutralise "$profile/chrome/userContent.css"
    cat <<EOT
glass on for $profile
  * Start Zen. The sidebar, top bar and empty tabs show your compositor's blur (if it
    blurs behind translucent windows: Hyprland, SwayFX, picom… — see
    docs/compatibility.md); pages and video stay opaque. Tint: settings > Glass tint.
  * Menus stay nearly opaque. For translucent menus your compositor must blur popups
    (Hyprland: decoration { blur { popups = true } }); then tick "Translucent menus too".
  * Undo: restore the *.bak-zen-m3e files.
EOT
    exit 0
fi

# ---------------------------------------------------------------- run
cp "$mods_dir/mods.json" "$mods_dir/mods.json.bak-zen-m3e" 2>/dev/null || true

if ((uninstall)); then
    edit_mods_json remove
    rm -rf "$target"
    ((matugen)) && remove_matugen_block
    echo "removed $MOD_ID from $profile"
    exit 0
fi

rm -rf "$target"
if [[ $mode == symlink ]]; then
    ln -s "$REPO" "$target"
else
    mkdir -p "$target"
    cp -r "$REPO"/{theme.json,preferences.json,chrome.css,m3e.uc.js,README.md,matugen} "$target"/
fi
edit_mods_json add

# Google Sans Flex next to chrome.css: Gecko only honours the variable axes
# (font-variation-settings) for a face loaded through @font-face. Use the installed
# variable font; if there is none, fetch it (SIL OFL 1.1) from google/fonts, pinned to a
# commit and checked against its SHA-256, into ~/.local/share/fonts.
FONT_COMMIT="bd8f81ddb5c74d5c8897b36ad88b440266245103"
FONT_URL="https://raw.githubusercontent.com/google/fonts/$FONT_COMMIT/ofl/googlesansflex"
FONT_FILE="GoogleSansFlex%5BROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf"
FONT_SHA256="a9ac770798857d5e8ac593ced42b22e40a7c08cec98319f92b0eccc2783a77ba"

find_font() {   # the variable face (it has a width axis), whatever the file is called
    fc-list --format '%{file}|%{variable}\n' 'Google Sans Flex' 2>/dev/null \
        | grep -m1 -i 'googlesansflex.*|true' | cut -d'|' -f1 || true
}

fetch_font() {
    local dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/GoogleSansFlex" tmp
    command -v curl >/dev/null || { echo "warning: curl not found; can't download Google Sans Flex." >&2; return 1; }
    tmp="$(mktemp -d)"
    if ! curl -fsSL -o "$tmp/font.ttf" "$FONT_URL/$FONT_FILE" || ! curl -fsSL -o "$tmp/OFL.txt" "$FONT_URL/OFL.txt"; then
        rm -rf "$tmp"; echo "warning: downloading Google Sans Flex failed." >&2; return 1
    fi
    if [[ "$(sha256sum "$tmp/font.ttf" | cut -d' ' -f1)" != "$FONT_SHA256" ]]; then
        rm -rf "$tmp"; echo "warning: Google Sans Flex download didn't match its checksum; not installed." >&2; return 1
    fi
    mkdir -p "$dir"
    mv "$tmp/font.ttf" "$dir/GoogleSansFlex[ROND,opsz,slnt,wdth,wght].ttf"
    mv "$tmp/OFL.txt" "$dir/OFL.txt"
    rm -rf "$tmp"
    fc-cache -f "$dir" >/dev/null 2>&1 || true
    echo "font: installed Google Sans Flex (OFL 1.1) into $dir"
}

font="$(find_font)"
if [[ -z "$font" ]] && ((download_font)); then
    fetch_font && font="$(find_font)"
    # fc-cache may lag; fall back to the file just installed
    [[ -n "$font" ]] || font="$(ls "${XDG_DATA_HOME:-$HOME/.local/share}"/fonts/GoogleSansFlex/*.ttf 2>/dev/null | head -1 || true)"
fi
if [[ -n "$font" ]]; then
    mkdir -p "$target/fonts"
    cp -f "$font" "$target/fonts/GoogleSansFlex.ttf"
    echo "font: $font"
else
    echo "warning: no Google Sans Flex; the system font is used and the expressive axes fall back to plain weights." >&2
fi

if ((matugen)); then
    add_matugen_block
    render_now
fi

cat <<EOF
installed $MOD_ID ($mode) into
  $profile

Next:
  * Start Zen. Settings > Sine shows "M3 Expressive" with its preferences.
  * Colours from a specific image or colour instead:
      ./install.sh --source ~/Pictures/wall.jpg      (or --source '#rrggbb')
  * Disable SuperPins, MatugenZen and Transparent Zen: this mod replaces them (glass:
    ./install.sh --glass with Zen closed).
  * Live palette reload needs the mod's script; Sine only runs scripts of local mods
    when "sine.allow-unsafe-js" is true. Without it the palette updates on restart.
EOF
