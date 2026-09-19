# Wave2json 1.3.6

English | [Español](es/Wave2json.md) | [Index](../README.md#documentation)

Wave2json exports the audio waveform as a JSON pyramid: a detailed series of minimum/maximum amplitudes plus progressively coarser levels. It reads PCM and writes temporary level files incrementally, so it does not hold the complete audio or every waveform level in memory.

The script is distributed from `Macros-Lite` and registers three direct actions under **Wave2json**. There is no configuration dialog. Assign hotkeys to the individual actions listed below; the menu root is not an executable action.

## Actions

| Action | Export |
| --- | --- |
| Full audio | The complete active audio source. |
| Selected span | One continuous interval from the earliest selected start to the latest selected end, including any gaps between selected lines. |
| Each selected line | One JSON file for every selected dialogue, in subtitle order. Overlapping lines remain separate exports. |

The active audio file takes priority. If no separate audio file is available, the active video's audio is used. A real source file must exist. FFmpeg is resolved from PATH and the direct actions decode its first audio stream, indexed as `0:a:0`.

Selected actions require only uncommented dialogue lines with finite, positive timing. Duplicate indices are removed; invalid rows are reported. A negative start is clipped to zero. A line that becomes empty after this adjustment or millisecond rounding is rejected, so an empty selection interval cannot accidentally request the full audio.

## Output paths

Files are written beside the saved ASS when its path is available, otherwise beside the audio/video source. The default name is based on the ASS filename, falling back to the media filename.

- Full audio: `Project.waveform.json`.
- Selected span: `Project_1200-2800ms.waveform.json`.
- Each selected line: `Project_1200-2800ms_line001_1200-2800ms.waveform.json`, followed by `line002`, etc. The shared prefix comes from the first selected line; the final range suffix always describes the individual file.

Filename characters that Windows cannot use are normalized. Reserved device names are recognized even before a filename extension. Existing output files are replaced atomically after the new JSON has been written successfully; these direct actions do not display an overwrite dialog.

## Audio and timing

FFmpeg decodes mono, 48 kHz, signed 16-bit little-endian PCM. Stereo and multichannel sources are mixed down by FFmpeg. The waveform therefore describes that mono decode, not a separate amplitude series for each original channel.

Selected ranges use precise output seeking after decoder initialization. This preserves the samples at the requested time in compressed audio such as AAC. A late selection in a long file can consequently require decoding preceding audio. Decoding is cancellable through the shared process supervisor.

The base level contains one min/max pair per 48 samples, corresponding to 1 ms. A final group containing fewer than 48 samples is retained. Each additional level combines adjacent pairs by taking their smallest minimum and largest maximum, continuing until the coarsest level has one point. Odd final points are carried into the next level without dropping the tail.

`durationMs` is calculated from the actual decoded sample count, including fractions of a millisecond. It is written with up to six decimal places. It can differ from a requested range when the source ends early; the source range metadata records what was requested, and `totalSamples` records what was actually decoded.

## JSON format

The schema remains **version 1**.

```json
{
  "type": "waveform",
  "version": 1,
  "sampleRate": 48000,
  "channels": 1,
  "bits": 16,
  "amplitudeFormat": "s16",
  "amplitudeMin": -32768,
  "amplitudeMax": 32767,
  "pointLayout": "interleavedMinMax",
  "durationMs": 2,
  "totalSamples": 96,
  "levels": [
    {
      "scale": 1,
      "pointMs": 1,
      "samplesPerPoint": 48,
      "points": 2,
      "peaks": [-100, 200, -300, 400]
    },
    {
      "scale": 2,
      "pointMs": 2,
      "samplesPerPoint": 96,
      "points": 1,
      "peaks": [-300, 400]
    }
  ]
}
```

For selected exports, the document also includes `sourceStartMs`, `sourceEndMs`, `sourceDurationMs` and `sourceLineCount`. The peak array is flat: minimum, maximum, minimum, maximum. Its length must be twice the level's `points` value. `samplesPerPoint` describes a complete group; the final group may be shorter.

An empty decode, an odd PCM byte count, a read error, a changed PCM size or an incomplete temporary level fails the export. These conditions are not accepted as normal end-of-file.

## Cancellation and errors

`kite.PyBridge.runProcess` runs FFmpeg without a visible console window on Windows, monitors cancellation and collects its diagnostic. Decoding cancellation is reported as cancellation rather than an audio decoding failure.

PCM and level files are removed after success, cancellation or failure. JSON is assembled in bounded batches, with cancellation checks during both analysis and output. A failed write leaves an existing JSON untouched. For **Each selected line**, completed earlier files remain available if a later line fails; the message identifies the failed line.

No maximum duration, point count or number of pyramid levels is imposed. Disk space, processing time, filesystem limits and available FFmpeg codecs remain practical constraints. Peak aggregation preserves amplitude extrema; it is not RMS loudness or a frequency spectrum.
