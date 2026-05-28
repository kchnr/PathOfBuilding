---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Split `src/Modules/Common.lua` into two parts: pure utility functions (extractable now) and the class system (stays for now). Common.lua currently serves two roles: it provides ~40 utility functions used everywhere (`copyTable`, `round`, `formatValue`, `tableConcat`, `isValueInArray`, etc.) AND it implements the class system (`newClass`, `new`, lazy `getClass()` via `LoadModule`). These roles need to be separated so utility functions can be required independently without pulling in the class system.

### What stays in Common.lua

- The `common` table itself
- External library loading (curl, xml, base64, sha1, utf8)
- The class system: `newClass`, `new`, `getClass`, `common.classes`
- Functions that depend on the app runtime: `ConPrintf`, `LoadModule`, `GetTime`
- Functions that depend on other globals: `ImportBuild` (calls `buildSites`), `cacheSkillUUID` (accesses `env.build.skillsTab`), `GetVirtualScreenSize` (calls `GetScreenSize`)

### What moves to a new `src/Modules/Utils.lua`

Pure functions with only Lua stdlib dependencies:

- `copyTable`, `copyTableSafe`
- `round`, `formatValue`, `formatNumSep`, `formatRound`, `formatPercent`, `formatSec`
- `tableConcat`, `tableDeepEquals`
- `pairsYield` (depends on `GetTime` global... check this)
- `pairsSortByKey`
- `isValueInArray`, `isValueInArrayPred`, `isValueInTable`
- `zip`
- `string:split`, `string:matchOrPattern`
- `ceil_b`, `floor_b`
- `urlEncode`, `urlDecode`
- `stringify`
- `wipeTable` if it exists
- `getFormatNumSep`, `getFormatRound`, `getFormatPercent`, `getFormatSec` (higher-order wrappers)

### How to split safely

1. Create `src/Modules/Utils.lua` containing only the pure functions listed above. Each function is local to the file and attached to a local `Utils` table which is returned.
2. In `Common.lua`, replace each moved function's definition with `common.FuncName = require("Modules.Utils").FuncName` (or just let the global remain — simpler: set `_G.FuncName = Utils.FuncName` in Main.lua).
3. Register all moved functions as globals in `Main.lua` immediately after `Common.lua` is loaded, BEFORE any other module that uses them:

```lua
local Utils = require("Modules.Utils")
copyTable = Utils.copyTable
round = Utils.round
formatValue = Utils.formatValue
-- ... etc for all moved functions
```

4. `Common.lua` is loaded first (keeps class system), then `Utils` globals are registered, then all other modules proceed as before.

### Watch out for

- `pairsYield` calls `GetTime()` which is a SimpleGraphic/HeadlessWrapper native function — it may need to stay in Common.lua
- `copyFile` does file IO (`io.open`) — this is an adapter concern, not pure logic. Move to `Utils.lua` or keep in Common.lua.
- `prettyPrintTable` calls `ConPrintf` — keep in Common.lua
- `wipeGlobalCache` and `cacheData` access `GlobalCache` global — keep in Common.lua

## Acceptance criteria

- [ ] `src/Modules/Utils.lua` exists, contains all pure utility functions, returns a table, has no non-stdlib dependencies
- [ ] `src/Modules/Common.lua` retains the class system, external lib loading, and app-runtime-dependent functions
- [ ] `Main.lua` registers all moved utility functions as globals from `require("Modules.Utils")`
- [ ] The application starts, loads builds, and calculates stats normally
- [ ] Existing `spec/System/` tests continue to pass
- [ ] A `spec/logic/Utils_spec.lua` test can be written with plain busted: `require("spec.test_helper"); local Utils = require("Modules.Utils")`

## Blocked by

- [01-foundation-package-path](01-foundation-package-path.md)
- [02-convert-global-lua](02-convert-global-lua.md) — the pattern is proven by Global.lua first, and `copyTable` extraction in issue 02 is a subset of this work
