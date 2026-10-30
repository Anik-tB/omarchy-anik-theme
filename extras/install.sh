#!/bin/bash

# Install the Anik desktop extras: bar, panels, notifications, OSD, idle,
# screensaver, window look and GTK accent hook. Every file it replaces is
# backed up first, and the backup folder is printed at the end.

set -euo pipefail

EXTRAS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
BACKUP="$CONFIG/omarchy/anik-extras-backup-$(date +%Y%m%d-%H%M%S)"

if ! command -v omarchy >/dev/null; then
  echo "Omarchy not found. These extras only work on Omarchy." >&2
  exit 1
fi

if [[ ${1:-} != "--yes" ]]; then
  echo "This replaces your Omarchy bar layout (shell.json) and ~/.config/hypr/looknfeel.lua,"
  echo "and adds the anik.* shell plugins. Your current files are backed up first."
  read -rp "Continue? [y/N] " answer
  [[ $answer == [yY]* ]] || exit 0
fi

backup() {
  if [[ -e $1 ]]; then
    mkdir -p "$BACKUP/$(dirname "${1#"$HOME"/}")"
    cp -a "$1" "$BACKUP/${1#"$HOME"/}"
  fi
}

echo "Installing shell plugins..."
mkdir -p "$CONFIG/omarchy/plugins"
for plugin in "$EXTRAS"/plugins/anik.*; do
  target="$CONFIG/omarchy/plugins/$(basename "$plugin")"
  backup "$target"
  rm -rf "$target"
  cp -a "$plugin" "$target"
done

echo "Installing bar layout..."
backup "$CONFIG/omarchy/shell.json"
cp "$EXTRAS/shell.json" "$CONFIG/omarchy/shell.json"

echo "Installing window look and feel..."
backup "$CONFIG/hypr/looknfeel.lua"
cp "$EXTRAS/hypr/looknfeel.lua" "$CONFIG/hypr/looknfeel.lua"

echo "Installing screensaver..."
backup "$HOME/.local/bin/anik-screensaver"
backup "$HOME/.local/share/anik-screensaver/run"
install -Dm755 "$EXTRAS/screensaver/anik-screensaver" "$HOME/.local/bin/anik-screensaver"
install -Dm755 "$EXTRAS/screensaver/run" "$HOME/.local/share/anik-screensaver/run"

menu="$CONFIG/omarchy/extensions/omarchy-menu.jsonc"
if [[ -f $menu ]] && ! grep -q '"system.screensaver"' "$menu"; then
  backup "$menu"
  # Insert the entry before the file's closing brace
  sed -i '$!b; s|^}|  // Menu > System > Screensaver runs the Anik screensaver.\n  "system.screensaver": {"icon":"󱄄","label":"Screensaver","action":"$HOME/.local/bin/anik-screensaver force"},\n}|' "$menu"
fi

echo "Installing GTK accent hook..."
omarchy hook install theme-set "$EXTRAS/hooks/anik-gnome-accent.sh" >/dev/null

if ! command -v cava >/dev/null; then
  echo "Note: install cava for the bar's audio visualizer (omarchy pkg add cava)."
fi
if ! fc-list | grep -qi electroharmonix; then
  echo "Note: the bar clock uses the Electroharmonix font (free from Typodermic/DaFont)."
  echo "      Without it the clock falls back to the regular bar font."
fi

hyprctl reload >/dev/null 2>&1 || true
omarchy restart shell

echo
echo "Done. Backups of replaced files: $BACKUP"
echo "To undo: copy them back from that folder, then run: omarchy restart shell"
