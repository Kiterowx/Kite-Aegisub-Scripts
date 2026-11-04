# Hephaestus Fansubber

Version **1.2.1**. English | [Español](es/Hephaestus.md)

Hephaestus contains the five Autos in `kite.Hephaestus.lua`. Open **Hephaestus Fansubber → Automatons** to work; **Install**, **Check** and **Configure** manage the shared **Fansub Automatons** backend.

| Tool | Purpose |
| --- | --- |
| [Auto Drawing](AutoDrawing.md) | Convert images, sequences and SVG to ASS drawings; the current name of PNG2ASS. |
| [Auto Mask](AutoMask.md) | Detect surfaces, reconstruct backgrounds and create fills, shapes or clips. |
| [Auto Blur](AutoBlur.md) | Derive blur curves from video using a fixed or tracked sample. |
| [Auto Motion](AutoMotion.md) | Track a video region, apply the motion and save it for reuse or restoration. |
| [Auto Timing](AutoTiming.md) | Timing, vocal separation, signals, Scream Detector, SCXvid and waveform export. |

## Installation

1. Prepare Aegisub and DependencyControl with the [installation guide](../README.md#installation).
2. Copy `kite.Hephaestus.lua` into `automation/autoload`, or install it from the Kite feed. Open its normal entry to resolve pending modules and rescan Automation.
3. Choose **Hephaestus Fansubber → Install → All automatons**, or select a specific tool under **Install**.
4. Run **Check → All automatons** and review pending components. **Details** opens the technical diagnostics.
5. Open the required tool under **Automatons** and prepare its input.

**Configure** selects the installation folder and `auto`, `cpu` or `cuda` device. A new installation uses `%LOCALAPPDATA%\Kiterow\Fansub Automatons` on Windows x64. The installer prepares private Python, FFmpeg, FFprobe, required packages and models, and obtains a verified SCXvid download.

Integrated installation downloads the latest compatible stable [Fansub Automatons release](https://github.com/Kiterowx/Fansub-Automatons/releases), verifies the ZIP and its SHA-256, and prepares the runtime. It requires backend version **1.2.1** or later.

## Space and models

A new environment requires **14 GiB free with CUDA** or **6 GiB with CPU**, with a **2 GiB** reserve. These are installation thresholds; project media and processing outputs need additional working space.

Compatible verified runtimes are reused. Package downloads run with pip caching disabled. Auto Mask models are prepared by its installer, while vocal separation downloads each profile's model on first use. Keep the models for reuse between projects.

Replaced files and recovery records are stored in **Documents/Aegisub Maintenance/Fansub Automatons**. Keep retired macros and modules in Documents, outside Aegisub's active loading paths. See [installer and recovery details](FansubAutomatons.md).

## Migration

| Previous feature | Current location under Automatons |
| --- | --- |
| PNG2ASS | Auto Drawing |
| AutoMask / AutoBlur / AutoMotion | Auto Mask / Auto Blur / Auto Motion |
| Chrono Auto Timing and Scream Detector | Auto Timing → Timing / Scream Detector |
| Chrono Extract KF | Auto Timing → Keyframes |
| Chrono Audio | Auto Timing → Audio |
| Wave2json | Auto Timing → Waveform |

Recognized settings, shortcuts and favorites migrate to the current paths. Timing and Scream settings import once from Chrono. [Chrono](ChronoSuite.md) retains audit, editing and import tools; [Rhea](RheaSigns.md) provides After Effects Keyframes.

The distribution keeps [seven common modules plus Automatons and MotionEngine](Dependencies.md#included-modules). Update macros and modules as a set. **Check** verifies components and backend capabilities; use Automation in Aegisub to confirm macro loading.
