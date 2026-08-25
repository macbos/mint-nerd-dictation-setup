# Mint nerd-dictation setup

A small installer and desktop integration for [nerd-dictation](https://github.com/ideasman42/nerd-dictation) on Linux Mint/Cinnamon.

This setup installs nerd-dictation in an isolated Python virtual environment, downloads the Dutch Vosk model, adds a one-key dictation toggle, and shows a red microphone in the system tray while dictation is active.

## What this installs

- `nerd-dictation` from the official upstream repository
- Vosk in a private Python virtual environment
- Dutch model `vosk-model-small-nl-0.22`
- PipeWire audio input via `pw-cat`
- X11 typing via `xdotool`
- A `dictation-toggle` command
- A theme-independent red microphone tray icon via `yad`
- Optionally a Cinnamon shortcut on `Ctrl+Alt+D`

The system Python installation is not modified with `pip`.

## Tested environment

This setup is intended for Linux Mint 22.x with Cinnamon on X11 and Python 3.12. It may work on closely related Ubuntu-based distributions, but those are not the primary target.

Check your session with:

```bash
echo "$XDG_SESSION_TYPE"
```

The expected result is `x11`.

## Install

Clone this repository and run the installer:

```bash
git clone https://github.com/macbos/mint-nerd-dictation-setup.git
cd mint-nerd-dictation-setup
bash install.sh
```

The installer is designed to be safe to run again. Existing correct components are reused and the upstream nerd-dictation checkout is updated when possible.

Near the end, the installer asks:

```text
Wil je Ctrl+Alt+D automatisch instellen als dicteersneltoets? [j/N]
```

Choose `j` to let the installer configure the Cinnamon shortcut. Existing custom shortcuts are preserved. If `Ctrl+Alt+D` is already used by another custom shortcut, nothing is overwritten and the installer tells you to resolve the conflict manually.

If an existing custom shortcut already runs this setup's `dictation-toggle`, the installer reuses that entry instead of adding a duplicate.

## Manual Cinnamon shortcut setup

If you choose not to configure it automatically, open:

**System Settings → Keyboard → Shortcuts → Custom Shortcuts**

Create one shortcut:

- Name: `Dictation toggle`
- Command: `~/.local/bin/dictation-toggle`
- Shortcut: `Ctrl+Alt+D`

## Usage

1. Place the cursor in a text field.
2. Press `Ctrl+Alt+D` to start dictation.
3. A red microphone appears in the system tray.
4. Speak normally.
5. Press `Ctrl+Alt+D` again to stop dictation.
6. The tray icon disappears.

## Files installed in your home directory

```text
~/.local/src/nerd-dictation/
~/.local/share/nerd-dictation/venv/
~/.local/share/nerd-dictation/microphone-red.svg
~/.local/bin/nerd-dictation
~/.local/bin/dictation-toggle
~/.config/nerd-dictation/model/
```

## Updating

Pull the latest version of this repository and run the installer again:

```bash
git pull
bash install.sh
```

The installer also attempts a fast-forward update of the upstream nerd-dictation checkout.

## Uninstall

Run:

```bash
bash uninstall.sh
```

By default this removes the files installed by this setup, including the downloaded Dutch language model and the local nerd-dictation checkout. It does not remove general system packages such as `git`, `xdotool`, or `yad`.

## Notes

- `nerd-dictation` is a separate upstream project and has its own license.
- Vosk and the Vosk language models are separate projects with their own licenses.
- This repository only contains the installation/integration scripts and the tray icon used around those projects.
- Wayland is deliberately not configured by this installer because the input simulation setup is different from X11.

## License

The original scripts and SVG icon in this repository are licensed under the MIT License. See [LICENSE](LICENSE).
