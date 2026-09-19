# Hotkeys 2.0.2

English | [Español](es/Hotkeys.md) | [Index](../README.md#documentation)

Hotkeys exposes the shared action catalog, favorite management, hotkey migration and settings editor. The default entries are **: Kite Hotkeys :/Sync** and **: Kite Hotkeys :/Config**. A saved menu root or DependencyControl custom menu can prefix/change the visible location. The script requires UI 1.5.1; other scripts use the shared modules directly and do not require this editor macro to be installed.

## Sync existing assignments

Sync reads the configured Aegisub hotkey JSON and DependencyControl configuration, then proposes command-path changes caused by known namespace/menu renames or a changed custom menu. It preserves each keyboard context and its assigned keys. It does not assign new keys or choose shortcuts for you; use Aegisub's shortcut preferences for that.

The review contains every proposed change, including old and new command paths. Apply performs the reviewed migration; Close/Cancel leaves the file unchanged. Several sources targeting the same command merge their key lists without duplicates. Chained migrations use the original source bindings, so moving A to B and B to C does not move A's keys twice. A no-op mapping does not delete a binding.

Before writing, Sync checks that the file still matches the content reviewed. If Aegisub or another editor changed it, Sync reports that the plan must be regenerated. It creates a timestamped `.bak-...` copy; repeated writes in the same second get distinct suffixes. The shared file helper writes atomically, and a failed backup prevents the migration write. The completion report gives the backup location. Reload Aegisub if the edited assignments are not immediately active.

Migration depends on DependencyControl records and recognized path conventions. The report is the place to review a proposed custom-menu relocation; a command absent from those records may require manual reassignment. The tool does not rewrite DependencyControl's customMenu preference itself.

## Configure paths and favorites

Config contains the hotkey file path, DependencyControl config path, menu root and favorites root. Defaults use Aegisub's user paths. **Registered** shows known commands collected from published script catalogs, existing assignments and saved favorites. A published catalog describes the last registered actions; it can remain after a script has been removed or before a source script reloads.

Choose a **Source**, enter a **Favorite path**, then use **Add Favorite**. The path is relative to the configured favorites root; `Timing/Join` creates a nested group. Leaving it empty uses the source action's final name. Adding an existing path updates its source. Full paths beginning with the configured menu/favorites roots are normalized without duplicating those roots, including custom multi-part roots.

Favorites delegate to the original action and its validation rather than copying the implementation. Reload Automation so the source script can register the favorite in its own execution context. A saved favorite whose source is unavailable remains configuration data until that source is installed and loaded. The editor cannot call an action in another script's Lua context by reading its catalog entry alone.

**Remove Favorite** removes the saved mapping; reload to clear an already registered menu entry. **Save** persists path/root changes. **Registered** and **Settings** return to the current unsaved form, retaining the chosen source, paths and favorite name. Closing discards unsaved edits. Add/Remove persist their actions immediately; closing afterward does not undo an already saved favorite. Write errors return to the draft with an error report.

## Shared settings

**Settings** opens the shared store's section list. Select a namespace/section and Edit its JSON values. Keep the existing keys and value types; invalid JSON or structural changes are rejected while the draft stays available for correction. Save writes the selected section; Back returns without saving that draft. The owning script reads the updated values when its settings flow reloads them, so a script may need to be reopened/reloaded.

Settings, favorites and action catalogs are saved in `kite.settings.json`. You can use the other scripts without installing Hotkeys.
