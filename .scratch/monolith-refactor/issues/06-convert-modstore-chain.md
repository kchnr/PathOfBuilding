---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert the three mod storage class files — `src/Classes/ModStore.lua`, `src/Classes/ModDB.lua`, and `src/Classes/ModList.lua` — from global-dependent modules into standard Lua modules that return their class tables. These are the first class files being converted, so they establish the pattern for all subsequent class conversions.

### Current coupling

All three files capture the `modLib` global as an upvalue at load time:

```lua
-- ModStore.lua:17, ModList.lua:17, ModDB.lua:17
local mod_createMod = modLib.createMod
```

This is the hidden coupling that prevents these files from being loaded without the full app. The conversion replaces this with an explicit require.

### Conversion pattern

For each class file:

```lua
-- BEFORE
local mod_createMod = modLib.createMod    -- captures global

local ModStoreClass = newClass("ModStore", function(self, parent) ... end)
function ModStoreClass:AddMod(mod) ... end
-- [no return — class registered via newClass → common.classes["ModStore"]]

-- AFTER
local modLib = require("Modules.ModTools")
local mod_createMod = modLib.createMod      -- now from require

local ModStoreClass = newClass("ModStore", function(self, parent) ... end)
function ModStoreClass:AddMod(mod) ... end

return ModStoreClass   -- NEW: return for require() consumers
```

### Why this is safe

1. `newClass("ModStore", ...)` still registers the class in `common.classes["ModStore"]` — the class system's lazy loader (`getClass`) continues to work.
2. `LoadModule("Classes/ModStore")` in Main.lua still executes the file — it just now returns a value that Main.lua can capture.
3. The global `modLib` is still available (registered by Main.lua in issue 05), so even if `require("Modules.ModTools")` fails, the global fallback works.
4. No consumer code changes needed — consumers get ModStore/ModDB/ModList instances via `new("ModStore", parent)` which goes through the class system, not directly through require.

### Order: ModStore first, then ModDB/ModList

`ModDB` and `ModList` both inherit from `ModStore` (`newClass("ModList", "ModStore", ...)`). Convert ModStore first and verify it works, then convert the others.

### Verification

After conversion, a simple busted test proves the coupling is broken:

```lua
-- spec/logic/ModStore_spec.lua
require("spec.test_helper")
-- common (class system) is already loaded by test_helper
-- modLib global is registered by test_helper or we require it
local ModStore = require("Classes.ModStore")

describe("ModStore", function()
    it("creates an instance", function()
        local store = new("ModStore")
        assert.is_not_nil(store)
    end)
end)
```

## Acceptance criteria

- [ ] `src/Classes/ModStore.lua` uses `require("Modules.ModTools")` instead of capturing global `modLib`
- [ ] `src/Classes/ModStore.lua` returns the ModStore class table
- [ ] `src/Classes/ModDB.lua` uses `require("Modules.ModTools")` and returns the ModDB class table
- [ ] `src/Classes/ModList.lua` uses `require("Modules.ModTools")` and returns the ModList class table
- [ ] The application starts, loads builds, and calculates stats normally
- [ ] Existing `spec/System/` tests continue to pass
- [ ] A `spec/logic/ModStore_spec.lua` test passes with plain busted (no HeadlessWrapper)

## Blocked by

- [01-foundation-package-path](01-foundation-package-path.md)
- [04-split-common-utilities](04-split-common-utilities.md) — need `copyTable` and other utilities available via require for busted tests
- [05-convert-modtools-itemtools](05-convert-modtools-itemtools.md) — ModStore requires `modLib` to be require-able
