#!/usr/bin/env bash
# identify-hardware.sh
#
# Identify the Lenovo PCI audio subsystem ID for the current machine.
# This ID is used to locate the correct DAX3 tuning XML in the Lenovo driver package.
#
# Usage: bash scripts/identify-hardware.sh

set -euo pipefail

echo "Searching for Lenovo audio hardware..."
echo ""

found=0

# Method 1: Walk PCI sysfs, look for audio class devices with Lenovo subsystem vendor
for dev in /sys/bus/pci/devices/*; do
    class_file="$dev/class"
    subvendor_file="$dev/subsystem_vendor"
    subdevice_file="$dev/subsystem_device"

    [[ -f "$class_file" && -f "$subvendor_file" && -f "$subdevice_file" ]] || continue

    class=$(cat "$class_file" 2>/dev/null)
    subvendor=$(cat "$subvendor_file" 2>/dev/null)

    # PCI class 0x0403 = Multimedia Audio Controller, 0x0401 = Multimedia Audio Device
    # Lenovo subsystem vendor = 0x17aa
    if [[ ("$class" == "0x000403" || "$class" == "0x000401" || "$class" == "0x040300" || "$class" == "0x040100") && "$subvendor" == "0x17aa" ]]; then
        subdevice=$(cat "$subdevice_file" 2>/dev/null)
        vendor_file="$dev/vendor"
        device_file="$dev/device"
        vendor=$(cat "$vendor_file" 2>/dev/null)
        device=$(cat "$device_file" 2>/dev/null)

        # Format the subsystem device ID as uppercase 4-digit hex without 0x prefix
        subsys_id=$(printf "%04X" "$((subdevice))")
        full_id="17AA${subsys_id}"

        echo "Found audio device:"
        echo "  PCI device:        ${vendor}:${device}"
        echo "  Subsystem ID:      ${subvendor}:${subdevice}"
        echo "  Lenovo SSID:       ${full_id}"
        echo ""
        echo "Use this with generate-presets.sh:"
        echo "  bash scripts/generate-presets.sh --driver-exe n3ga127w.exe --subsystem-id ${subsys_id}"
        echo ""
        found=1
    fi
done

# Method 2: lspci fallback
if [[ "$found" -eq 0 ]]; then
    if command -v lspci &>/dev/null; then
        echo "Falling back to lspci output. Look for lines with [17aa:XXXX] in the subsystem field."
        echo ""
        lspci -nnv 2>/dev/null | grep -A10 -i "audio\|multimedia" | grep -i "subsystem\|17aa" || true
        echo ""
        echo "The four hex digits after '17aa:' are your subsystem ID."
        echo "Use them with: bash scripts/generate-presets.sh --driver-exe n3ga127w.exe --subsystem-id XXXX"
    else
        echo "Could not identify audio hardware automatically."
        echo ""
        echo "Install 'pciutils' for lspci, or check:"
        echo "  cat /sys/bus/pci/devices/*/subsystem_vendor"
        echo "  cat /sys/bus/pci/devices/*/subsystem_device"
        echo ""
        echo "Look for a device with subsystem_vendor = 0x17aa and an audio PCI class (0x040300 or 0x040100)."
    fi
fi

# Method 3: check against known IDs from the driver package
if [[ "$found" -eq 1 ]]; then
    echo "Checking against known IDs in the Lenovo n3ga127w.exe driver package..."
    echo "(Run this from the root of the repository)"
    echo ""

    # Known IDs from the driver package (DEV_0287 AMD + DEV_0285 AMD + representative DEV_0257 Intel)
    known_ids=(
        17AA22F1 17AA22F2 17AA22F3 17AA22F8 17AA22F9 17AA22FA 17AA22FB 17AA22FC
        17AA22C6 17AA22C7 17AA22D4 17AA22D5 17AA22D8 17AA22DE 17AA22E1 17AA22E4
        17AA22E5 17AA22E6 17AA22E7 17AA2234 17AA2304 17AA2314 17AA2315 17AA2316
        17AA2317 17AA2318 17AA2319 17AA231A 17AA231B 17AA231E 17AA231F 17AA2326
        17AA2340 17AA2341 17AA3809 17AA508B 17AA50B0
        17AA2292 17AA2293 17AA229D 17AA22B8 17AA22BB 17AA22BE 17AA22BF 17AA22C0
        17AA22C1 17AA22C2 17AA22C3 17AA22D6
    )

    # Re-read the detected ID
    for dev in /sys/bus/pci/devices/*; do
        class_file="$dev/class"
        subvendor_file="$dev/subsystem_vendor"
        subdevice_file="$dev/subsystem_device"
        [[ -f "$class_file" && -f "$subvendor_file" && -f "$subdevice_file" ]] || continue
        class=$(cat "$class_file" 2>/dev/null)
        subvendor=$(cat "$subvendor_file" 2>/dev/null)
        if [[ ("$class" == "0x000403" || "$class" == "0x000401" || "$class" == "0x040300" || "$class" == "0x040100") && "$subvendor" == "0x17aa" ]]; then
            subdevice=$(cat "$subdevice_file" 2>/dev/null)
            subsys_id=$(printf "%04X" "$((subdevice))")
            full_id="17AA${subsys_id}"
            for known in "${known_ids[@]}"; do
                if [[ "$full_id" == "$known" ]]; then
                    echo "  ${full_id} is present in the driver package."
                    if [[ "$full_id" == "17AA22F2" ]]; then
                        echo "  This is the ThinkPad Z16 Gen 1 — pre-generated assets are in assets/thinkpad-z16-gen1/"
                    else
                        echo "  Run generate-presets.sh to create presets for this hardware."
                    fi
                    break 2
                fi
            done
            echo "  ${full_id} was not found in the known ID list."
            echo "  Your device may use a different driver package. Check docs/reproduce.md."
        fi
    done
fi
