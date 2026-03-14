# Background: Why Linux ThinkPad Audio Sounds Different from Windows

This document explains what Dolby DAX3 is, why it matters, and how this repository reconstructs its effect outside of Windows.

---

## The physical reality of laptop speakers

A ThinkPad is not a hi-fi speaker system. The Z16 Gen 1 houses two Cirrus Logic CS35L41 Class-D amplifiers driving a pair of small speaker capsules in a thin aluminium chassis. Every design choice in that enclosure is a compromise against space, weight, and thermal constraints.

Small speaker drivers in small enclosures behave predictably poorly in certain frequency ranges. They roll off steeply in the bass because the driver has neither the excursion range nor the back-volume to move enough air at low frequencies. They often have resonant peaks in the upper midrange and lower treble caused by standing waves in the chassis cavity. And they have essentially no ability to create a convincing stereo image because the drivers are less than 20 cm apart and aimed at a surface — the keyboard deck — rather than at the listener.

None of this means the hardware is bad. It means the hardware requires software to function as intended.

Lenovo employs acoustic engineers. They measure the frequency and phase response of the speaker assembly on production hardware, characterise the resonances and rolloff, and derive a set of digital filters that correct the speaker's response to a known target curve. This is called *speaker correction*, and every laptop manufacturer that ships decent audio does it. What sets Lenovo's ThinkPad implementation apart is that this tuning is model-specific — the Z16 Gen 1's correction filters are different from the T14s Gen 3's, because the cabinets are different — and it runs as part of a larger, multi-stage DSP pipeline co-developed with Dolby.

---

## What Dolby DAX3 is

DAX3 is Dolby's *Device Audio eXperience* version 3, a Windows kernel-mode audio extension (APO — Audio Processing Object) that implements a real-time digital audio pipeline. From the user's perspective it appears as the "Dolby Audio" control panel. From the engineer's perspective, it is a processing graph with the following stages:

**IEQ (Intelligent EQ) via FIR convolution.** The primary frequency correction is implemented as a finite impulse response (FIR) filter encoded as an impulse response (IRS) file. Lenovo specifies three IEQ target curves per device — *Balanced*, *Detailed*, and *Warm* — representing different tonal balances. The *Balanced* curve aims for a neutral reference response; *Detailed* emphasises the upper midrange and treble; *Warm* pulls the presence region back and favours a denser low-mid character. FIR filters can be designed as either linear-phase (symmetric impulse, zero phase distortion, fixed group delay) or minimum-phase (asymmetric impulse, front-loaded energy, lower latency but non-linear phase). The IRS files in this repository use a **minimum-phase** design, which is standard for real-time audio processing because it introduces the minimum possible latency. The tradeoff is that minimum-phase filters introduce some phase non-linearity, primarily in the bass — generally inaudible for speaker correction use on laptop hardware.

**Audio Optimizer (speaker correction).** A second set of per-band gain adjustments corrects for measured asymmetries between the left and right speaker capsules. The Z16's measured corrections are small (sub-3 dB across most of the spectrum) but non-zero, and they vary between the left and right channel, indicating the speakers are not matched at the driver level.

**Parametric EQ.** A high-pass filter at 100 Hz rolls off sub-bass content that the drivers cannot reproduce. Some profiles include additional notch filters for specific resonant peaks.

**Surround virtualizer (select profiles only).** The Dynamic and Movie profiles apply a stereo widening stage that uses the `stereo-base` parameter to increase the apparent separation between the channels. This uses psychoacoustic techniques to make the two close-proximity drivers sound further apart.

**Dialog enhancer.** A narrowband boost centred at 2.5 kHz increases speech intelligibility in Movie and Voice profiles. The gain is derived from Dolby's `dialog-enhancer-amount` coefficient in the tuning XML.

**Volume leveler (autogain).** An EBU R128 loudness normaliser that attempts to maintain consistent perceived loudness across sources with different average levels. DAX3 enables this by default; the generated EasyEffects presets preserve it but leave it *bypassed*. The reason is documented below.

**Multiband compressor.** Six-band dynamic compression applying the coefficients from Dolby's `mb-compressor-tuning` DSP block. This controls inter-band loudness relationships and prevents harshness on peaks.

**Regulator (per-band limiter).** A set of per-band gain ceilings derived from Dolby's `threshold_high` values. The first nine bands (sub-bass through lower treble, 47 Hz – 9 kHz) have non-zero ceiling values; the upper bands are unconstrained. This protects the CS35L41 amplifiers from being driven beyond their safe operating range in the frequency bands where the speakers are most sensitive.

**Brickwall limiter.** A final −1 dBFS limiter that prevents digital clipping after all preceding gain stages.

### A note on autogain

The autogain stage is bypassed in the generated presets because it depends on Dolby's *Media Intelligence* signal classifier, which runs on Windows and categorises incoming audio as speech, music, or silence. Without the classifier steering the autogain, the EBU R128 algorithm applies gain increases to quiet passages that then clip on louder transients. The settings are preserved in the JSON so the stage can be enabled manually via the EasyEffects UI, but blind activation is not recommended.

---

## What happens on Linux without this pipeline

PipeWire is a modern Linux audio server that replaced PulseAudio and JACK in most distributions from 2021 onward. It routes audio from applications to hardware with extremely low latency and good compatibility. It does not, by default, apply any speaker correction or DSP processing.

When an application plays audio on a Linux ThinkPad Z16 without the EasyEffects pipeline active:

