# Field Group Manager 1.1.3

Field Group Manager groups unique dialogue field values and writes mapped values into another field.

Menu root: `Field Group Manager`

The `Field Group Manager` entry itself can be assigned as a hotkey in Aegisub.

Namespace: `kite.FieldGroupManager`

## Use cases

- Group actors, effects, styles, layers, comments, margins, or timing fields.
- Map grouped source values into another dialogue field.
- Apply a single value or a parallel value list to a selection or the whole script.

## Configuration

Stored options are validated when loaded, so stale or manually edited settings fall back to supported fields, scopes, and modes. Writes are planned before mutation and applied transactionally; malformed non-dialogue rows are never treated as events.

In a parallel mapping, `<mixed>` keeps a genuinely mixed group unchanged. Enter `\<mixed>` when the intended string value is literally `<mixed>`.

## Requirements

- `kite.UI` 1.1.3
- `kite.LineOps` 1.5.2
