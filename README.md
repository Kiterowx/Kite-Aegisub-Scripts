# Kite Aegisub Scripts

English | [Español](README.es.md)

Aegisub tools for typesetting, text editing, timing and karaoke. Each script can be installed separately with its dependencies.

## Scripts

Scripts are grouped by their main use. Each name links to its guide; follow the [installation steps](#installation) to prepare the requirements.

### Text and selection

| Script | Use | Interface |
| --- | --- | --- |
| [Selesub 2.1.9](docs/Selesub.md) | Filter and select lines, including adjacent lines with matching visible text. | English |
| [Field Group Manager 1.1.8](docs/FieldGroupManager.md) | Map groups of lines to values in Actor, Style, Layer and other fields. | English |

### Timing and audio

| Script | Use | Interface |
| --- | --- | --- |
| [Chrono Suite 1.6.1](docs/ChronoSuite.md) | Timing, line merging and cleanup, smart splitting and karaoke timing tools. | English, Spanish, Portuguese |
| [Wave2json 1.3.6](docs/Wave2json.md) | Export audio waveforms for Auto Timing and Smart Split. | No GUI |
| [Pointiac 1.1.7](docs/Pointiac.md) | Generate markers at the first and last visible frames of a line. | English |

### Sign placement and motion

| Script | Use | Interface |
| --- | --- | --- |
| [Rhea Signs 2.2.1](docs/RheaSigns.md) | Edit tags, build signs, position elements and work with drawings. | English, Spanish, Portuguese |
| [Allure 1.2.5](docs/Allure.md) | Save reusable styling presets and pose signs around a chosen pivot. | English, Spanish |
| [Moka Motion 3.7.6](docs/MokaMotion.md) | Apply tracking, perspective and motion to signs. | English |

### Drawings, textures and masks

| Script | Use | Interface |
| --- | --- | --- |
| [AddTexture 2.1.8](docs/AddTexture.md) | Clip pasted ASS drawing textures to text outlines. | English |
| [Cliptomaniac 0.4.5](docs/Cliptomaniac.md) | Edit and transform vector clips. | English, Spanish |
| [AutoMask 2.5.6](docs/AutoMask.md) | Reconstruct backgrounds and create masks from video frames. | English |
| [PNG2ASS 1.7.1](docs/PNG2ASS.md) | Convert images into ASS drawings. | English |

### Color and animation

| Script | Use | Interface |
| --- | --- | --- |
| [Obake 0.4.5](docs/Obake.md) | Build transform chains, animation presets and transitions between visual states. | English, Spanish |
| [Gradient Row 1.8.9](docs/GradientRow.md) | Apply color gradients across lines or text. | English |
| [Zheus Colormanager 4.7.4](docs/Zheus.md) | Edit palettes, gradients and color effects. | Spanish |
| [AutoBlur 2.1.4](docs/AutoBlur.md) | Calculate blur adjustments from loaded video. | English |
| [Zagreo Glyphs 1.2.4](docs/ZagreoGlyphs.md) | Generate and animate vector glyphs and shapes. | English |

### Karaoke

| Script | Use | Interface |
| --- | --- | --- |
| [Alecto KFX 3.4.3](docs/AlectoKFX.md) | Generate effects from intro, active and outro guides. | Spanish |
| [Macaria Revert 1.0.2](docs/MacariaRevert.md) | Reconstruct source karaoke from generated lines. | English |

### Capture and export

| Script | Use | Interface |
| --- | --- | --- |
| [Snapshoter 1.6.8](docs/Snapshoter.md) | Export subtitle snapshots and video clips. | English |
| [Social Clip 1.0.3](docs/SocialClip.md) | Prepare video excerpts for social platforms. | Spanish |

### Keyboard workflow

| Script | Use | Interface |
| --- | --- | --- |
| [Hotkeys 2.0.2](docs/Hotkeys.md) | Edit shortcuts, migrate bindings and manage shared preferences. | English |

## Installation

Install in this order: **Aegisub and DependencyControl → environment libraries → third-party modules → Kite scripts and modules → external programs for the features needed**. Third-party modules must be installed before copying scripts into `autoload`; a missing dependency can prevent a macro from appearing in the menu.

### 1. Aegisub and DependencyControl

The recommended build is [arch1t3cht's Aegisub — Migration Release 04](https://github.com/arch1t3cht/Aegisub/releases/tag/migration04-01), based on [TypesettingTools/Aegisub](https://github.com/TypesettingTools/Aegisub). AutoBlur uses video functions from arch1t3cht's build. Keep the Automation folders and libraries supplied with Aegisub.

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
| [Yutils](https://github.com/Youka/Yutils) | Required by Zagreo Glyphs and **ZF main**, used by AddTexture, Cliptomaniac, Moka Motion and PNG2ASS; also used by ASSFoundation curve operations. If missing, copy [src/Yutils.lua](https://github.com/Youka/Yutils/blob/T1/src/Yutils.lua) to `automation/include/Yutils.lua`. Not every Aegisub build includes it. It requires LuaJIT; libpng is only needed for its PNG reader. |
| [LuaJSON](https://github.com/harningt/luajson) (`json`) | Required by Aegisub-Motion's **Line** and by Chrono's Smart Split for waveform reading. If missing, copy `json.lua` and the `json` folder from the project's [lua directory](https://github.com/harningt/luajson/tree/master/lua) into `automation/include`. It needs LPeg (`lpeg`), supplied by the Lua environment of the recommended builds. Keep the complete `json` folder: dkjson does not provide the same API. |
| Fonts | Must be available to Aegisub and to the renderer used for exports. |
| VSFilterMod | Zheus four-corner gradients require a renderer that supports those extensions. Installing a Lua module does not add that support to libass. |

### 3. Third-party modules from DependencyControl

Open **DependencyControl → Install Script** and use the **Modules:** dropdown. **Automation Scripts:** is a separate selector for macros. Entries normally show a version after the module name and may also show a channel.

Install **aka.command**, a shared dependency of the Kite modules. Then install the modules for the chosen scripts using the [per-script table](docs/Dependencies.md#dependencies-by-script). **dkjson** is bundled with DependencyControl and is explicitly declared by Allure. One macro does not require every library in this catalog.

| Name in **Modules** | Identifier in code | Source catalog |
| --- | --- | --- |
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

For example, `l0.Functional` is listed as **(Almost) Functional Suite**, and `myaa.ASSParser` as **ASS Parser**. **ArchMath** is `arch.Math`, not Aegisub-Motion's **Math** module.

If a catalog is missing, add its **feed** link through **Manage Feeds**, review any trust prompt and refresh the list. Already installed modules may be absent from the installation dropdown; check DependencyControl's update options instead. Dependencies of these libraries are resolved from their own feeds. Installing the Aegisub-Motion macro is not necessary just to obtain **LineCollection**, for example.

The table also includes indirect dependencies: **petzkuLib** installs with **aka.command**; **polyclipping**, **zimg** and **requireffi** with **ZF main**; **Transform** with **Line**. **DataWrapper** is only needed for AutoBlur tracking and adds **DataHandler** and **ShakeShapeHandler**. **SubInspector** is an **ASSFoundation** dependency, even though not all its functions use it.

### 4. Copy the Automation folder

The [repository](https://github.com/Kiterowx/Kite-Aegisub-Scripts) has one installation tree:

```text
automation/
├── autoload/           22 public scripts (.lua and .moon)
└── include/
    └── kite/          12 shared modules
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

### 5. External programs by feature

These programs are installed outside DependencyControl and are only needed for the features listed.

| Program | Use |
| --- | --- |
| 64-bit [Python](https://www.python.org/downloads/) 3.10 or newer, with pip | AutoMask and PNG2ASS backends. |
| [Git](https://git-scm.com/downloads), available on `PATH` | Installing or updating those backends from GitHub. |
| [FFmpeg and FFprobe](https://ffmpeg.org/download.html) | AutoMask, Wave2json, Chrono's Scream Detector and exports from Moka Motion, Snapshoter and Social Clip. FFprobe reads tracks and metadata. ASS rendering and H.264 export need a build with libass and libx264. |
| SCXvid command-line executable | **Chrono Suite/Extract KF**, together with FFmpeg. Set both paths under **Chrono Suite/Config → SCXvid**. |
| x264 command-line executable | Optional alternative in **Moka Motion/Create Video Clip**. |

Add FFmpeg to `PATH` or select it in the script settings. Restart Aegisub after changing `PATH`. On Windows, keep PowerShell available for external processes. Wave2json does not need Python; PNG2ASS does not need FFmpeg to convert images.

### Python backends

For AutoMask or PNG2ASS:

1. Select the Python interpreter under **AutoMask/Backend/Configure** or **PNG2ASS/Backend/Configure**.
2. Run **Backend/Install or Update**, followed by **Backend/Check**.
3. For EfficientSAM and LaMa, also run **AutoMask/Backend/Install Models**. Gradient reconstruction works without those models.

The installer supplies OpenCV and the other Python libraries. AutoMask also installs PNG2ASS; FFmpeg and SCXvid are installed separately. Terminal installation is available with these commands, using only the backend needed:

```text
python -m pip install --upgrade "git+https://github.com/Kiterowx/kite-png2ass.git"
python -m pip install --upgrade "git+https://github.com/Kiterowx/kite-automask.git"
```

The terminal must use the same Python interpreter selected in Aegisub. See the [dependency guide](docs/Dependencies.md) for details.

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
| Missing function in `kite.UI` or another Kite module | Update all 12 modules under `include/kite` too. Copying only the macro can mix incompatible versions. |
| Duplicate Automation entries | Check the configured autoload paths for copies of the same macro. Keep one active copy. |
| A backend works in a terminal but fails in Aegisub | Compare interpreter paths, run **Backend/Check** and confirm that pip installed into that same Python environment. |
| FFmpeg, FFprobe or SCXvid cannot be found | Check the configured executable or `PATH`, then restart Aegisub after changes. Lua module installation does not install these programs. |

## Startup, memory and cache

Each `autoload` macro loads when Aegisub starts or rescans Automation. Aegisub creates a Lua environment per script, so libraries used by several macros can be loaded into several environments. Time and memory use depend on the installed set and the computer; there is no fixed cost per file.

To reduce loading, keep only the required macros in `autoload`. Others can be stored outside every configured autoload path. Keep the modules needed by active macros: placing a library in `include` does not make it an independently running macro.

With the default settings, DependencyControl caches downloaded catalogs under `%APPDATA%\Aegisub\cache\l0.DependencyControl\feeds`. This avoids repeated downloads; clearing it at every startup can cause more network activity. Initial feed discovery, an update or a slow connection can add waiting time. This cache is separate from Aegisub's audio/video cache and AutoMask's downloaded models.

Update policy is stored in `%APPDATA%\Aegisub\config\l0.DependencyControl.json`. For `updates.mode`, `auto-update` allows automatic checks; `dependency-resolution` installs required dependencies without scheduled checks; `user-requested` limits activity to explicit Toolbox actions. The last mode requires missing dependencies to be installed manually. `off` prevents installation too. See [DependencyControl's configuration documentation](https://github.com/TypesettingTools/DependencyControl/blob/v0.9.1/README.md#configuration) for the settings and their effects.

## Support

Questions can be posted in the [support Discord](https://discord.gg/Egq8us4xZC). For errors, include the macro name and version, the Aegisub build, the full message and the steps that reproduce it.

## Links

- [Catalog site](https://kiterowx.github.io/Kite-Aegisub-Scripts-Guide/)
- [Chrono Generators](https://github.com/Kiterowx/Chrono-Generators-Scripts)
- [Timing guide](https://kiterowx.github.io/Arquitectura-del-Timing/)

## Documentation

Individual guides are linked in the [catalog by function](#scripts). The [dependency guide](docs/Dependencies.md) lists the modules required by each script.

## License

MIT. See [LICENSE](LICENSE).
