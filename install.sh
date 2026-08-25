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

SHORTCUT_SCHEMA="org.cinnamon.desktop.keybindings"
SHORTCUT_ITEM_SCHEMA="org.cinnamon.desktop.keybindings.custom-keybinding"
SHORTCUT_NAME="Nerd Dictation Toggle"
SHORTCUT_COMMAND="$BIN_DIR/dictation-toggle"
SHORTCUT_BINDING="<Primary><Alt>d"
SHORTCUT_STATUS="manual"

log() {
    printf '\n==> %s\n' "$1"
}

ok() {
    printf '  [OK] %s\n' "$1"
}

warn() {
    printf '  [LET OP] %s\n' "$1"
}

fail() {
    printf '  [FOUT] %s\n' "$1" >&2
    exit 1
}

get_gsettings_string() {
    local schema_path="$1"
    local key="$2"
    local raw

    raw="$(gsettings get "$schema_path" "$key" 2>/dev/null || printf "''")"
    python3 - "$raw" <<'PY'
import ast
import sys

try:
    value = ast.literal_eval(sys.argv[1])
except Exception:
    value = ""
print(value)
PY
}

read_custom_shortcut_ids() {
    local raw
    raw="$(gsettings get "$SHORTCUT_SCHEMA" custom-list 2>/dev/null || printf '[]')"
    python3 - "$raw" <<'PY'
import ast
import sys

raw = sys.argv[1].strip()
if raw.startswith("@as "):
    raw = raw[4:]
try:
    values = ast.literal_eval(raw)
except Exception:
    values = []
for value in values:
    print(value)
PY
}

write_custom_shortcut_list() {
    local value
    value="$(python3 - "$@" <<'PY'
import sys
print(repr(sys.argv[1:]))
PY
)"
    gsettings set "$SHORTCUT_SCHEMA" custom-list "$value"
}

configure_cinnamon_shortcut() {
    local answer=""
    local id path command binding_raw
    local our_id=""
    local conflict_id=""
    local new_id=""
    local index
    local -a custom_ids=()

    if ! command -v gsettings >/dev/null 2>&1; then
        warn "gsettings is niet beschikbaar; stel Ctrl+Alt+D handmatig in."
        return
    fi

    if ! gsettings list-schemas | grep -qx "$SHORTCUT_SCHEMA"; then
        warn "Cinnamon-sneltoetsenschema is niet gevonden; stel Ctrl+Alt+D handmatig in."
        return
    fi

    if ! gsettings list-schemas | grep -qx "$SHORTCUT_ITEM_SCHEMA"; then
        warn "Cinnamon custom-keybinding-schema is niet gevonden; stel Ctrl+Alt+D handmatig in."
        return
    fi

    if [ ! -t 0 ]; then
        warn "Geen interactieve terminal; automatische sneltoetsconfiguratie wordt overgeslagen."
        return
    fi

    printf '\nWil je Ctrl+Alt+D automatisch instellen als dicteersneltoets? [j/N] '
    if ! read -r answer; then
        answer=""
    fi

    case "${answer,,}" in
        j|ja|y|yes)
            ;;
        *)
            echo "Sneltoets niet automatisch aangepast."
            return
            ;;
    esac

    mapfile -t custom_ids < <(read_custom_shortcut_ids)

    for id in "${custom_ids[@]}"; do
        path="/org/cinnamon/desktop/keybindings/custom-keybindings/$id/"
        command="$(get_gsettings_string "$SHORTCUT_ITEM_SCHEMA:$path" command)"
        binding_raw="$(gsettings get "$SHORTCUT_ITEM_SCHEMA:$path" binding 2>/dev/null || printf '[]')"

        if [[ "$command" == *"$SHORTCUT_COMMAND"* ]]; then
            our_id="$id"
            continue
        fi

        if [[ "$binding_raw" == *"$SHORTCUT_BINDING"* ]] || \
           [[ "$binding_raw" == *"<Control><Alt>d"* ]] || \
           [[ "$binding_raw" == *"<Primary><Alt>D"* ]]; then
            conflict_id="$id"
        fi
    done

    if [ -n "$conflict_id" ]; then
        warn "Ctrl+Alt+D is al gekoppeld aan een andere aangepaste sneltoets ($conflict_id)."
        warn "Er is niets overschreven. Kies handmatig een andere toets of verwijder het conflict."
        return
    fi

    if [ -n "$our_id" ]; then
        new_id="$our_id"
        echo "Bestaande nerd-dictation-sneltoets gevonden: $new_id"
    else
        index=0
        while :; do
            new_id="custom$index"
            if [[ ! " ${custom_ids[*]} " =~ [[:space:]]${new_id}[[:space:]] ]]; then
                break
            fi
            index=$((index + 1))
        done
    fi

    path="/org/cinnamon/desktop/keybindings/custom-keybindings/$new_id/"
    gsettings set "$SHORTCUT_ITEM_SCHEMA:$path" name "$SHORTCUT_NAME"
    gsettings set "$SHORTCUT_ITEM_SCHEMA:$path" command "$SHORTCUT_COMMAND"
    gsettings set "$SHORTCUT_ITEM_SCHEMA:$path" binding "['$SHORTCUT_BINDING']"

    if [ -z "$our_id" ]; then
        custom_ids+=("$new_id")
        write_custom_shortcut_list "${custom_ids[@]}"
    fi

    SHORTCUT_STATUS="automatic"
    ok "Ctrl+Alt+D is ingesteld voor nerd-dictation"
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

log "Cinnamon-sneltoets"
configure_cinnamon_shortcut

cat <<EOF

Installatie voltooid.

Geïnstalleerd:
  $BIN_DIR/nerd-dictation
  $BIN_DIR/dictation-toggle
  $DATA_DIR/microphone-red.svg
  $MODEL_DIR
EOF

if [ "$SHORTCUT_STATUS" = "automatic" ]; then
    cat <<EOF

Sneltoets:
  Ctrl+Alt+D is automatisch ingesteld.
EOF
else
    cat <<EOF

Sneltoets handmatig instellen in Cinnamon:
  Naam:     Dictation toggle
  Commando: $BIN_DIR/dictation-toggle
  Toets:    Ctrl+Alt+D
EOF
fi

cat <<'EOF'

Gebruik:
  Ctrl+Alt+D  -> dicteren aan + rode microfoon
  Ctrl+Alt+D  -> dicteren uit + icoon weg
EOF
