# AutoBlur 2.1.4

English | [Español](es/AutoBlur.md) | [Index](../README.md#documentation)

AutoBlur estimates changing background sharpness over one dialogue event and writes an ASS blur curve. Open **AutoBlur** or assign that macro as a hotkey.

## Workflow

1. Load the video and select one dialogue line with positive duration.
2. Move the video playhead inside that line. This frame establishes the tracking reference.
3. Choose a textured background point near the sign, avoiding the subtitle itself, scene cuts and unrelated moving objects.
4. Set the sampling and curve controls, then execute. The line remains selected. A read or sampling failure leaves it unchanged.

The suggested point comes from the first static vector clip pin, an explicit position/move at the current time, clipboard coordinates, or style alignment and margins. Clips inside transforms and text inside ASS comments are not treated as static pins. The point uses script coordinates, converted to video coordinates for sampling. Review the suggestion: a style anchor is not automatically a useful background sample.

## Tracking

Enable **Use tracking data** and paste an After Effects Position export supported by `a-mo.DataWrapper`. The data must cover exactly the selected event's frame interval. Offsets are relative to the current video frame, so the chosen sample coordinate is the tracked point at that reference frame. Empty data, unusable channels or mismatched lengths are rejected. Without tracking, the same background coordinate is sampled throughout the event.

## Controls

| Control | Meaning |
| --- | --- |
| Patch radius | Radius in video pixels for five nearby sample patches; minimum 2 provides enough Laplacian samples. |
| Max blur | Upper bound for the generated ASS blur, including after quantization. Zero produces zero blur. |
| Curve exponent | Positive exponent controlling response to relative sharpness. |
| Quant step | Blur level spacing; 0 disables quantization. |
| Smooth window | Moving average window in frames; 1 disables smoothing. |
| Min run | Suppresses short level runs in Discrete mode; 1 keeps them. |
| Transition | Interpolation duration in milliseconds around a level change; 0 writes a one-millisecond step. |
| Mode | Continuous keeps each quantized change; Discrete first suppresses short runs. Equal consecutive values share the same transform builder. |

Larger patches require more processing and memory; sampling checks cancellation between patch rows. Invalid coordinates, invalid controls or an empty enabled tracking input return to the draft without discarding other edited values. Closing the window cancels.

## Sampling and output

For each frame, AutoBlur computes luminance and Laplacian variance in five patches, combines their scores with a trimmed mean, then smooths over time. The 95th percentile is the sharpness reference. Blur is `maxBlur * (1 - clamp(variance/reference, 0, 1)^curve)`, followed by quantization and optional run suppression. Flat patches with zero variance throughout are rejected because they cannot establish a useful reference.

Frame coverage includes the start frame and excludes the end frame. Transform times are relative to the ASS line start, including when the event starts between frame boundaries. The curve is inserted into the first leading override block; preceding comments remain comments. If there is no such override block, a new one is created.

**Strip existing** removes blur and edge-blur tags from that first override block and its transforms, removing transforms emptied by the operation while retaining mixed transforms. Later inline overrides and resets remain unchanged and can alter the generated appearance; inspect them when a result differs across the text.

## Requirements and persistence

Use arch1t3cht’s Aegisub with video loaded. Your settings are saved between sessions; choose the sample coordinate and tracking data for each run.

## Estimate limits

This is a local contrast estimate, not a calibrated optical blur measurement; changing texture or lighting can change the estimate. Inspect the sign against its background in Aegisub.
