# Kite Aegisub Scripts

English | [Español](README.es.md)

Aegisub scripts for timing, typesetting, karaoke and subtitle editing. Each guide covers the available tools and how to use them.

## Scripts

Start with the [installation steps](#installation). The table lists the additional requirements for each script.

| Script | Version | Interface languages | Requirements |
| --- | --- | --- | --- |
| AddTexture | 2.1.8 | English | ZF, ASSFoundation and an ASS drawing on the clipboard. |
| Alecto KFX | 3.4.3 | Spanish | `karaskel.lua`, included with Aegisub; timed karaoke for syllable effects. |
| Allure | 1.2.4 | English, Spanish | `l0.dkjson` and the fonts used in the subtitles. |
| AutoBlur | 2.1.4 | English | arch1t3cht's Aegisub and loaded video. |
| AutoMask | 2.5.5 | English | Python 3.10+, the AutoMask backend, FFmpeg and loaded video. |
| Chrono Suite | 1.5.3 | English, Spanish, Portuguese | Wave2json output for Auto Timing; FFmpeg for Scream Detector; FFmpeg and SCXvid for Extract KF. |
| Cliptomaniac | 0.4.4 | English, Spanish | ZF, ASSFoundation, Functional, Aegisub-Motion and arch libraries. |
| Field Group Manager | 1.1.8 | English | No additional requirements. |
| Gradient Row | 1.8.9 | English | Aegisub-Motion, ASSFoundation and arch.Perspective; SubInspector for rendered bounds. |
| Hotkeys | 2.0.2 | English | No additional requirements. |
| Macaria Revert | 1.0.2 | English | Generated karaoke lines to reconstruct. |
| Moka Motion | 3.7.6 | English | Aegisub-Motion, ASSFoundation, arch libraries and ZF; FFmpeg for exports. |
| Obake | 0.4.5 | English, Spanish | ASSFoundation and Aegisub-Motion. |
| PNG2ASS | 1.6.4 | English | Python 3.10+ and the PNG2ASS backend. |
| Pointiac | 1.1.7 | English | Loaded video for frame markers. |
| Rhea Signs | 2.1.4 | English, Spanish, Portuguese | ASSFoundation, Functional, Aegisub-Motion and arch.Perspective. |
| Selesub | 2.1.8 | English | `myaa.ASSParser`. |
| Snapshoter | 1.6.8 | English | Aegisub-Motion, `myaa.ASSParser`, FFmpeg and loaded video. |
| Social Clip | 1.0.3 | Spanish | Aegisub-Motion, ASSFoundation, `myaa.ASSParser`, FFmpeg/FFprobe and loaded video; SubInspector for complex masks. |
| Wave2json | 1.3.6 | No GUI | FFmpeg on `PATH` and loaded audio. |
| Zagreo Glyphs | 1.2.3 | English | Aegisub-Motion, ASSFoundation and Yutils. |
| Zheus Colormanager | 4.7.3 | Spanish | VSFilterMod for four-corner gradients; loaded video for ColorRelay. |

## Installation

### 1. Aegisub and DependencyControl

Use [arch1t3cht's Aegisub — Migration Release 04](https://github.com/arch1t3cht/Aegisub/releases/tag/migration04-01), based on [TypesettingTools/Aegisub](https://github.com/TypesettingTools/Aegisub). It includes the extra tools used by these scripts. You can also find the [TypesettingTools releases here](https://github.com/TypesettingTools/Aegisub/releases).

Install [DependencyControl](https://github.com/TypesettingTools/DependencyControl#installation) and keep Aegisub's bundled Automation files. The instructions below use the Windows automation directory: `%APPDATA%\Aegisub\automation`. For a portable installation, use its configured automation directory.

### 2. Scripts and modules

Download this repository and copy:

| From the repository | To Aegisub's automation directory |
| --- | --- |
| The scripts you want from `Macros/` and `Macros-Lite/` | `autoload/` |
| The complete `Modules/kite/` folder | `include/kite/` |

**Copy all 12 modules to `include/kite`, keeping the `kite` folder.** These scripts require all 12 included modules. When updating, replace the scripts and modules together. Remove duplicate script copies, then restart Aegisub or choose **Automation > Rescan Autoload Dir**.

### Lua libraries

Install the libraries listed for each script through DependencyControl or from their repositories. For a manual installation, keep the provided `include` folder structure.

| Library | Modules |
| --- | --- |
| [ASSFoundation](https://github.com/TypesettingTools/ASSFoundation) | `l0.ASSFoundation` |
| [Functional](https://github.com/TypesettingTools/Functional) | `l0.Functional` |
| [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) | `a-mo.*` |
| [arch libraries](https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts) | `arch.Math`, `arch.Perspective`, `arch.Util` |
| [ZF](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) | `ZF.main` |
| [Akatsumekusa scripts](https://github.com/Akatmks/Akatsumekusa-Aegisub-Scripts) | `aka.command` |
| [Myaamori scripts](https://github.com/TypesettingTools/Myaamori-Aegisub-Scripts) | `myaa.ASSParser` |
| [SubInspector](https://github.com/TypesettingTools/SubInspector) | `SubInspector.Inspector` |
| [Yutils](https://github.com/Youka/Yutils) | `Yutils.lua` |

Install `aka.command` for external processes and `l0.dkjson` through DependencyControl. Use the fonts referenced by your subtitle styles. The [dependency guide](docs/Dependencies.md) lists the included modules and Python packages.

### 3. Python backends

AutoMask and PNG2ASS need **64-bit [Python](https://www.python.org/downloads/) 3.10 or newer**, with `pip`, and [Git](https://git-scm.com/downloads) on `PATH`.

1. Open **AutoMask/Backend/Configure** or **PNG2ASS/Backend/Configure** and select Python.
2. Run **Backend/Install or Update**.
3. Run **Backend/Check** to confirm installation.

**The installer handles OpenCV and the other Python libraries.** For AutoMask's EfficientSAM and LaMa tools, also run **AutoMask/Backend/Install Models**. Gradient reconstruction works without those models.

To install from a terminal:

```text
python -m pip install --upgrade "git+https://github.com/Kiterowx/kite-png2ass.git"
python -m pip install --upgrade "git+https://github.com/Kiterowx/kite-automask.git"
```

Run the command for the backend you need; AutoMask also installs PNG2ASS. Use the same Python interpreter in the terminal and Aegisub.

### 4. FFmpeg and SCXvid

Install [FFmpeg](https://ffmpeg.org/download.html), including FFprobe, and add it to `PATH` or select its executable in the script settings. Use a build with libass and libx264 for subtitle rendering and video exports. Restart Aegisub after changing `PATH`.

For **Chrono Suite/Extract KF**, also install the SCXvid command-line executable and set both paths in **Chrono Suite/Config > SCXvid**. Export audio with Wave2json to create the waveform JSON used by Auto Timing.

The Python installer does not install FFmpeg or SCXvid. Keep Windows PowerShell available for external processes.

## DependencyControl

The update feed contains the 22 scripts and 12 modules in this repository:

```text
https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json
```

## Support

Join the [support Discord](https://discord.gg/Egq8us4xZC). Include the macro name and version, your Aegisub build, the error message and the steps needed to reproduce the problem.

## Links

- Catalogue site: <https://kiterowx.github.io/Kite-Aegisub-Scripts-Guide/>
- Chrono Generators: <https://github.com/Kiterowx/Chrono-Generators-Scripts>
- Timing guide: <https://kiterowx.github.io/Arquitectura-del-Timing/>

## Documentation

- [AddTexture](docs/AddTexture.md)
- [Alecto KFX](docs/AlectoKFX.md)
- [Allure](docs/Allure.md)
- [AutoBlur](docs/AutoBlur.md)
- [AutoMask](docs/AutoMask.md)
- [Chrono Suite](docs/ChronoSuite.md)
- [Cliptomaniac](docs/Cliptomaniac.md)
- [Dependencies](docs/Dependencies.md)
- [Field Group Manager](docs/FieldGroupManager.md)
- [Gradient Row](docs/GradientRow.md)
- [Hotkeys](docs/Hotkeys.md)
- [Macaria Revert](docs/MacariaRevert.md)
- [Moka Motion](docs/MokaMotion.md)
- [Obake](docs/Obake.md)
- [PNG2ASS](docs/PNG2ASS.md)
- [Pointiac](docs/Pointiac.md)
- [Rhea Signs](docs/RheaSigns.md)
- [Selesub](docs/Selesub.md)
- [Snapshoter](docs/Snapshoter.md)
- [Social Clip](docs/SocialClip.md)
- [Wave2json](docs/Wave2json.md)
- [Zagreo Glyphs](docs/ZagreoGlyphs.md)
- [Zheus Colormanager](docs/Zheus.md)

## License

MIT. See [LICENSE](LICENSE).
