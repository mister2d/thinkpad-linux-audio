# thinkpad-linux-audio

Dolby DAX3 speaker tuning for Lenovo ThinkPad laptops, extracted from Lenovo's official Windows audio driver and converted to [EasyEffects](https://github.com/wwmm/easyeffects) presets for use on any Linux distribution. Pre-generated assets are provided for the ThinkPad Z16 Gen 1; the pipeline works for all models covered by the same driver package.

---

## The problem in one paragraph

Lenovo's acoustic engineers, working with Dolby, design custom digital signal processing (DSP) filters for each ThinkPad model. These filters compensate for the physical limitations of the laptop's speaker enclosure — correcting the frequency response, applying compression and limiting to protect the drivers, and adding speaker virtualization for certain listening modes. On Windows, this DSP chain runs transparently inside the Realtek audio driver as *Dolby DAX3*. On Linux, PipeWire and ALSA route audio directly to the hardware. The speakers function correctly, but without the acoustic compensation they were designed to need. The result is audio that is measurably and audibly different from what Lenovo intended for the hardware.

This repository provides pre-converted EasyEffects presets for the Z16 Gen 1 so that Linux users get the same speaker tuning that ships with the machine.

---

## Quick start — ThinkPad Z16 Gen 1

**Prerequisites:** PipeWire (standard on most distributions since 2022), EasyEffects 7.x or later.

See [docs/usage.md](docs/usage.md) for full installation instructions across distributions. The short version:

```bash
# 1. Install EasyEffects (Flatpak, works on any distro)
flatpak install flathub com.github.wwmm.easyeffects

# 2. Create the EasyEffects data directories
mkdir -p ~/.local/share/easyeffects/irs
mkdir -p ~/.local/share/easyeffects/output

# 3. Copy assets
cp assets/thinkpad-z16-gen1/irs/*.irs ~/.local/share/easyeffects/irs/
cp assets/thinkpad-z16-gen1/presets/*.json ~/.local/share/easyeffects/output/

# 4. Launch EasyEffects, open the Output presets panel, and load:
#    Dolby-Music-Balanced   (recommended starting point)
```

---

## Available presets

Each preset is a full 8-stage EasyEffects output pipeline derived from Lenovo's DAX3 tuning data. Profiles come from the Dolby DAX3 spec; the three tone variants (Balanced / Detailed / Warm) reflect different IEQ (Intelligent EQ) target curves tuned for the Z16's speaker array.

| Preset file | Dolby profile | Tone variant | Notes |
|---|---|---|---|
| `Dolby-Music-Balanced` | Music | Balanced | **Recommended default** |
| `Dolby-Music-Detailed` | Music | Detailed | Brighter high-frequency emphasis |
| `Dolby-Music-Warm` | Music | Warm | Reduced highs, fuller low-mids |
| `Dolby-Dynamic-Balanced` | Dynamic | Balanced | Adds stereo widening; good for mixed content |
| `Dolby-Dynamic-Detailed` | Dynamic | Detailed | |
| `Dolby-Dynamic-Warm` | Dynamic | Warm | |
| `Dolby-Movie-Balanced` | Movie | Balanced | Dialog enhancement + surround widening |
| `Dolby-Movie-Detailed` | Movie | Detailed | |
| `Dolby-Movie-Warm` | Movie | Warm | |
| `Dolby-Game-Balanced` | Game | Balanced | |
| `Dolby-Game-Detailed` | Game | Detailed | |
| `Dolby-Game-Warm` | Game | Warm | |
| `Dolby-Voice-Balanced` | Voice | Balanced | Speech intelligibility boost |
| `Dolby-Voice-Detailed` | Voice | Detailed | |
| `Dolby-Voice-Warm` | Voice | Warm | |
| `Dolby-Voice_Onlinecourse-*` | Voice (lecture) | All three | Optimised for spoken-word content |
| `Dolby-Personalize_User1/2/3-*` | User presets | All three | Blank personalization slots from DAX3 |

---

## Pipeline stages

The DSP pipeline in these presets directly mirrors what Dolby DAX3 applies on Windows:

| Stage | What it does |
|---|---|
| **Convolver** | FIR impulse response encoding the IEQ target curve + audio-optimizer speaker correction |
| **Stereo Tools** | Surround widening (Dynamic and Movie profiles only) |
| **Equalizer** | 100 Hz 4th-order high-pass filter + per-speaker parametric EQ |
| **Autogain** | EBU R128 volume leveler (preserved but bypassed by default — see [docs/background.md](docs/background.md#autogain)) |
| **Multiband Compressor** | Frequency-band dynamics control decoded from Dolby's DSP coefficients |
| **Regulator** | Per-band limiter derived from Dolby `threshold_high` values |
| **Limiter** | Brickwall at −1 dBFS |

---

## Other ThinkPad models

The Lenovo audio driver package that contains the Z16 tuning data also covers a large number of other ThinkPad models. This repository ships pre-generated assets for the Z16 Gen 1 only because that is the hardware on which the output has been directly verified. However, the full generation pipeline is documented and scripted for any model covered by the same driver package.

If you have a different ThinkPad model: see [docs/reproduce.md](docs/reproduce.md) and [scripts/generate-presets.sh](scripts/generate-presets.sh).

---

## Documentation

| Document | Contents |
|---|---|
| [docs/background.md](docs/background.md) | Why laptop audio needs DSP, what DAX3 is, how the conversion works |
| [docs/usage.md](docs/usage.md) | Installing EasyEffects and applying presets on any Linux distribution |
| [docs/reproduce.md](docs/reproduce.md) | Regenerating assets from the Lenovo driver package for any supported model |
| [HARDWARE.md](HARDWARE.md) | Supported hardware, subsystem IDs, how to identify your model |

---

## Asset provenance

The `.irs` and `.json` files in `assets/` are computed from `DEV_0287_SUBSYS_17AA22F2_PCI_SUBSYS_22F217AA.xml`, which is Lenovo's official Dolby DAX3 tuning file for the ThinkPad Z16 Gen 1. This XML is distributed by Lenovo inside the signed Windows audio driver package `n3ga127w.exe`, available from Lenovo's support site. It is included here for transparency and reproducibility verification.

The conversion was performed with [antoinecellerier/speaker-tuning-to-easyeffects](https://github.com/antoinecellerier/speaker-tuning-to-easyeffects). The scripts and documentation in this repository are MIT-licensed. The derived audio assets carry Lenovo's original distribution terms; they are provided here under the same basis as binary firmware files distributed by the linux-firmware project — sourced from the vendor, redistributed for hardware compatibility.
