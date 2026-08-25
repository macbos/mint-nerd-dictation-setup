#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$HOME/.local/src/nerd-dictation"
DATA_DIR="$HOME/.local/share/nerd-dictation"
VENV_DIR="$DATA_DIR/venv"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/nerd-dictation"
MODEL_DIR="$CONFIG_DIR/model"
MODEL_NAME="vosk-model-small-nl-0.22"
MODEL_ZIP="$MODEL_NAME.zip"
MODEL_URL="https://alphacephei.com/vosk/models/$MODEL_ZIP"

log() {
    printf '\n==> %s\n' "$1"
}

if [ "${XDG_SESSION_TYPE:-}" != "x11" ]; then
    echo "Waarschuwing: deze installer is bedoeld voor een X11-sessie."
    echo "Huidige sessie: ${XDG_SESSION_TYPE:-onbekend}"
    echo "Wayland gebruikt andere invoersimulatie en wordt hier niet automatisch ingesteld."
    exit 1
fi

log "Systeempakketten installeren"
sudo apt update
sudo apt install -y git python3-venv xdotool unzip wget yad pipewire-bin

if ! command -v pw-cat >/dev/null 2>&1; then
    echo "Fout: pw-cat is niet gevonden na installatie van de vereisten."
    exit 1
fi

mkdir -p "$HOME/.local/src" "$DATA_DIR" "$BIN_DIR" "$CONFIG_DIR"

log "nerd-dictation ophalen of bijwerken"
if [ -d "$SRC_DIR/.git" ]; then
    git -C "$SRC_DIR" pull --ff-only
else
    rm -rf "$SRC_DIR"
    git clone https://github.com/ideasman42/nerd-dictation.git "$SRC_DIR"
fi

log "Python virtual environment voorbereiden"
if [ ! -x "$VENV_DIR/bin/python" ]; then
    python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/pip" install --upgrade "$SRC_DIR/package/python"

log "nerd-dictation command installeren"
ln -sfn "$VENV_DIR/bin/nerd-dictation" "$BIN_DIR/nerd-dictation"

log "Nederlands Vosk-model controleren"
if [ ! -d "$MODEL_DIR/am" ] || [ ! -d "$MODEL_DIR/conf" ] || [ ! -d "$MODEL_DIR/graph" ]; then
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    wget -O "$tmpdir/$MODEL_ZIP" "$MODEL_URL"
    unzip -q "$tmpdir/$MODEL_ZIP" -d "$tmpdir"
    rm -rf "$MODEL_DIR"
    mv "$tmpdir/$MODEL_NAME" "$MODEL_DIR"
    rm -rf "$tmpdir"
    trap - EXIT
else
    echo "Nederlands taalmodel is al aanwezig."
fi

log "Toggle-script en rood microfoonicoon installeren"
install -m 0755 "$REPO_ROOT/bin/dictation-toggle" "$BIN_DIR/dictation-toggle"
install -m 0644 "$REPO_ROOT/assets/microphone-red.svg" "$DATA_DIR/microphone-red.svg"

log "Installatie controleren"
"$BIN_DIR/nerd-dictation" --help >/dev/null
xdotool --version >/dev/null
yad --version >/dev/null
pw-cat --version >/dev/null 2>&1 || true

cat <<EOF

Installatie voltooid.

Geïnstalleerd:
  $BIN_DIR/nerd-dictation
  $BIN_DIR/dictation-toggle
  $DATA_DIR/microphone-red.svg
  $MODEL_DIR

Stel in Cinnamon één aangepaste sneltoets in:
  Naam:     Dictation toggle
  Commando: bash -lc '$HOME/.local/bin/dictation-toggle'
  Toets:    Ctrl+Alt+D

Daarna:
  Ctrl+Alt+D  -> dicteren aan + rode microfoon
  Ctrl+Alt+D  -> dicteren uit + icoon weg
EOF
