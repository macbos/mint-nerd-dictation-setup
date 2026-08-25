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

ok() {
    printf '  [OK] %s\n' "$1"
}

fail() {
    printf '  [FOUT] %s\n' "$1" >&2
    exit 1
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

command -v git >/dev/null 2>&1 && ok "git gevonden" || fail "git ontbreekt"
command -v xdotool >/dev/null 2>&1 && ok "xdotool gevonden" || fail "xdotool ontbreekt"
command -v yad >/dev/null 2>&1 && ok "yad gevonden" || fail "yad ontbreekt"
command -v pw-cat >/dev/null 2>&1 && ok "pw-cat gevonden" || fail "pw-cat ontbreekt"

[ -x "$BIN_DIR/nerd-dictation" ] && ok "nerd-dictation is uitvoerbaar" || fail "nerd-dictation ontbreekt"
[ -x "$BIN_DIR/dictation-toggle" ] && ok "dictation-toggle is uitvoerbaar" || fail "dictation-toggle ontbreekt"
[ -f "$DATA_DIR/microphone-red.svg" ] && ok "rood microfoonicoon gevonden" || fail "microfoonicoon ontbreekt"

if [ -d "$MODEL_DIR/am" ] && [ -d "$MODEL_DIR/conf" ] && [ -d "$MODEL_DIR/graph" ]; then
    ok "Nederlands Vosk-model gevonden"
else
    fail "Nederlands Vosk-model is onvolledig"
fi

"$VENV_DIR/bin/python" -c 'import vosk' >/dev/null 2>&1 \
    && ok "Python kan Vosk importeren" \
    || fail "Vosk kan niet worden geïmporteerd"

"$BIN_DIR/nerd-dictation" --help >/dev/null 2>&1 \
    && ok "nerd-dictation start correct" \
    || fail "nerd-dictation start niet correct"

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
