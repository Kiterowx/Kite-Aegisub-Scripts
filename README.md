# Kite Aegisub Scripts

English | [Español](README.es.md)

I develop these tools for typesetting, text editing, timing and media export in Aegisub. This repository contains the scripts, their shared modules and usage guides. Each macro can be installed separately with its dependencies.

## Scripts

| Script | Version | Purpose |
| --- | --- | --- |
| [AddTexture](docs/AddTexture.md) | 2.2.1 | Texture, patterns and drawing effects. |
| [Allure](docs/Allure.md) | 1.2.8 | Sign library, movement and animation. |
| [Chrono Suite](docs/ChronoSuite.md) | 1.8.0 | Audit, text utilities, Import Lines, Cleanup, Joinator and Final Data. |
| [Cliptomaniac](docs/Cliptomaniac.md) | 0.4.8 | Edit rectangular and vector clips. |
| [Gradient Row](docs/GradientRow.md) | 1.9.2 | Gradients across lines and text. |
| [Hephaestus Fansubber](docs/Hephaestus.md) | 1.2.1 | The five Autos and shared backend installation. |
| [Hotkeys](docs/Hotkeys.md) | 2.0.4 | Shortcuts, favorites and shared preferences. |
| [Kiri-Shot](docs/KiriShot.md) | 1.0.0 | PNG captures, sequences, masks and social video. |
| [Moka Motion](docs/MokaMotion.md) | 3.8.2 | Apply Mocha tracking to subtitle position, scale, rotation and perspective. |
| [Obake](docs/Obake.md) | 0.4.8 | Transform chains and transitions. |
| [Rhea Signs](docs/RheaSigns.md) | 2.4.0 | Sign editing, tags, shapes, fonts, fades and After Effects Keyframes. |
| [Selesub](docs/Selesub.md) | 2.2.0 | Filter, select and assign grouped field values with Fields. |
| [Zheus Color](docs/Zheus.md) | 1.0.0 | Actor palettes, gradients and color comparison. |

### Hephaestus Fansubber

- [Auto Drawing](docs/AutoDrawing.md): Images, SVG and sequences.
- [Auto Mask](docs/AutoMask.md): Surface detection and reconstruction.
- [Auto Blur](docs/AutoBlur.md): Blur curves from video.
- [Auto Motion](docs/AutoMotion.md): Tracking, project history and restoration.
- [Auto Timing](docs/AutoTiming.md): Lazy/Busy/Legacy, vocals, signals, Scream Detector, keyframes and waveform.

## Installation

Install in this order: **Aegisub and DependencyControl → environment libraries → third-party modules → Kite scripts and modules → external programs for the features needed**. Current macros provide a normal entry for resolving pending dependencies through DependencyControl. You can also install the required modules from the catalog before copying scripts. If an entry is missing, inspect Automation load errors.

### 1. Aegisub and DependencyControl

