---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert `src/Modules/Data.lua` and all its game-data sub-files into standard Lua modules. This is the module system's hardest conversion because Data.lua uses a unique pattern: it creates the global `data` table, then loads dozens of sub-files via `LoadModule("Data/Subfile", data)`, passing the `data` table as a vararg. Each sub-file does `local data = ...` and populates it.

### Current pattern

```lua
-- Data.lua
data = { }
LoadModule("Data/Misc", data)        -- adds monster stats tables to data
LoadModule("Data/Uniques/Amulets", data)
LoadModule("Data/Skills/act_str", data)
-- ... dozens more sub-files
LoadModule("Data/Skills/act_str", data)
```

Each sub-file:
```lua
-- Data/Misc.lua
local data = ...      -- receives the shared data table
data.monsterEvasionTable = { 67, 86, ... }
data.monsterLifeTable = { 22, 26, ... }
```

### Conversion approach

Data.lua returns the `data` table. For the sub-files, there are two approaches:

**Option A (preferred — least invasive):** Keep sub-files using `LoadModule`. Only Data.lua is converted:

```lua
-- Data.lua (converted)
local data = { }
LoadModule("Data/Misc", data)        -- sub-files unchanged
LoadModule("Data/Skills/act_str", data)
-- ...
return data
```

```lua
-- Main.lua
data = require("Modules.Data")
```

This preserves the vararg-injection pattern for data sub-files. They don't need to be converted to return-style — they're loaded once at startup by Data.lua and never loaded standalone.

**Option B (cleaner but more work):** Convert sub-files to return their additions:

```lua
-- Data/Misc.lua (converted)
return {
    monsterEvasionTable = { 67, 86, ... },
    monsterLifeTable = { 22, 26, ... },
}
```

```lua
-- Data.lua (converted)
local data = {}
local misc = require("Data.Misc")
for k, v in pairs(misc) do data[k] = v end
```

**Decision: use Option A for this slice.** Converting data sub-files adds work without benefit at this stage — they're not tested in isolation and have no consumers other than Data.lua. The sub-file conversion is a potential follow-up issue after the main migration is complete.

### Data.lua's own dependencies

Data.lua captures `modLib` and calls utility functions. Replace with `require()` per the established pattern:

```lua
local modLib = require("Modules.ModTools")
local data = {}
-- ... load sub-files ...
return data
```

## Acceptance criteria

- [ ] `src/Modules/Data.lua` uses `require()` for its own dependencies (`modLib`, utilities)
- [ ] `src/Modules/Data.lua` returns the `data` table
- [ ] `Main.lua` sets `data = require("Modules.Data")`
- [ ] All game data sub-files continue to load via `LoadModule` (unchanged)
- [ ] The application starts and all game data is available (items, skills, tree, uniques, etc.)
- [ ] Existing `spec/System/` tests continue to pass

## Blocked by

- [01-foundation-package-path](01-foundation-package-path.md)
- [05-convert-modtools-itemtools](05-convert-modtools-itemtools.md)
- [04-split-common-utilities](04-split-common-utilities.md)
