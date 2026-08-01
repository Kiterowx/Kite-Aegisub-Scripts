# Moka Motion 3.4.0

Moka Motion unifies Mocha transform, mask, clip, perspective, frame-by-frame track, PNG sequence, and video-trim workflows.

Menu root: `Moka Motion`

Namespace: `kite.MokaMotion`

## Main areas

- Apply or invert Mocha Transform data.
- Convert AE Mask Shape, legacy Bezier, or Shake SSF data to `\clip`, `\iclip`, or ASS drawings.
- Apply CC Power Pin and Corner Pin perspective data.
- Analyze, denoise, repair, and retarget frame-by-frame tracks.
- Create shape, clip, inverted-clip, and ASS drawing output from supported mask formats.
- Inspect supported tracking exports.

## Media export

- `Moka Motion/Utilities/Create Video Clip` encodes the selected frame interval to an MKV with x264 and remuxes it to MP4 with FFmpeg.
- `Moka Motion/Utilities/Create Exact PNG Sequence` exports verified frame-indexed PNG files.
- `Moka Motion/Utilities/Trim Settings` stores x264 and FFmpeg paths through Kite UI. Blank fields use `PATH`.

The video route preserves x264 B-frames and uses a separate `.lavf.index`. A verified CFR source passes its detected rate to the encoder; a VFR source keeps the demuxer timestamps without forcing `24000/1001`. The intermediate MKV is removed only after a successful remux.

## Subtitle operations

`kite.Media` supplies media paths, timecodes, and frame windows. `kite.LineOps` handles selection, visible text, positions, transactions, and insertion results. `kite.PyBridge` runs x264 and FFmpeg and retains diagnostic output when an external stage fails.

Each application uses the tracking or mask data supplied for that run. Reapplication and inversion do not depend on hidden data in `line.extra` or a single global cache entry.
