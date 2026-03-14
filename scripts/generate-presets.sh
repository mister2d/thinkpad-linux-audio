#!/usr/bin/env bash
# generate-presets.sh
#
# Generate EasyEffects presets from a Lenovo ThinkPad Dolby DAX3 tuning XML.
# Requires: innoextract (to extract the driver), python3, python3-numpy, python3-scipy, git
#
# Usage:
#   bash generate-presets.sh [OPTIONS]
#
# Options:
#   --driver-exe PATH       Path to the Lenovo driver installer (n3ga127w.exe)
#   --driver-dir PATH       Path to an already-extracted driver directory
#                           (use this instead of --driver-exe if you already ran innoextract)
#   --subsystem-id ID       4-digit hex subsystem ID, e.g. 22F2 (without the 17AA prefix)
#                           Run identify-hardware.sh to find yours
#   --output-dir PATH       Where to write the generated presets and IRS files
#                           Default: ./generated/<subsystem-id>/
#   --install               Copy generated files into EasyEffects data directory
#   --ee-data PATH          EasyEffects data directory (default: ~/.local/share/easyeffects)
#   --help                  Show this help

set -euo pipefail

usage() {
    sed -n '/^# Usage:/,/^[^#]/{ /^#/{ s/^# \{0,1\}//; p }; /^[^#]/q }' "$0"
    echo ""
    sed -n '/^# Options:/,/^[^#]/{ /^#/{ s/^# \{0,1\}//; p }; /^[^#]/q }' "$0"
    exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

DRIVER_EXE=""
DRIVER_DIR=""
SUBSYSTEM_ID=""
OUTPUT_DIR=""
INSTALL=0
EE_DATA="${HOME}/.local/share/easyeffects"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --driver-exe)  DRIVER_EXE="$2"; shift 2 ;;
        --driver-dir)  DRIVER_DIR="$2"; shift 2 ;;
        --subsystem-id) SUBSYSTEM_ID="${2^^}"; shift 2 ;;
        --output-dir)  OUTPUT_DIR="$2"; shift 2 ;;
        --install)     INSTALL=1; shift ;;
        --ee-data)     EE_DATA="$2"; shift 2 ;;
        --help|-h)     usage ;;
        *) die "Unknown option: $1" ;;
    esac
done

[[ -z "$SUBSYSTEM_ID" ]] && die "--subsystem-id is required. Run scripts/identify-hardware.sh to find yours."

# Validate subsystem ID format
[[ "$SUBSYSTEM_ID" =~ ^[0-9A-F]{4}$ ]] || \
    die "Subsystem ID must be exactly 4 hex characters, e.g. 22F2 (got: $SUBSYSTEM_ID)"

FULL_SUBSYS="17AA${SUBSYSTEM_ID}"

# ── Check dependencies ────────────────────────────────────────────────────────

check_dep() {
    command -v "$1" &>/dev/null || die "Required tool not found: $1. See docs/reproduce.md for installation instructions."
}

check_dep python3
check_dep git
python3 -c "import numpy, scipy" 2>/dev/null || \
    die "Python packages numpy and scipy are required. Install with: pip install numpy scipy"

# ── Extract driver if needed ──────────────────────────────────────────────────

if [[ -n "$DRIVER_EXE" ]]; then
    check_dep innoextract
    EXTRACT_TMP=$(mktemp -d)
    info "Extracting driver package..."
    innoextract -e "$DRIVER_EXE" -d "$EXTRACT_TMP"
    DRIVER_DIR="$EXTRACT_TMP"
fi

[[ -z "$DRIVER_DIR" ]] && die "Provide either --driver-exe or --driver-dir."
[[ -d "$DRIVER_DIR" ]] || die "Driver directory not found: $DRIVER_DIR"

# ── Locate the DAX3 XML ───────────────────────────────────────────────────────

DAX3_DIR=$(find "$DRIVER_DIR" -type d -name "ext_thinkpad" -path "*/dax3/*" | head -1)
[[ -d "$DAX3_DIR" ]] || die "Could not find Dolby/dax3/ext_thinkpad/ inside $DRIVER_DIR"

# Try exact match first; fall back to glob
XML_FILE=$(find "$DAX3_DIR" -name "DEV_*_SUBSYS_${FULL_SUBSYS}_*.xml" ! -name "*_settings.xml" | head -1)

if [[ -z "$XML_FILE" ]]; then
    info "No exact match for SUBSYS_${FULL_SUBSYS}. Available IDs:"
    find "$DAX3_DIR" -name "DEV_*_SUBSYS_17AA*.xml" ! -name "*_settings.xml" \
        | sed 's/.*SUBSYS_\(17AA[0-9A-Fa-f]*\).*/  \1/' | sort -u
    die "Subsystem ID ${FULL_SUBSYS} not found in driver package."
fi

info "Using DAX3 XML: $(basename "$XML_FILE")"

# ── Clone or locate the converter ────────────────────────────────────────────

CONVERTER_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/speaker-tuning-to-easyeffects"

if [[ ! -d "$CONVERTER_DIR/.git" ]]; then
    info "Cloning antoinecellerier/speaker-tuning-to-easyeffects..."
    git clone --depth=1 https://github.com/antoinecellerier/speaker-tuning-to-easyeffects.git "$CONVERTER_DIR"
else
    info "Using cached converter at $CONVERTER_DIR"
fi

CONVERTER="$CONVERTER_DIR/dolby_to_easyeffects.py"
[[ -f "$CONVERTER" ]] || die "Converter script not found at $CONVERTER"

# ── Generate presets ──────────────────────────────────────────────────────────

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$(pwd)/generated/${FULL_SUBSYS}"
fi

IRS_DIR="${OUTPUT_DIR}/irs"
PRESETS_DIR="${OUTPUT_DIR}/presets"
mkdir -p "$IRS_DIR" "$PRESETS_DIR"

info "Listing available profiles..."
python3 "$CONVERTER" --list "$XML_FILE"

info "Generating all profiles → $OUTPUT_DIR"
python3 "$CONVERTER" \
    --all-profiles \
    --endpoint internal_speaker \
    --output-dir "$PRESETS_DIR/" \
    --irs-dir "$IRS_DIR/" \
    "$XML_FILE"

IRS_COUNT=$(ls "$IRS_DIR"/*.irs 2>/dev/null | wc -l)
PRESET_COUNT=$(ls "$PRESETS_DIR"/*.json 2>/dev/null | wc -l)
info "Generated: ${IRS_COUNT} IRS files, ${PRESET_COUNT} preset files"

# ── Install (optional) ────────────────────────────────────────────────────────

if [[ "$INSTALL" -eq 1 ]]; then
    info "Installing to $EE_DATA"
    mkdir -p "$EE_DATA/irs" "$EE_DATA/output"
    cp "$IRS_DIR/"*.irs "$EE_DATA/irs/"
    cp "$PRESETS_DIR/"*.json "$EE_DATA/output/"
    info "Done. Open EasyEffects and load a Dolby-* preset from the Output presets panel."
fi

info "Complete. To install manually:"
echo "  cp $IRS_DIR/*.irs     ~/.local/share/easyeffects/irs/"
echo "  cp $PRESETS_DIR/*.json ~/.local/share/easyeffects/output/"
