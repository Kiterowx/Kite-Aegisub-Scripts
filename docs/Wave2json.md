# Wave2json 1.3.2

Wave2json exports the active audio waveform to JSON.

Menu root: `Wave2json`

The `Wave2json` entry itself can be assigned as a hotkey in Aegisub.

Namespace: `kite.Wave2json`

Wave2json registers direct no-dialog entries for the full audio, the selected span, and each selected line.

## Behavior

- Uses the active audio file from the current Aegisub project.
- Assumes `ffmpeg` is available from PATH.
- Exports the complete active audio, the combined selected time span, or one file per selected dialogue line.
- Writes the JSON beside the script file when possible, otherwise beside the audio file.
- Uses atomic output replacement and always removes decoded PCM and pyramid-level temporary files after success, cancellation, or failure.

## Output

The exporter decodes mono 48 kHz PCM through FFmpeg and streams waveform pyramid data to JSON without retaining every level in memory.

## Requirements

Wave2json requires a loaded audio file, FFmpeg, `kite.PyBridge` 1.4.4, and `kite.LineOps` 1.5.2.
