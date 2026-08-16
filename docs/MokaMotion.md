# Moka Motion 3.6.1

Moka Motion unifies Mocha transform, mask, clip, perspective, frame-by-frame track, PNG sequence, and video-trim workflows.

Menu root: `Moka Motion`

Namespace: `kite.MokaMotion`

## Main areas

- Apply or invert Mocha Transform data.
- Convert AE Mask Shape, legacy Bezier, or Shake SSF data to `\clip`, `\iclip`, or ASS drawings.
- Apply CC Power Pin and Corner Pin perspective data.
- Analyze, denoise, repair, and retarget frame-by-frame tracks.
- Merge consecutive compatible FBF states with exact, conservative, or subpixel comparison while protecting duration-dependent tags.
- Create shape, clip, inverted-clip, and ASS drawing output from supported mask formats.
- Inspect supported tracking exports.

## Media export

- `Moka Motion/Utilities/Create Video Clip` creates and verifies a frame-exact H.264 MP4. It prefers FFmpeg/libx264 and can fall back to external x264.
- `Moka Motion/Utilities/Create Exact PNG Sequence` exports verified frame-indexed PNG files.
- `Moka Motion/Utilities/Trim Settings` stores x264 and FFmpeg paths through Kite UI. Blank fields use `PATH`.

The video route validates the exact decoded frame count before accepting the output. Temporary and partial files are retained when an external stage fails so the diagnostic remains inspectable.

## Subtitle operations

`kite.Media` supplies media paths, timecodes, and frame windows. `kite.LineOps` handles selection, visible text, positions, transactions, and insertion results. `kite.PyBridge` runs x264 and FFmpeg and retains diagnostic output when an external stage fails.

Each application uses the tracking or mask data supplied for that run. Reapplication and inversion do not depend on hidden data in `line.extra` or a single global cache entry.
