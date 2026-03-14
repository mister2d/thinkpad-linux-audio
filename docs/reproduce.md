# Reproducing the Assets / Generating for Your Model

This guide documents the full pipeline for extracting Dolby DAX3 tuning data from the Lenovo Windows audio driver and converting it to EasyEffects presets. Follow it if you want to:

- Verify the assets in this repository were generated correctly
- Generate presets for a different ThinkPad model covered by the same driver package
- Update the assets after Lenovo releases a new driver version

---

## How to identify your ThinkPad's hardware ID

Every supported ThinkPad has a unique PCI subsystem ID that identifies its audio hardware configuration. You need this to locate the correct DAX3 XML inside the driver package.

```bash
# Show the audio device's PCI subsystem ID
grep -r "" /sys/bus/pci/devices/*/subsystem_vendor /sys/bus/pci/devices/*/subsystem_device 2>/dev/null \
  | paste - - \
  | awk -F: '{print $2, $4}' \
  | while read vendor device; do
      [ "$vendor" = "0x17aa" ] && printf "Lenovo subsystem: 17AA%s\n" "${device#0x}"
    done

# Or more directly, look at the audio codec:
lspci -nnv 2>/dev/null | grep -A5 -i "audio\|multimedia"
```

The subsystem ID will appear in the form `[17aa:XXXX]`. The four hex digits `XXXX` are what you need. You are looking for a subsystem ID in the driver's XML filename pattern `SUBSYS_17AAXXXX`.

Alternatively, use the included identification script:

```bash
bash scripts/identify-hardware.sh
```

---

## Prerequisites

You need the following tools. All are available in standard distribution repositories and in nixpkgs.

| Tool | Purpose | Debian/Ubuntu | Fedora | Arch | Nix |
|---|---|---|---|---|---|
| `innoextract` | Unpack the Inno Setup installer | `apt install innoextract` | `dnf install innoextract` | `pacman -S innoextract` | `nix-shell -p innoextract` |
| `python3` | Run the converter | `apt install python3` | included | included | `nix-shell -p python3` |
| `python3-numpy` | DSP computations | `apt install python3-numpy` | `dnf install python3-numpy` | `pacman -S python-numpy` | `nix-shell -p python3Packages.numpy` |
| `python3-scipy` | FIR filter design | `apt install python3-scipy` | `dnf install python3-scipy` | `pacman -S python-scipy` | `nix-shell -p python3Packages.scipy` |
| `git` | Clone the converter | standard | standard | standard | `nix-shell -p git` |

**NixOS one-liner:**
```bash
nix-shell -p innoextract git python3 python3Packages.numpy python3Packages.scipy
```

---

## Step 1 — Download the Lenovo audio driver

Download the driver package from Lenovo's support site. The package name is `n3ga127w.exe` (driver ID `DS557051`).

Direct navigation: `https://support.lenovo.com/us/en/downloads/ds557051`

The driver covers a large range of ThinkPad models with AMD Ryzen and Intel processors. Download the package once; it contains DAX3 XML files for all supported hardware.

```bash
mkdir -p ~/dolby-extract && cd ~/dolby-extract
# Download using your browser or:
curl -L -o n3ga127w.exe "https://download.lenovo.com/pccbbs/mobiles/n3ga127w.exe"
```

---

## Step 2 — Extract the installer

The `.exe` is an Inno Setup self-extracting archive. `innoextract` unpacks it without running any Windows code.

```bash
cd ~/dolby-extract
innoextract -e n3ga127w.exe -d ./extracted/
```

This produces a directory tree including `extracted/code$GetExtractPath$/Dolby/dax3/ext_thinkpad/` which contains all the per-device DAX3 XML files.

---

## Step 3 — Locate your device's DAX3 XML

```bash
DAX3_DIR="extracted/code\$GetExtractPath\$/Dolby/dax3/ext_thinkpad"

# List all device XMLs (exclude _settings.xml and non-device files):
ls "$DAX3_DIR" | grep -E "^DEV_.*\.xml$" | grep -v "_settings"

# Search for your subsystem ID (replace XXXX with your four hex digits):
ls "$DAX3_DIR" | grep -i "SUBSYS_17AAXXXX"
```

The file you want is named `DEV_YYYY_SUBSYS_17AAXXXX_PCI_SUBSYS_XXXX17AA.xml` where:
- `YYYY` is the codec device ID (e.g., `0287` for ALC287, `0285` for ALC285, `0257` for ALC257)
- `XXXX` is your four-digit subsystem ID

Copy it to your working directory:

```bash
cp "$DAX3_DIR/DEV_0287_SUBSYS_17AAXXXX_PCI_SUBSYS_XXXX17AA.xml" ~/dolby-extract/my-device.xml
```

---

## Step 4 — Clone the converter

```bash
cd ~/dolby-extract
git clone https://github.com/antoinecellerier/speaker-tuning-to-easyeffects.git
```

---

## Step 5 — Inspect available profiles

Before generating, confirm the XML contains data for the `internal_speaker` endpoint:

```bash
python3 speaker-tuning-to-easyeffects/dolby_to_easyeffects.py \
  --list ~/dolby-extract/my-device.xml
```

Expected output:
```
Endpoints and profiles in my-device.xml:
  endpoint: internal_speaker (operating_mode=normal)
    profile: dynamic
    profile: movie
    profile: music
    ...
```

If `internal_speaker` is not listed, the XML may be for a headphone or USB audio device rather than integrated speakers. Check the `ext_thinkpad/` directory for an alternative XML for your subsystem ID.

---

## Step 6 — Generate the presets

```bash
mkdir -p ~/dolby-extract/output ~/dolby-extract/irs

python3 speaker-tuning-to-easyeffects/dolby_to_easyeffects.py \
  --all-profiles \
  --endpoint internal_speaker \
  --output-dir ~/dolby-extract/output/ \
  --irs-dir ~/dolby-extract/irs/ \
  ~/dolby-extract/my-device.xml
```

Successful output lists each generated file. The `output/` directory will contain one `.json` file per profile × tone variant, and `irs/` will contain the corresponding `.irs` impulse response files.

---

## Automated script

The repository includes `scripts/generate-presets.sh` which automates steps 2–6 given the extracted driver directory and your subsystem ID:

```bash
bash scripts/generate-presets.sh \
  --driver-dir ~/dolby-extract/extracted \
  --subsystem-id 17AA22F2 \
  --output-dir ~/my-presets
```

Run `bash scripts/generate-presets.sh --help` for full usage.

---

## Verifying output against the repository

If you are regenerating for the Z16 Gen 1 (`17AA22F2`) to verify the assets in this repository, the generated IRS files should be byte-identical to those committed in `assets/thinkpad-z16-gen1/irs/`, because the converter is deterministic given the same input XML.

```bash
diff <(sha256sum ~/dolby-extract/irs/Dolby-Music-Balanced.irs | awk '{print $1}') \
     <(sha256sum assets/thinkpad-z16-gen1/irs/Dolby-Music-Balanced.irs | awk '{print $1}')
# No output = files are identical
```

---

## Notes on driver package versions

Lenovo periodically releases updated audio driver packages. New versions may contain revised DAX3 tuning XML files with adjusted filter coefficients. When Lenovo releases a new version, users should regenerate the assets using the new XML and verify the output before deploying. The source XML committed to this repository corresponds to driver version `6.0.9499.1` (package `n3ga127w.exe`). The tuning version embedded in the Z16 XML is `43`, dated `03/02/2022`.