The recommended build is [arch1t3cht's Aegisub — Migration Release 04](https://github.com/arch1t3cht/Aegisub/releases/tag/migration04-01), based on [TypesettingTools/Aegisub](https://github.com/TypesettingTools/Aegisub). Auto Blur uses video functions from arch1t3cht's build. Keep the Automation folders and libraries supplied with Aegisub.

If DependencyControl is missing or fails after installing Aegisub Migration, it can be repaired with [version 0.9.1](https://github.com/TypesettingTools/DependencyControl/releases/tag/v0.9.1):

1. Download **[DependencyControl-v0.9.1.zip](https://github.com/TypesettingTools/DependencyControl/releases/download/v0.9.1/DependencyControl-v0.9.1.zip)** from the release assets. The **Source code** archives contain the repository, not the installation package.
2. Close Aegisub and extract the package contents into `%APPDATA%\Aegisub\automation`, merging its `autoload` and `include` folders with the existing ones. Avoid an extra `automation\automation` level.
3. Open Aegisub and check for **DependencyControl → Install Script** under Automation. Scripts can also be reloaded with **Automation → Rescan Autoload Dir**.

Use the user-profile folder, not the installation folder under `Program Files`, where updates can fail because of permissions. Portable installations use their configured Automation paths. The usual Linux path is `~/.aegisub/automation`; on macOS it is `~/Library/Application Support/Aegisub/automation`.

Version 0.9.1 fixes one cause of **Bad DependencyControl record**: manually installed modules with an unparseable version. It cannot repair a wrong directory or install external programs. On Aegisub 3.4 or newer, the current Windows/macOS DependencyControl package supplies its required components: DownloadManager, BadMutex and PreciseTimer no longer need separate installation. Other libraries can still need **requireffi**, which is installed as a ZF dependency. See the [official installation instructions](https://github.com/TypesettingTools/DependencyControl/blob/v0.9.1/README.md).

### 2. Environment libraries

These components are checked separately from the module list above:

| Component | Source and use |
| --- | --- |
| `karaskel.lua`, `utils.lua`, `aegisub.re`, `aegisub.unicode`, `aegisub.clipboard` and the MoonScript loader | Part of Aegisub's Automation environment. Keep the files supplied with Aegisub; these are not entries to install from this module catalog. |
| [Yutils (tstools)](https://github.com/TypesettingTools/Yutils) | Install **Yutils (tstools)** (`tstools.Yutils`) through DependencyControl for geometry macros and libraries that use Yutils. The scripts retain compatibility with `require("Yutils")`. It requires LuaJIT; libpng is only needed for its PNG reader. |
| [LuaJSON](https://github.com/harningt/luajson) (`json`) | Required by Aegisub-Motion's **Line**, Chrono's Smart Split and Auto Timing for waveform reading. If missing, copy `json.lua` and the `json` folder from the project's [lua directory](https://github.com/harningt/luajson/tree/master/lua) into `automation/include`. It needs LPeg (`lpeg`), supplied by the Lua environment of the recommended builds. Keep the complete `json` folder: dkjson does not provide the same API. |
| Fonts | Must be available to Aegisub and to the renderer used for exports. |
| VSFilterMod | Zheus four-corner gradients require a renderer that supports those extensions. Installing a Lua module does not add that support to libass. |

### 3. Third-party modules from DependencyControl

Open **DependencyControl → Install Script** and use the **Modules:** dropdown. **Automation Scripts:** is a separate selector for macros. Entries normally show a version after the module name and may also show a channel.

Install **aka.command**, a shared dependency of the Kite modules. Then install the modules for the chosen scripts using the [per-script table](docs/Dependencies.md#dependencies-by-script). **dkjson** is bundled with DependencyControl and is explicitly declared by Allure. One macro does not require every library in this catalog; check which ones it needs.

| Name in **Modules** | Identifier in code | Source catalog |
| --- | --- | --- |
| **Yutils (tstools)** | `tstools.Yutils` | [TypesettingTools/Yutils](https://github.com/TypesettingTools/Yutils) · [feed](https://raw.githubusercontent.com/TypesettingTools/Yutils/master/DependencyControl.json) |
| **ZF main** | `ZF.main` | [zeref](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json) |
| **ASSFoundation** | `l0.ASSFoundation` | [ASSFoundation](https://github.com/TypesettingTools/ASSFoundation) · [feed](https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json) |
| **(Almost) Functional Suite** | `l0.Functional` | [Functional](https://github.com/TypesettingTools/Functional) · [feed](https://raw.githubusercontent.com/TypesettingTools/Functional/master/DependencyControl.json) |
| **Line** | `a-mo.Line` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **LineCollection** | `a-mo.LineCollection` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **Log** | `a-mo.Log` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **Tags** | `a-mo.Tags` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **ArchMath** | `arch.Math` | [arch1t3cht](https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json) |
| **Perspective** | `arch.Perspective` | [arch1t3cht](https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json) |
| **Util** | `arch.Util` | [arch1t3cht](https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json) |
| **SubInspector** | `SubInspector.Inspector` | [SubInspector](https://github.com/TypesettingTools/SubInspector) · [feed](https://raw.githubusercontent.com/TypesettingTools/SubInspector/master/DependencyControl.json) |
| **aka.command** | `aka.command` | [Akatsumekusa](https://github.com/Akatmks/Akatsumekusa-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/Akatmks/Akatsumekusa-Aegisub-Scripts/master/DependencyControl.json) |
| **ASS Parser** | `myaa.ASSParser` | [Myaamori](https://github.com/TypesettingTools/Myaamori-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/Myaamori-Aegisub-Scripts/master/DependencyControl.json) |
| **dkjson** | `l0.dkjson` | [DependencyControl](https://github.com/TypesettingTools/DependencyControl) · [feed](https://raw.githubusercontent.com/TypesettingTools/DependencyControl/v0.9.1/DependencyControl.json) |
| **DataWrapper** | `a-mo.DataWrapper` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **polyclipping** | `zpolyclipping.polyclipping` | [zeref](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json) |
| **zimg** | `zimg.main` | [zeref](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json) |
| **Transform** | `a-mo.Transform` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **petzkuLib** | `petzku.util` | [petzku](https://github.com/petzku/Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/petzku/Aegisub-Scripts/refs/heads/master/DependencyControl.json) |
| **DataHandler** | `a-mo.DataHandler` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **ShakeShapeHandler** | `a-mo.ShakeShapeHandler` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **requireffi** | `requireffi.requireffi` | [ffi-experiments](https://github.com/TypesettingTools/ffi-experiments) · [feed](https://raw.githubusercontent.com/TypesettingTools/ffi-experiments/master/DependencyControl.json) |

For example, `l0.Functional` is listed as **(Almost) Functional Suite**, and `myaa.ASSParser` as **ASS Parser**.

If a catalog is missing, add its **feed** link through **Manage Feeds**, review any trust prompt and refresh the list. Already installed modules may be absent from the installation dropdown; check DependencyControl's update options instead. Dependencies of these libraries are resolved from their own feeds. Installing the Aegisub-Motion macro is not necessary just to obtain **LineCollection**, for example.

The table also includes indirect dependencies: **petzkuLib** installs with **aka.command**; **polyclipping**, **zimg** and **requireffi** with **ZF main**; **Transform** with **Line**. **DataWrapper** is only needed for Auto Blur tracking and adds **DataHandler** and **ShakeShapeHandler**. **SubInspector** is an **ASSFoundation** dependency, even though not all its functions use it.

### 4. Copy the Automation folder

The [repository](https://github.com/Kiterowx/Kite-Aegisub-Scripts) has one installation tree:

```text
automation/
├── autoload/           13 public scripts (.lua and .moon)
└── include/
    └── kite/          9 shared modules
```

Copy the `automation` folder onto `%APPDATA%\Aegisub\automation`, merging the contents. Its two folders can also be copied separately:

| Repository source | Aegisub destination |
| --- | --- |
| `automation/autoload/` | `%APPDATA%\Aegisub\automation\autoload\` |
| `automation/include/kite/` | `%APPDATA%\Aegisub\automation\include\kite\` |

For a partial installation, keep only the scripts needed in the copied `autoload` folder and retain the complete `include/kite` folder. Copy `.moon` files as supplied. Libraries from `include` do not belong in `autoload`.

When updating, replace Kite scripts and modules together. Remove older copies of those same macros to avoid duplicate registrations, then restart Aegisub or rescan Automation. Preserve other libraries already present in `include`.

The Kite feed supports installation and updates of the macros and their modules through DependencyControl:

```text
https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json
```

### 5. External programs and shared backend

| Program | Use |
| --- | --- |
| Private 64-bit Python and Python libraries | Fansub Automatons prepares them for Auto Drawing, Auto Mask, Auto Motion and Auto Timing audio processing. |
| FFmpeg and FFprobe | Media processing in Hephaestus and exports from Moka Motion and Kiri-Shot. FFprobe reads tracks and metadata. ASS rendering needs libass; H.264 export needs libx264. |
| SCXvid | **Hephaestus Fansubber → Automatons → Auto Timing → Keyframes**, together with FFmpeg. The installer downloads and verifies the executable. |
| x264 | Optional alternative in **Moka Motion → Create Video Clip**. |

For the Autos, open **Hephaestus Fansubber → Install → All automatons**, or select one tool. Then run **Check → All automatons**. Auto Blur analyzes frames inside Aegisub and requires its video API.

Integrated installation downloads the latest compatible stable [Fansub Automatons release](https://github.com/Kiterowx/Fansub-Automatons/releases), verifies the ZIP and its SHA-256, and prepares the runtime. It requires backend version **1.2.1** or later. **Configure** selects the installation folder and the `auto`, `cpu` or `cuda` device.

The installer uses Windows x64. A new environment requires **6 GiB free for CPU** or **14 GiB for CUDA**; these thresholds include a **2 GiB** reserve. Models and working media need additional space. Compatible components are verified and reused. See [Fansub Automatons installation and recovery](docs/FansubAutomatons.md).

To install from a package, download and extract the Fansub Automatons distribution and run `Install.cmd`. Choose the same installation folder when updating to reuse the runtime.

Moka Motion and Kiri-Shot let you select FFmpeg in their settings. You can also add it to `PATH`; restart Aegisub after changing that variable. Windows uses PowerShell to supervise external processes. Auto Drawing can convert images without FFmpeg.

### Updating scripts and modules

I distribute **seven common modules** —Core, UI, PyBridge, AssContext, ShapeOptimizer, EventOps and Timing— plus **Automatons** and **MotionEngine**. Update macros and all nine modules together. The [dependency reference](docs/Dependencies.md#included-modules) covers their versions, responsibilities and migration.

Keep replaced versions outside active Automation paths and retain one active copy of each macro. Preserve third-party libraries and modules used by other projects. The [Hephaestus](docs/Hephaestus.md), [Kiri-Shot](docs/KiriShot.md) and [Selesub](docs/Selesub.md#assign-fields-with-fields) guides explain migration of their integrated functions.

## Finding dependencies in the source

Open a `.lua` or `.moon` file in a text editor. Its `DependencyControl` block is usually near the beginning and lists module identifiers and minimum versions. Search for `require`, `requireModules` and `include` as well. For example, `a-mo.LineCollection` is installed as **LineCollection**, even though its identifier and filename differ.

In [DependencyControl.json](DependencyControl.json), each script declares `requiredModules`. Follow any `kite.*` entry into `modules` to inspect its dependencies. Third-party libraries can require further modules too. A load wrapped in `pcall` may belong to an optional feature; check the script's guide before installing it. These declarations do not need editing to install a dependency.

## Installation problems

| Symptom | Checks |
| --- | --- |
| DependencyControl is missing | Use the release ZIP, check the user directory and inspect Automation's load errors. Avoid extra nested folders and old Toolbox copies in another autoload path. |
| **Bad DependencyControl record** | Update to the complete 0.9.1 package and reload. If it persists, retain the full error: the issue fixed in this release is not the only possible cause. |
| `module '…' not found`, or a macro is missing | Find the identifier in the table, install its module and check `include/kite`. Check Yutils and Aegisub's bundled libraries separately. |
| A module is absent from **Modules:** | Check whether it is already installed, whether its feed is added and enabled, and whether a trust prompt or network error is pending. Make sure the selector is **Modules:**, not **Automation Scripts:**. |
| HTTP, TLS or download error | Check the connection, proxy, antivirus and access to the feed named in the error. DependencyControl's logs are in the Aegisub profile's `log` folder. |
| DLL, FFI or native-library load error | Check compatibility with the Aegisub version and architecture. Reinstall the appropriate complete package; renaming a DLL does not resolve an architecture mismatch. |
| Missing function in `kite.UI` or another Kite module | Update all nine modules under `include/kite` too. Copying only the macro can mix incompatible versions. |
| Duplicate Automation entries | Check the configured autoload paths for copies of the same macro. Keep one active copy. |
| A backend works in a terminal but fails in Aegisub | Check the shared installation folder in **Hephaestus Fansubber → Configure**, run **Check** and retain its diagnostics. |
| FFmpeg, FFprobe or SCXvid cannot be found | Check the configured executable or `PATH`, then restart Aegisub after changes. Lua module installation does not install these programs. |

## Startup, memory and cache

Each `autoload` macro loads when Aegisub starts or rescans Automation. Aegisub creates a Lua environment per script, so libraries used by several macros can be loaded into several environments. Time and memory use depend on the installed set and the computer; there is no fixed cost per file.

To reduce loading, keep only the required macros in `autoload`. Others can be stored outside every configured autoload path. Keep the modules needed by active macros: placing a library in `include` does not make it an independently running macro.

With the default settings, DependencyControl caches downloaded catalogs under `%APPDATA%\Aegisub\cache\l0.DependencyControl\feeds`. This avoids repeated downloads; clearing it at every startup can cause more network activity. Initial feed discovery, an update or a slow connection can add waiting time. This cache is separate from Aegisub's audio/video cache and Auto Mask's downloaded models.

Update policy is stored in `%APPDATA%\Aegisub\config\l0.DependencyControl.json`. For `updates.mode`, `auto-update` allows automatic checks; `dependency-resolution` installs required dependencies without scheduled checks; `user-requested` limits activity to explicit Toolbox actions. The last mode requires missing dependencies to be installed manually. `off` prevents installation too. See [DependencyControl's configuration documentation](https://github.com/TypesettingTools/DependencyControl/blob/v0.9.1/README.md#configuration) for the settings and their effects.

## Support

Questions can be posted in the [support Discord](https://discord.gg/Egq8us4xZC). For errors, include the macro name and version, the Aegisub build, the full message and the steps that reproduce it.

## Links

- [Catalog site](https://kiterowx.github.io/Kite-Aegisub-Scripts-Guide/)
- [Chrono Generators](https://github.com/Kiterowx/Chrono-Generators-Scripts)
- [Timing guide](https://kiterowx.github.io/Arquitectura-del-Timing/)

## Documentation

Individual guides are linked in the [script catalog](#scripts). The [dependency guide](docs/Dependencies.md) lists the modules required by each script.

## License

MIT. See [LICENSE](LICENSE).
