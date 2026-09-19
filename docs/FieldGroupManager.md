# Field Group Manager 1.1.8

English | [Español](es/FieldGroupManager.md) | [Index](../README.md#documentation)

Open **Field Group Manager** to map each unique source-field value to a target value. It operates on dialogue events, optionally including commented events.

## Workflow and example

Choose **Group by**, **Write field**, **Scope** and **Mode**. For example, group by Actor and write Layer: the left list might contain Alice, Bob and Narrator, and the right list `1`, `2`, `3`. Execute assigns each value to every included event in its corresponding group. Groups are sorted alphabetically for strings and numerically for numbers/times; they are not listed in selection order.

**Parallel list** uses one right-hand row per group. **Single value** writes the same input to every included group. The left list is a reference; editing it does not rename groups. Use Group by and the filters to determine the source groups.

Changing the source, target, scope or inclusion filters regenerates the lists before execution. **Refresh list** also regenerates them and discards the edited mapping. Execute again after checking the refreshed correspondence. Invalid values or time order return to the current draft so they can be corrected. Cancel leaves subtitles unchanged.

## Fields and accepted values

| Field | Input |
| --- | --- |
| Effect, Actor, Style, Text | Literal strings. Text is the complete ASS text, including tags and escapes. |
| Layer | Nonnegative integer. |
| Start, End | Nonnegative integer milliseconds, `h:mm:ss.cc` or `mm:ss.cc`; seconds and clock minutes must be below 60 where applicable. |
| Margin L, Margin R, Margin V | Nonnegative integers; zero retains ASS style-margin behavior. Margin V updates the compatible vertical field aliases. |
| Comment | Comment/Dialogue, yes/no, true/false, 1/0; y/n, si and commented/dialog are also accepted. |

Time lists display centiseconds, so source times that round to the same displayed clock value form one group. A value typed as integer milliseconds is applied with its full precision: 1001 → 1004 is a change even though both display as `0:00:01.00`. Nonfinite numbers and overflowing numeric strings are rejected. Proposed starts must not exceed their ends; validation checks the entire plan before writing any row.

String fields are assigned literally; choosing a Style value does not create a new style definition. In Parallel list, each mapping occupies one physical textbox row; use ASS `\N` to represent line breaks within subtitle Text.

## Empty and mixed groups

**Include empty source** includes a source whose value is empty; its left-hand label is `<empty>`. **Include comments** includes commented dialogue events. **Selection** uses normalized selected indices; **Whole script** includes all eligible events. With no selection, the initial scope becomes Whole script.

If a group currently has different target values, its right-hand entry is `<mixed>`. Leaving that marker skips the mixed group. Enter `\<mixed>` to write the literal string `<mixed>` instead. Empty target rows clear string fields and write zero to numeric/time fields. A parallel list must cover every group; extra nonempty rows are rejected, while trailing empty rows are tolerated.

## Applying and persistence

The operation prepares all changes first, checks cancellation during preparation and insertion, and applies one transaction. Failure or cancellation restores changes already written. Only changed rows become the result selection; if nothing changes, the previous selection stays. The report counts changed groups, changed lines and skipped groups.

The six grouping choices are saved. Enter pasted mappings and Single value text for each run. The list has no fixed group limit.
