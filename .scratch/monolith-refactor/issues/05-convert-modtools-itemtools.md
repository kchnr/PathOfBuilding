---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert `src/Modules/ModTools.lua` and `src/Modules/ItemTools.lua` from global-namespace modules into standard Lua modules that return their public API. These are the two main library tables used across the entire codebase.

### ModTools.lua (the `modLib` global)

Currently:
```lua
modLib = { }
function modLib.createMod(modName, modType, modVal, ...) ... end
function modLib.parseMod(modText) ... end
function modLib.formatFlags(flags, flagTable) ... end
-- ... other functions
```

This is a straightforward conversion. The entire `modLib` table is self-contained — it doesn't capture any project globals as upvalues (it uses `bit` builtins and Lua stdlib). Conversion:

1. Change `modLib = { }` to `local modLib = { }`
2. Add `return modLib` at the end
3. In `Main.lua`: change `LoadModule("Modules/ModTools")` to `modLib = require("Modules.ModTools")`
4. No consumer code changes needed — the global `modLib` is still set

### ItemTools.lua (the `itemLib` global)

Same pattern. Currently defines:
- `itemLib.influenceInfo` — influence type metadata
- `itemLib.catalystInfo` — catalyst metadata
- Various item utility functions

Conversion:
1. Change `itemLib = { }` to `local itemLib = { }`
2. Add `return itemLib` at the end
3. In `Main.lua`: change `LoadModule("Modules/ItemTools")` to `itemLib = require("Modules.ItemTools")`

### Why these two together

Both follow the exact same conversion pattern: a global table with attached functions, no complex dependencies, no vararg injection, no class system involvement. Converting them together reduces overhead without adding risk.

### Risk note

`ModTools.lua` is imported by many files — if the conversion breaks, many things fail. But the conversion is purely additive (add `return`, change one line in Main.lua) and the global is still registered, so the risk is low.

## Acceptance criteria

- [ ] `src/Modules/ModTools.lua` returns the `modLib` table
- [ ] `src/Modules/ItemTools.lua` returns the `itemLib` table
- [ ] `Main.lua` sets `modLib = require("Modules.ModTools")` and `itemLib = require("Modules.ItemTools")`
- [ ] The application starts, loads builds, and calculates stats normally
- [ ] Existing `spec/System/` tests continue to pass
- [ ] `require("Modules.ModTools")` returns the same table as the global `modLib` (testable with busted after issue 02 is done)

## Blocked by

- [01-foundation-package-path](01-foundation-package-path.md)
- [02-convert-global-lua](02-convert-global-lua.md) — Global.lua must be converted first as the POC pattern
