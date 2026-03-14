# Supported Hardware

---

## Pre-generated assets

Pre-generated EasyEffects presets are provided for the following hardware. These have been directly tested and verified.

| Model | Machine types | PCI subsystem ID | Codec | Assets |
|---|---|---|---|---|
| ThinkPad Z16 Gen 1 | 21D4, 21D5 | `17AA22F2` | ALC287 (DEV_0287) | `assets/thinkpad-z16-gen1/` |

---

## Additional models in the driver package

The Lenovo audio driver package (`n3ga127w.exe`, driver ID `DS557051`) contains DAX3 tuning XML files for a large number of additional ThinkPad models. Pre-generated assets are not included for these in the repository, but generating them follows the same process documented in [docs/reproduce.md](docs/reproduce.md).

The full list of subsystem IDs present in the driver package is below. Use [scripts/generate-presets.sh](scripts/generate-presets.sh) to generate presets for your hardware once you have identified your subsystem ID.

### How to find your subsystem ID

```bash
bash scripts/identify-hardware.sh
```

Or manually:

```bash
# Show all Lenovo PCI subsystem IDs on your system:
for f in /sys/bus/pci/devices/*/subsystem_vendor; do
  vendor=$(cat "$f")
  device=$(cat "${f%_vendor}_device")
  [ "$vendor" = "0x17aa" ] && echo "17AA${device#0x00}"
done
```

Match the result against the tables below. If your ID appears, your device has a DAX3 tuning file in the driver package and presets can be generated for it.

---

### Newer AMD ThinkPads — ALC287 (DEV_0287)

These are AMD Ryzen–based ThinkPads introduced from approximately 2022 onward.

| PCI subsystem ID | Notes |
|---|---|
| `17AA22F2` | ThinkPad Z16 Gen 1 — **pre-generated, verified** |
| `17AA22F1` | ThinkPad Z16 Gen 1 variant |
| `17AA22F3` | |
| `17AA22F8` | |
| `17AA22F9` | |
| `17AA22FA` | |
| `17AA22FB` | |
| `17AA22FC` | |
| `17AA22C6` | |
| `17AA22C7` | |
| `17AA22D4` | |
| `17AA22D5` | |
| `17AA22D8` | |
| `17AA22DE` | |
| `17AA22E1` | |
| `17AA22E4` | |
| `17AA22E5` | |
| `17AA22E6` | |
| `17AA22E7` | |
| `17AA2234` | |
| `17AA2304` | |
| `17AA2314` | |
| `17AA2315` | |
| `17AA2316` | |
| `17AA2317` | |
| `17AA2318` | |
| `17AA2319` | |
| `17AA231A` | |
| `17AA231B` | |
| `17AA231E` | |
| `17AA231F` | |
| `17AA2326` | |
| `17AA2340` | |
| `17AA2341` | |
| `17AA3809` | |
| `17AA508B` | |
| `17AA50B0` | |

### Older AMD ThinkPads — ALC285 (DEV_0285)

| PCI subsystem ID | Notes |
|---|---|
| `17AA2292` | |
| `17AA2293` | |
| `17AA229D` | |
| `17AA22B8` | |
| `17AA22BB` | |
| `17AA22BE` | |
| `17AA22BF` | |
| `17AA22C0` | |
| `17AA22C1` | |
| `17AA22C2` | |
| `17AA22C3` | |
| `17AA22D6` | |
| `17AA22D8` | |
| `17AA22DE` | |
| `17AA22E1` | |
| `17AA7403` | |

### Intel-era ThinkPads — ALC257 (DEV_0257)

The driver package also includes DAX3 tuning for a large number of Intel HDA codec–based ThinkPads. These span multiple generations of T, X, L, E, and IdeaPad series. The full list of subsystem IDs is available by running:

```bash
ls extracted/code\$GetExtractPath\$/Dolby/dax3/ext_thinkpad/DEV_0257_*.xml | \
  sed 's/.*SUBSYS_\(17AA[^_]*\).*/\1/' | sort -u
```

after extracting the driver package per [docs/reproduce.md](docs/reproduce.md).

---

## Contributing model name mappings

If you know the ThinkPad model name that corresponds to a subsystem ID listed above, please open a pull request updating this table. Include the machine type (e.g., "21D4") or the Lenovo PSREF page URL as a reference. Model names without a verifiable source will not be merged.

The most reliable mapping source is the Linux kernel's `sound/pci/hda/patch_realtek.c`, which contains `SND_PCI_QUIRK` entries mapping subsystem IDs to model-specific quirks and can be cross-referenced with ThinkPad machine types documented in Lenovo's PSREF.
