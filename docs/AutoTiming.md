# Auto Timing

Part of [Hephaestus Fansubber](Hephaestus.md) **1.2.1**. Open **Hephaestus Fansubber → Automatons → Auto Timing** for timing, audio preparation, Scream Detector, SCXvid and waveform export.

| Entry | Purpose |
| --- | --- |
| Timing | Adjust dialogue with Lazy, Busy or Legacy. |
| Scream Detector | Mark relatively loud intervals for review. |
| Audio → Isolator | Separate vocals while retaining the complete timeline. |
| Audio → Signals | Generate timing data from synchronized isolated vocals. |
| Audio → Complete | Separate vocals and generate signals, with optional video for keyframes. |
| Keyframes | Extract an SCXvid log from a chosen video. |
| Waveform | Export full audio, the selected span or each selected line. |
| Settings | Choose the language and keyframe filename suffix. |

## Prepare the audio

Use **Hephaestus Fansubber → Install → Auto Timing**, then **Check → Auto Timing**. These operations share the suite's runtime and media tools.

1. Open **Audio → Isolator** and choose the input audio or video and output folder.
2. Select **quality** (BS-RoFormer) or **fast** (MDX-Net), with `opus` or `wav` output. The first use can download the profile's model.
3. Run **Audio → Signals** on the isolated vocals. Preserve the original start and silent intervals so the data remains synchronized.
4. Load the waveform JSON in Lazy or select the signal files in **Busy Files...**.

**Audio → Complete** performs separation and signal generation together. **Video for keyframes (optional)** adds SCXvid processing. **Replace existing generated files** enables replacement of previous results; check the destination before running a long job.

Signals produces `*_Retimes_30.txt`, `*_Retimes_40.txt` and `*_Retimes_50.txt` silence logs, `*_Retimes_vad.tsv`, `*_Retimes_flux.tsv`, `*_Retimes_spectrum.tsv`, `*.waveform.json` and `*_envelope.tsv`. Names follow the processed input. Listen to difficult boundaries: separation may retain music or remove part of a voice.

## Timing

Auto Timing has two main methods, plus a separate Legacy path. Every control lives in this window and persists in the Auto Timing configuration.

- **Method:**
- Lazy: reads spoken activity from a peaks JSON.
- Busy: combines silence, VAD, flux, RMS envelope, and optional waveform data. It requires the bundled `kite.Timing` module.
- **Mode for Lazy and Busy:**
- Full + polish: detect the voice, then pad, chain, and snap to video keyframes.
- Raw voice: move each line onto the detected voice start/end with no padding.
- Post current: keep the current in/out and only run the final padding, chaining, and video-keyframe pass.
- **Waveform JSON:** a peaks file (min/max samples). Type a path or pick one with Browse...; it is cached for the session, and Reload waveform cache forces a fresh read.
- Keyframes come from the loaded video, the same way the audit markers read them. Full + polish and Post current need them; Raw voice does not.
- Busy Files... opens only the file inputs used by Busy. If Busy is processed without a JSON or Busy files, this window opens first.
- Legacy... opens the Legacy method selector and silence files. Legacy aligns line edges to silence clusters, does not use video keyframes, and writes [LZ ...] tags.
- **Style filter:** All, All Default, Default+Alt, or an exact style, plus a second exact style in the extra box.
- Problem lines are marked in Effect with [TM-...] markers (no voice, weak match, overlap, short, fast CPS), cleaned on the next run.

## Detection and margins

Lazy smooths the peak envelope, thresholds it, cleans the mask, and keeps the speech span each line is then padded around. Busy reuses the same final margins on its combined match.

- **Search ± (ms):** how far beyond the line's own in/out to look for the voice (0 = stay inside the line).
- **Smoothing (ms):** width of the envelope smoothing window.
- **Auto threshold (Otsu):** choose the speech/silence cut automatically; off falls back to a percentile sensitivity.
- **Bridge gaps / Drop islands (ms):** close micro-silences and discard micro-blips before the span is measured.
- **Trim small edge spill:** drop a faint, well-separated blip stuck to a line edge so it does not stretch the timing.
- **Margins · post-timing:** lead-in / lead-out, chain max out / in, KF snap end / start, voice-cut limit, duration floor, and the CPS flag — the default criteria that shape how the raw span becomes the final in/out.

## Keyframes

Choose the input video and output folder. FFmpeg decodes the video and SCXvid creates the log. Load that log in Aegisub before using modes that snap to keyframes. **Settings** controls the filename suffix, initially `_keyframes.log`.

**After Effects Keyframes**, for motion data, is available in [Rhea Signs](RheaSigns.md#after-effects-keyframes).

## Scream Detector

Audio-level review tool. Runs FFmpeg astats on the loaded audio/video and writes the [SCREAM] marker to lines whose interval is statistically loud relative to the rest of the analysed set.

- **Average line dB:** mean power inside each subtitle interval. Closer to 0 is stricter.
- **Strong sample dB:** samples above this value count as strong evidence.
- **Strong sample ratio (%):** minimum percent of strong samples per interval.
- **Minimum samples:** ignores lines with too little audio evidence.
- **Robust z-score:** compares each line against the median/MAD of the analysed set.
- **Apply to:** All dialogue or Selected lines only.
- **Clear previous SCREAM marks:** removes earlier [SCREAM] in scope before writing new ones.
- **Reuse existing analysis log:** skips FFmpeg if a previous log exists. Useful for recalibration.

## Waveform

| Command | Output |
| --- | --- |
| Full audio | The complete active audio. |
| Selected span | Earliest selected start to latest selected end, including gaps. |
| Each selected line | One file per selected dialogue. |

The exporter uses the loaded audio or the video's audio and the shared FFmpeg configuration. JSON files are written beside the ASS, or beside the media for an unsaved project. Full export uses `Project.waveform.json`; partial exports add their time range.

Each successful export replaces a previous file with the same name. With **Each selected line**, completed files remain if a later line fails.

Audio is decoded as mono, 48 kHz, 16-bit PCM. The base level stores one minimum/maximum pair for each millisecond; further levels combine neighbouring pairs. `sourceStartMs` places a partial export on the original timeline. Timing and Chrono's Smart Split respect this offset.

`peaks` contains integer min/max pairs and `pointMs` must be positive and finite. Amplitude helps locate activity; identifying speech content requires listening.

For lines at 10.0–11.5 s and 12.0–13.0 s, **Selected span** exports 10.0–13.0 s including the gap. **Each selected line** creates two independent files with their own offsets.

## Settings and review

Timing keeps its source, method, detection and margin settings. Scream Detector stores its own criteria. Recognized settings migrate once from Chrono. **Settings** offers English, Spanish and Portuguese and the keyframe suffix.

Start with **Raw voice** on a short section and listen to its boundaries. Adjust the search range and thresholds, then use **Full + polish** for margins, chaining and keyframe snapping. `[TM-...]` and `[SCREAM]` markers identify intervals for review.

## Timing validation

Before applying timing, the tool checks prospective later overlaps, including cases involving more than three rows. Originally overlapping lines retain their specific handling. The waveform reader rejects incomplete pairs and invalid amplitudes; `pointMs` accepts complete scientific notation and must be positive and finite.