- The CS35L41 amplifiers receive a flat PCM signal.
- No sub-bass rolloff is applied. Frequencies below 100 Hz are sent to drivers that cannot reproduce them, wasting amplifier headroom.
- No frequency correction is applied. The speaker's natural resonances and rolloff remain uncompensated.
- No stereo widening is applied. The drivers' proximity produces a narrow, centre-localised image.
- No compression or limiting is applied beyond what the CS35L41 firmware implements internally.

The result is audio that works, and that technically reproduces what was recorded, but that sounds thin, honky, and cramped compared to the same hardware on Windows. It is not a driver bug or a hardware incompatibility. It is the absence of tuning that the hardware was designed to have applied.

---

## How EasyEffects fits in

[EasyEffects](https://github.com/wwmm/easyeffects) is a PipeWire plugin host that sits in the audio graph between applications and hardware. It loads a user-defined chain of LADSPA/LV2 plugins and applies them to the audio stream in real time. It runs as a PipeWire client, which means it works with any application that uses PipeWire — including PulseAudio applications (via the PipeWire PulseAudio compatibility layer) — without requiring per-application configuration.

An EasyEffects *output preset* is a JSON file that defines the plugin chain and its parameters for the speaker output path. It references `.irs` files (impulse response files in WAV-compatible format) for convolver stages and encodes all other parameters directly as floating-point values.

By loading one of the presets in this repository, EasyEffects reconstructs the full DAX3 DSP chain as a PipeWire graph, applying the speaker correction, compression, and limiting that Lenovo's engineers designed for the hardware.

---

## How the assets in this repository were generated

The generation pipeline requires no Windows installation, virtual machine, or audio loopback capture. It operates entirely on data extracted from Lenovo's official driver package.

### Step 1 — Extract the driver

Lenovo's audio driver `n3ga127w.exe` is an Inno Setup self-extracting installer. The `innoextract` tool (available in nixpkgs and most distribution repositories) unpacks the installer on Linux without executing any Windows code.

```bash
innoextract -e n3ga127w.exe -d ./extracted/
```

### Step 2 — Locate the DAX3 tuning XML

The extracted driver contains a directory `Dolby/dax3/ext_thinkpad/` with per-device XML files named by PCI hardware ID. The Z16 Gen 1 file is:

```
DEV_0287_SUBSYS_17AA22F2_PCI_SUBSYS_22F217AA.xml
```

`DEV_0287` is the Realtek ALC287 codec device ID. `SUBSYS_17AA22F2` is the Lenovo PCI subsystem ID for the Z16 Gen 1 (machine types 21D4 and 21D5). This subsystem ID is what the Windows driver uses to select the correct tuning profile for the hardware.

The XML contains all DAX3 tuning parameters: IEQ target arrays, audio-optimizer per-band gain tables, PEQ filter coefficients, multiband compressor tuning, regulator thresholds, and dialog enhancer amounts — one complete set per Dolby profile (Music, Dynamic, Movie, Game, Voice, etc.).

### Step 3 — Convert to EasyEffects format

The [`antoinecellerier/speaker-tuning-to-easyeffects`](https://github.com/antoinecellerier/speaker-tuning-to-easyeffects) Python script reads the DAX3 XML and performs the following transformations:

1. **IEQ + Audio Optimizer → FIR → IRS file.** The IEQ target array and audio-optimizer per-band corrections are combined into a single minimum-phase FIR filter using `scipy.signal`. The filter is exported as a `.irs` file (a 32-bit float WAV) that EasyEffects' Convolver plugin can load. One IRS file is generated per profile × tone variant combination (e.g., `Dolby-Music-Balanced.irs`).

2. **PEQ coefficients → EasyEffects Equalizer JSON.** The parametric EQ filters are translated directly into EasyEffects' equalizer stage format.

3. **Compressor tuning → EasyEffects Multiband Compressor JSON.** Dolby's DSP compressor coefficients are decoded and mapped to the corresponding GStreamer/EasyEffects multiband compressor parameters.

4. **Regulator thresholds → EasyEffects Regulator JSON.** Per-band limiter ceilings are mapped directly.

5. **Dolby profile flags → plugin enable/bypass states.** Stages like the stereo widener and dialog enhancer are only enabled in the profiles that use them.

The output is one JSON preset file per profile × tone variant, referencing the corresponding IRS file by name (`kernel-name`, the EasyEffects 8.x format — bare filename stem without path or extension).

The generation command:

```bash
python3 dolby_to_easyeffects.py \
  --all-profiles \
  --endpoint internal_speaker \
  --output-dir ./presets/ \
  --irs-dir ./irs/ \
  DEV_0287_SUBSYS_17AA22F2_PCI_SUBSYS_22F217AA.xml
```

This produces 27 preset files and 27 IRS files (9 Dolby profiles × 3 IEQ tone variants).

---

## Why this approach is more accurate than loopback capture

An alternative approach sometimes used for speaker correction is to record the speaker output with a calibrated measurement microphone and derive correction filters from the measurement. This has several disadvantages in this context:

- It captures the speaker response in a specific room and at a specific microphone position, not the free-field or in-ear response that Lenovo tuned for.
- It requires a calibrated microphone and measurement setup.
- It cannot recover the multiband compressor tuning, per-band limiting, or stereo widening that DAX3 applies.

The DAX3 XML extraction approach uses the exact tuning data that Lenovo's acoustic engineers derived from their own measurements and target curves, in the form they encoded it for the hardware. The only transformation is format conversion — no measurement error, no room acoustics, no approximation.
