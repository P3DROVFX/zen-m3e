#!/usr/bin/env bash
# Install M3 Expressive into a Zen profile that uses Sine, and hook it into matugen.
#
#   ./install.sh                 symlink this repo into the default Zen profile
#   ./install.sh --copy          copy instead of symlink
#   ./install.sh --profile DIR   pick the profile explicitly
#   ./install.sh --no-matugen    skip the matugen template
#   ./install.sh --no-font-download
#                                don't fetch Google Sans Flex when it isn't installed
#   ./install.sh --source SRC    first palette from an image or a #hex colour (default:
#                                the ii shell's current colour, if there is one)
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
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

die() { echo "error: $*" >&2; exit 1; }

# ---------------------------------------------------------------- profile
if [[ -z "$profile" ]]; then
    # Native builds keep profiles in ~/.zen; the Flatpak in its sandbox.
    for zen_root in "$HOME/.zen" "$HOME/.var/app/app.zen_browser.zen/.zen"; do
        [[ -f "$zen_root/installs.ini" ]] && break
    done
    [[ -f "$zen_root/installs.ini" ]] || die "no Zen profiles found (use --profile DIR)"
    rel="$(grep -m1 '^Default=' "$zen_root/installs.ini" | cut -d= -f2-)"
    profile="$zen_root/$rel"
fi
[[ -d "$profile/chrome/sine-mods" ]] || die "$profile has no chrome/sine-mods (is Sine installed?)"
mods_dir="$profile/chrome/sine-mods"
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

# First palette now, without re-running the user's whole matugen config. Source: --source
# (an image or a #hex), else the ii shell's current colour; otherwise colors.css is
# written the next time the user runs matugen.
render_now() {
    local src="$source" mode tmp
    [[ -n "$src" ]] || src="$(cat "$HOME/.local/state/quickshell/user/generated/color.txt" 2>/dev/null || true)"
    if [[ -z "$src" ]]; then
        echo "note: no --source given; colors.css appears the next time you run matugen."
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
    echo "palette: $src ($mode) -> $target/colors.css"
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
  * Disable MatugenZen and Transparent Zen: this mod replaces both (it has its own
    matugen palette and a "translucent surfaces" option).
  * Live palette reload needs the mod's script; Sine only runs scripts of local mods
    when "sine.allow-unsafe-js" is true. Without it the palette updates on restart.
EOF
