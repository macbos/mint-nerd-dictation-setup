#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
DATA_DIR="$HOME/.local/share/nerd-dictation"
CONFIG_DIR="$HOME/.config/nerd-dictation"
SRC_DIR="$HOME/.local/src/nerd-dictation"
RUNDIR="${XDG_RUNTIME_DIR:-/tmp}"

if [ -x "$BIN_DIR/nerd-dictation" ]; then
    "$BIN_DIR/nerd-dictation" end >/dev/null 2>&1 || true
fi

for file in "$RUNDIR/nerd-dictation.pid" "$RUNDIR/nerd-dictation-tray.pid"; do
    if [ -f "$file" ]; then
        pid="$(cat "$file")"
        kill "$pid" 2>/dev/null || true
        rm -f "$file"
    fi
done

rm -f "$BIN_DIR/dictation-toggle"
rm -f "$BIN_DIR/nerd-dictation"
rm -rf "$DATA_DIR"
rm -rf "$CONFIG_DIR"
rm -rf "$SRC_DIR"

echo "Mint nerd-dictation setup is verwijderd."
echo "De algemene systeempakketten (git, xdotool, yad, enz.) zijn behouden."
echo "Verwijder eventueel ook handmatig de Cinnamon-sneltoets."
