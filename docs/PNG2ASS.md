# PNG2ASS 1.4.1

PNG2ASS converts images and SVG files into ASS drawing lines through the `kite-png2ass` Python package.

Menu root: `PNG2ASS`

Namespace: `kite.PNG2ASS`

## Entries

- `PNG2ASS`
- `PNG2ASS/Backend/Check`
- `PNG2ASS/Backend/Install or Update`
- `PNG2ASS/Backend/Configure`

Every command in this submenu can be assigned directly as a hotkey in Aegisub.

## Image conversion

PNG2ASS supports single-image conversion and multi-image frame sequences. For sequences, select one or more timed dialogue lines and the same number of image files as covered frames. The macro maps one image to one frame and writes frame-by-frame ASS drawing lines.

Accepted input: `.png`, `.jpg`, `.jpeg`, `.webp`, `.bmp`, `.tif`, `.tiff`, `.gif`, `.tga` and `.svg`. SVG files skip tracing and are converted directly.

The default mode is `auto`. It can detect alpha images, white-on-black mattes, dark-on-light mattes, and color images. Use `white-matte` explicitly for Mocha-style mattes where white is the visible shape and black is transparent.

Photographic sources carry compression noise that fragments the traced palette. Set `Denoise` to 1 to apply a median filter before tracing.

## Budgets

- `Max chars` guards the responsiveness of the subtitle grid.
- `Max pixels` guards tracing time on very large sources; the default accepts 4K and above.
- The line budget is enforced by the package and can be accepted from the warning dialog.

The backend checks image dimensions before full decoding, rejects unexpected multiframe input, limits input-list rows and output size, and reports observable line, character, contour, point, and dimension counts rather than a fixed rendering-time estimate.

## External package

The global backend check reports the installed version and the version advertised by the configured source. If the package is missing, incomplete, or outdated, it offers the relevant install, repair, or update action. The default package source is `git+https://github.com/Kiterowx/kite-png2ass.git`.

The package is installed as `kite-png2ass` and invoked as:

```bat
python -m ass_png2ass
```

## Configuration

Settings persist by namespace in `?user/config/kite.settings.json`. An existing `kite.PNG2ASS.conf` in the Aegisub user directory is imported once on first read.

Relative paths in an input list are resolved from the list file. Quantization is deterministic, and output files are written through a temporary file and atomic replacement. The macro uses `kite.LineOps` for selection and insertion results and `kite.PyBridge` for Python and process execution.
