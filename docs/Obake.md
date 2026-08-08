# Obake 0.3.4

Obake builds and maintains ASS transform and tag effects.

Menu root: `Obake`

Namespace: `kite.Obake`

## Main areas

- Transform-chain generation with manual keyframes or shaped timing.
- Retiming of timed `\t()` tags to the current line duration.
- In/out tag transitions from two selected dialogue lines.
- Animation presets for blur, fade, scale, color, border, shake, and split effects.
- Border-layer and color-layer generation with transform-aware fill/border normalization.

## Dedicated entries

- `Obake`
- `Obake/Help`
- `: Kite Hotkeys :/Obake/...`

The hotkey branch exposes individual Obake actions for direct assignment.
Its action names match the labels shown by the main action dropdown.

## Configuration

Settings persist through the shared Kite UI settings store, with migration from `kite-obake.json`. The script includes English and Spanish interface text.
