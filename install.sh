#!/usr/bin/env bash
# Install M3 Expressive into a Zen profile that uses Sine, and hook it into matugen.
#
#   ./install.sh                 symlink this repo into the default Zen profile
#   ./install.sh --copy          copy instead of symlink
#   ./install.sh --profile DIR   pick the profile explicitly
#   ./install.sh --no-matugen    skip the matugen template
#   ./install.sh --uninstall     remove the mod and the matugen template block
#
# Close Zen first: Sine rewrites mods.json while it runs.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ID="m3-expressive"
MATUGEN_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml"
MARK_BEGIN="# >>> zen-m3e >>>"
MARK_END="# <<< zen-m3e <<<"

mode=symlink profile="" matugen=1 uninstall=0
while (($#)); do
    case "$1" in
        --copy) mode=copy ;;
        --profile) profile="$2"; shift ;;
        --no-matugen) matugen=0 ;;
        --uninstall) uninstall=1 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

die() { echo "error: $*" >&2; exit 1; }

# ---------------------------------------------------------------- profile
if [[ -z "$profile" ]]; then
    zen_root="$HOME/.zen"
    [[ -f "$zen_root/installs.ini" ]] || die "no Zen profiles in $zen_root (use --profile)"
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
    [[ -f "$MATUGEN_CFG" ]] || die "no matugen config at $MATUGEN_CFG (use --no-matugen)"
    cp "$MATUGEN_CFG" "$MATUGEN_CFG.bak-zen-m3e"
    remove_matugen_block
    cat >>"$MATUGEN_CFG" <<EOF

$MARK_BEGIN
[templates.zen-m3e]
input_path = '$REPO/matugen/zen-m3e.css'
output_path = '$target/colors.css'
$MARK_END
EOF
}

# First palette now, from the shell's current source colour, without re-running the
# user's whole matugen config.
render_now() {
    local src mode tmp
    src="$(cat "$HOME/.local/state/quickshell/user/generated/color.txt" 2>/dev/null || true)"
    [[ "$src" =~ ^#[0-9A-Fa-f]{6}$ ]] || { echo "note: no shell source colour; colors.css is written on the next wallpaper change."; return 0; }
    mode=dark
    [[ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" == *light* ]] && mode=light
    tmp="$(mktemp -d)"
    printf "[config]\n[templates.m3e]\ninput_path = '%s'\noutput_path = '%s'\n" \
        "$REPO/matugen/zen-m3e.css" "$target/colors.css" >"$tmp/config.toml"
    matugen color hex "$src" -c "$tmp/config.toml" -m "$mode" -q
    rm -rf "$tmp"
    echo "palette: $src ($mode) -> $target/colors.css"
}

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
    cp -r "$REPO"/{theme.json,preferences.json,chrome.css,m3e.uc.js,README.md} "$target"/
fi
edit_mods_json add

# Google Sans Flex next to chrome.css: Gecko only honours the variable axes
# (font-variation-settings) for a face loaded through @font-face.
font="$(fc-list --format '%{file}\n' 'Google Sans Flex' 2>/dev/null | grep -i 'GoogleSansFlex-VariableFont' | head -1)"
if [[ -n "$font" ]]; then
    mkdir -p "$target/fonts"
    cp -f "$font" "$target/fonts/GoogleSansFlex.ttf"
    echo "font: $font"
else
    echo "warning: Google Sans Flex (variable) not found; expressive axes fall back to plain weights." >&2
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
