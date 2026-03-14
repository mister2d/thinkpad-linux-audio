#!/usr/bin/env python3
"""
generate-enhanced-presets.py

Derives the Z16-* enhanced preset set from the Dolby-* source presets.

What changes vs the Dolby originals:
  - multiband_compressor#1 removed (MI-dependent; causes compression artefacts
    without Dolby's Media Intelligence steering)
  - exciter#0 added (synthetic harmonics above 5.5 kHz; restores perceived
    clarity and air that the Z16 speakers roll off above the IEQ correction range)
  - autogain enabled at -14 LUFS (bypassed in Dolby originals)
  - Voice profiles gain an autogain stage (absent from their Dolby pipeline)
  - limiter gain-boost enabled + 4x oversampling for cleaner peak catching

The convolver, stereo_tools, and equalizer stages are carried over unchanged —
they encode Lenovo's speaker-specific correction and are the reason to use
these presets at all rather than a generic EQ.

Usage:
    python3 scripts/generate-enhanced-presets.py [--dolby-dir PATH] [--out-dir PATH]
"""

import json
import glob
import os
import copy
import argparse

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DEFAULT_DOLBY_DIR = os.path.join(
    REPO_ROOT, "assets", "thinkpad-z16-gen1", "presets", "dolby"
)
DEFAULT_OUT_DIR = os.path.join(
    REPO_ROOT, "assets", "thinkpad-z16-gen1", "presets", "enhanced"
)

# Profiles to skip — blank DAX3 personalization slots with no meaningful tuning
SKIP_PROFILES = {"Personalize_User1", "Personalize_User2", "Personalize_User3"}

# Exciter block — synthetic harmonics above 5.5 kHz.
# Scope 5500 Hz means only content above that frequency gets harmonics added.
# Amount 5.0 is slightly less aggressive than the AAG reference (6.0) because
# the convolver already brings some high-frequency correction.
EXCITER = {
    "bypass": False,
    "input-gain": -2.0,
    "output-gain": 0.0,
    "amount": 5.0,
    "harmonics": 8.0,
    "scope": 5500.0,
    "ceil": 16000.0,
    "ceil-active": False,
    "blend": 0.0,
}

# Autogain block inserted for profiles that lack it (Voice).
# Target -14 LUFS is conservative: close to streaming normalisation standards
# and accounts for the convolver's spectral tilt raising K-weighted LUFS.
# Users can adjust target in the EasyEffects UI if the level feels wrong.
AUTOGAIN_DEFAULT = {
    "bypass": False,
    "input-gain": 0.0,
    "output-gain": 0.0,
    "maximum-history": 15,
    "reference": "Geometric Mean (MSI)",
    "silence-threshold": -70.0,
    "target": -14.0,
}


def parse_profile_and_tone(filename):
    """
    'Dolby-Music-Balanced.json' -> ('Music', 'Balanced')
    'Dolby-Voice_Onlinecourse-Warm.json' -> ('Voice_Onlinecourse', 'Warm')
    """
    stem = os.path.splitext(filename)[0]  # 'Dolby-Music-Balanced'
    parts = stem.split("-", 2)            # ['Dolby', 'Music', 'Balanced']
    if len(parts) != 3:
        return None, None
    return parts[1], parts[2]


def transform(preset, profile):
    """Return a new preset dict with the enhanced pipeline applied."""
    out = copy.deepcopy(preset["output"])
    order = list(out["plugins_order"])

    # ── 1. Remove multiband compressor ────────────────────────────────────────
    order = [p for p in order if "multiband_compressor" not in p]
    for key in [k for k in out if "multiband_compressor" in k]:
        del out[key]

    # ── 2. Ensure autogain is present (Voice profiles lack it) ────────────────
    if "autogain#0" not in order:
        # Insert before limiter
        idx = next(i for i, p in enumerate(order) if p.startswith("limiter"))
        order.insert(idx, "autogain#0")
        out["autogain#0"] = copy.deepcopy(AUTOGAIN_DEFAULT)

    # ── 3. Insert exciter immediately before autogain ─────────────────────────
    idx = order.index("autogain#0")
    order.insert(idx, "exciter#0")
    out["exciter#0"] = copy.deepcopy(EXCITER)

    # ── 4. Configure autogain ─────────────────────────────────────────────────
    ag = out["autogain#0"]
    ag["bypass"] = False
    ag["target"] = -14.0
    ag["maximum-history"] = 15

    # ── 5. Update limiter ─────────────────────────────────────────────────────
    for key in [k for k in out if k.startswith("limiter")]:
        out[key]["gain-boost"] = True
        out[key]["oversampling"] = "Half x4(3L)"

    out["plugins_order"] = order
    return {"output": out}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dolby-dir", default=DEFAULT_DOLBY_DIR)
    parser.add_argument("--out-dir", default=DEFAULT_OUT_DIR)
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    sources = sorted(glob.glob(os.path.join(args.dolby_dir, "Dolby-*.json")))
    if not sources:
        print(f"No Dolby-*.json files found in {args.dolby_dir}")
        return 1

    generated = 0
    skipped = 0

    for src_path in sources:
        fname = os.path.basename(src_path)
        profile, tone = parse_profile_and_tone(fname)
        if profile is None:
            print(f"  skip (unparseable name): {fname}")
            skipped += 1
            continue
        if profile in SKIP_PROFILES:
            print(f"  skip (blank slot):       {fname}")
            skipped += 1
            continue

        with open(src_path) as f:
            dolby = json.load(f)

        enhanced = transform(dolby, profile)

        out_name = f"Z16-{profile}-{tone}.json"
        out_path = os.path.join(args.out_dir, out_name)
        with open(out_path, "w") as f:
            json.dump(enhanced, f, indent=4)

        pipeline = enhanced["output"]["plugins_order"]
        print(f"  {out_name:40s}  {pipeline}")
        generated += 1

    print(f"\n{generated} enhanced presets written to {args.out_dir}")
    print(f"{skipped} skipped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
