# Usage: Applying Presets on Any Linux Distribution

This guide walks through installing EasyEffects, placing the preset files, and loading a profile. It applies to any Linux distribution running PipeWire.

---

## Prerequisites

### PipeWire

EasyEffects is a PipeWire plugin host. PipeWire has been the default audio server on Fedora since F34 (2021), Ubuntu since 22.10, Debian since Bookworm, Arch since 2021, and most other mainstream distributions around the same period.

To confirm PipeWire is running:

```bash
pactl info | grep "Server Name"
# Expected output contains: PulseAudio (on PipeWire ...)
```

If you are on an older distribution still using PulseAudio, migrating to PipeWire is outside the scope of this guide, but it is strongly recommended — EasyEffects requires it.

### EasyEffects version

These presets target EasyEffects **7.x and later** (released 2022 onward). Version 7 changed the data directory from `~/.config/easyeffects/` to `~/.local/share/easyeffects/` and renamed the convolver field from `kernel-path` to `kernel-name`. The preset files in this repository use the version 7+ format.

To check your installed version:

```bash
easyeffects --version
# or, for the Flatpak:
flatpak run com.github.wwmm.easyeffects --version
```

---

## Installing EasyEffects

### Flatpak (recommended — works on any distribution)

Flatpak is the most reliable way to get a current EasyEffects build regardless of your distribution's package lag.

```bash
# Install Flatpak if not already present (most distributions have it)
# Then add Flathub:
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install EasyEffects:
flatpak install flathub com.github.wwmm.easyeffects
```

Note: The Flatpak version uses its own isolated data directory. Use this path instead of the standard one:

```
~/.var/app/com.github.wwmm.easyeffects/data/easyeffects/
```

The instructions below use `$EE_DATA` as a placeholder. Set it according to your installation:

```bash
# Native package:
export EE_DATA="$HOME/.local/share/easyeffects"

# Flatpak:
export EE_DATA="$HOME/.var/app/com.github.wwmm.easyeffects/data/easyeffects"
```

### Distribution packages

| Distribution | Package name | Command |
|---|---|---|
| Debian / Ubuntu | `easyeffects` | `sudo apt install easyeffects` |
| Fedora | `easyeffects` | `sudo dnf install easyeffects` |
| Arch Linux | `easyeffects` | `sudo pacman -S easyeffects` |
| openSUSE Tumbleweed | `easyeffects` | `sudo zypper install easyeffects` |
| Gentoo | `media-sound/easyeffects` | `emerge --ask media-sound/easyeffects` |
| NixOS | see below | — |

**NixOS:** Add `pkgs.easyeffects` to your packages and enable `services.easyeffects` in your Home Manager configuration. The data directory is managed through `home.file` or `xdg.dataFile` entries pointing to `~/.local/share/easyeffects/`.

---

## Installing the preset files

From the root of this repository:

```bash
# Set your EasyEffects data directory (see above)
export EE_DATA="$HOME/.local/share/easyeffects"   # adjust for Flatpak if needed

# Create directories
mkdir -p "$EE_DATA/irs"
mkdir -p "$EE_DATA/output"

# Copy impulse response files (required by both preset sets)
cp assets/thinkpad-z16-gen1/irs/*.irs "$EE_DATA/irs/"

# Copy the enhanced presets (recommended)
cp assets/thinkpad-z16-gen1/presets/enhanced/*.json "$EE_DATA/output/"

# Optionally also copy the Dolby originals for reference/comparison
# cp assets/thinkpad-z16-gen1/presets/dolby/*.json "$EE_DATA/output/"
```

The IRS files must be in the `irs/` subdirectory. The preset JSON files reference them by filename stem (e.g., `"kernel-name": "Dolby-Music-Balanced"`), and EasyEffects resolves that name relative to its `irs/` directory at runtime. Both the enhanced (`Z16-*`) and Dolby original (`Dolby-*`) presets share the same IRS files.

---

## Loading a preset

