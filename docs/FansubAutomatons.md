# Fansub Automatons

English | [Español](es/FansubAutomatons.md) | [Hephaestus](Hephaestus.md)

**Fansub Automatons** is the shared backend managed by Hephaestus Fansubber. Its single `fansub-automatons` package provides drawing conversion, surface reconstruction, tracking and audio processing. Auto Blur analyzes video inside Aegisub.

## Install from Hephaestus

Open **Hephaestus Fansubber → Install → All automatons**, then **Check → All automatons**. **Install** also offers individual tools, media tools and Auto Mask models. **Configure** selects the installation folder and compute device.

Integrated installation downloads the latest compatible stable [Fansub Automatons release](https://github.com/Kiterowx/Fansub-Automatons/releases), verifies the ZIP and its SHA-256, and prepares the runtime. It requires backend version **1.2.1** or later.

If GitHub has no compatible stable release with both the ZIP and its `.sha256` file, **Install** stops and reports the problem. To install from repository files, run `Install.cmd` in a complete checkout of [Fansub Automatons](https://github.com/Kiterowx/Fansub-Automatons).

## Install from the package

On Windows x64, extract the distribution into a location you intend to keep and run **Install.cmd**. It prepares private Python 3.13.7, FFmpeg, FFprobe, Lua dependencies and the selected Python capabilities. Internet access is used for required packages and models. SCXvid is obtained from its author's release and verified before extraction with Windows `tar.exe`.

```text
Install.cmd --modules all --compute auto
Install.cmd --modules chrono_audio --compute cpu
```

Installer identifiers are `autoblur`, `automotion`, `automask`, `png2ass`, `chrono_audio` and `all`. The latter two feature identifiers correspond to Auto Drawing and Auto Timing. Use `--home` to select the shared location and `--aegisub` for the Aegisub profile containing `automation` and `config`.

A new profile receives Hephaestus. An existing Chrono installation is updated with the matching integration. Missing third-party files are supplied from the verified bundle; existing libraries are preserved. The Yutils compatibility entry uses `tstools.Yutils`.

## Runtime, device and disk space

The default home is `%LOCALAPPDATA%\Kiterow\Fansub Automatons`. `auto` selects a compute profile using the available driver; `cpu` and `cuda` select one explicitly.

Creating a new runtime requires **14 GiB free for CUDA** or **6 GiB for CPU**, with a **2 GiB** reserve. These are installer thresholds, separate from project media, model downloads and processing outputs. An existing matching verified runtime is reused.

The installer checks compatible packages against their installed file records before reuse. Native files can use hard links on supported volumes; other files are copied into the private environment. Missing or incompatible requirements are installed with pip caching disabled. The original Python environment and NVIDIA driver are preserved.

Auto Mask models are installed with its capability and can be restored through **Install → Auto Mask models**. Audio separation obtains the selected profile's model on first use. Keep the shared model folders for reuse.

## Recovery and migration

The new runtime is verified before activation. Replaced files, configuration backups and recovery journals go to **Documents/Aegisub Maintenance/Fansub Automatons**. Activation uses atomic replacement and retries for transient file locks. A failed activation restores the previous state; the next installer run can recover an interrupted activation. Previous runtimes remain available.

The configuration retains `olympus.json` and legacy capability identifiers for migration. Current user-facing names are Fansub Automatons and Hephaestus. Update the macro and the [nine distributed Kite modules](Dependencies.md#included-modules) together, and move replaced copies outside active autoload/include paths.

## Diagnosis

**Check** inspects scripts, module files, Python dependencies, tools and models. **Details** provides technical diagnostics. Confirm loaded scripts from Automation in Aegisub, then verify the operation with the intended project media.

The package keeps executables in private folders and leaves system PATH and Windows protection settings intact. If a tool is blocked, retain the diagnostic and verify its origin and local policy.

## Sources and licenses

SCXvid comes from [soyokaze's r1 release](https://github.com/soyokaze/SCXvid-standalone/releases/tag/r1). Python and media assets are identified in the distribution manifest; Lua licenses are stored in `LICENSES`, and FFmpeg licenses accompany its tools.