1. Launch EasyEffects.
2. In the main window, click the **Output** tab (speaker icon).
3. Click the preset dropdown or the presets button in the top bar.
4. Select `Z16-Music-Balanced` as a starting point.
5. The pipeline activates immediately. You should hear a noticeable difference in bass response, stereo width, and overall tonal balance.

If the preset loads but the Convolver stage shows an error or plays silence, verify that the `.irs` files are in the correct directory and that the filename matches the `kernel-name` value in the JSON. You can inspect it:

```bash
python3 -m json.tool "$EE_DATA/output/Z16-Music-Balanced.json" | grep kernel-name
# Expected: "kernel-name": "Dolby-Music-Balanced"
```

---

## Choosing a preset

**Start with `Z16-Music-Balanced`.** It applies Lenovo's acoustic correction with the enhanced pipeline and neutral tonal balance. Most users will find this the best general-purpose preset.

**Tone variants:**
- `Balanced` — neutral reference, closest to Lenovo's measured target
- `Detailed` — adds emphasis in the upper midrange and treble; useful if you find the speakers dull or recessed
- `Warm` — reduces presence-range brightness; useful if you find the default response harsh or fatiguing

**Profile differences:**
- `Music` — no stereo widening; good for music listening
- `Dynamic` — adds stereo widening via the Stereo Tools stage; good for general desktop use and mixed content
- `Movie` — stereo widening plus dialog enhancement at 2.5 kHz; best for video content
- `Voice` / `Voice_Onlinecourse` — stronger dialog enhancement; best for calls, podcasts, lectures

**Enhanced vs Dolby originals:** The `Z16-*` enhanced presets are recommended for everyday use. The `Dolby-*` originals are useful for comparison or experimentation — on Linux they will sound noticeably more compressed and quieter due to the multiband compressor operating without Dolby's MI engine.

---

## Auto-loading a preset on login

### Using the EasyEffects UI

In EasyEffects preferences, enable **"Launch at system startup"** and set a default output preset. EasyEffects will start as a background service and apply the preset automatically on login.

### Using systemd (native installations)

```bash
# Enable the EasyEffects service for your user
systemctl --user enable easyeffects.service
systemctl --user start easyeffects.service
```

The service file is installed by most distribution packages. If it is not present, create `~/.config/systemd/user/easyeffects.service`:

```ini
[Unit]
Description=EasyEffects audio processing service
After=pipewire.service pipewire-pulse.service

[Service]
ExecStart=/usr/bin/easyeffects --gapplication-service
Restart=on-failure

[Install]
WantedBy=default.target
```

### Using the Flatpak

```bash
# The Flatpak registers an autostart entry when you enable startup in the UI.
# Alternatively, enable the service directly:
systemctl --user enable flatpak-com.github.wwmm.easyeffects.service
```

---

## Verifying the pipeline is active

With EasyEffects running and a preset loaded, the pipeline should appear in the PipeWire graph:

```bash
# List active PipeWire nodes
pw-cli list-objects | grep -i easyeffects

# Or with wpctl
wpctl status | grep -i easyeffects
```

You can also use `helvum` (a graphical PipeWire patchbay) to visualise the signal path: `Application → EasyEffects → Hardware sink`.

---

## Troubleshooting

**Preset loads but sounds identical to no preset:**
Check that EasyEffects is actually connected in the signal path. Some distributions configure PipeWire with a default sink that bypasses EasyEffects. In `wpctl status`, your default sink should be the EasyEffects virtual sink, not the hardware sink directly.

**Convolver stage shows "File not found":**
The `.irs` file referenced in the preset is not in the `irs/` directory. Re-copy the IRS files and confirm the filename matches exactly (case-sensitive on Linux).

**Distortion or clipping on loud content:**
The presets include a brickwall limiter at −1 dBFS. If you are experiencing distortion, check the input level. Some sources send pre-amplified output; reduce the application volume or add an input gain stage before the convolver in the EasyEffects pipeline.

**EasyEffects version 6.x or older:**
The preset files use the `kernel-name` field introduced in EasyEffects 7.x. On version 6.x, you will need to either upgrade or manually edit the JSON files to replace `kernel-name` with `kernel-path` pointing to the absolute path of the IRS file.
