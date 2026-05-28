---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert `src/Data/Global.lua` from a global-namespace style file into a standard Lua module that returns its public API. This is the canonical proof-of-concept for the entire migration pattern. `Global.lua` is the safest starting point because it defines only constants and enums — no complex logic, no state.

### The `Global.lua` file currently

Defines these top-level globals:
- `colorCodes` — color code table for UI rendering
- `defaultColorCodes` — copy of colorCodes (uses `copyTable`)
- `ModFlag` — bitfield enum (Attack, Spell, Hit, Dot, Melee, Area, etc.)
- `KeywordFlag` — bitfield enum (Aura, Curse, Fire, Cold, Trap, Minion, etc.)
- `SkillType` — integer enum for skill categories
- Helper functions: `updateColorCode`, `hexToRGB`, `MatchKeywordFlags`, `ClearMatchKeywordFlagsCache`

### What to change

**Step 1 — Handle the `copyTable` dependency.** `Global.lua` line 65 calls `copyTable(colorCodes)` which is defined in `Common.lua`. Before converting Global.lua, extract `copyTable` into its own tiny module at `src/Modules/CopyTable.lua` that only contains:

```lua
-- src/Modules/CopyTable.lua
local function copyTable(tbl, noRecurse)
    local out = {}
    for k, v in pairs(tbl) do
        if not noRecurse and type(v) == "table" then
            out[k] = copyTable(v)
        else
            out[k] = v
        end
    end
    return out
end
return copyTable
```

This module has zero dependencies (only Lua stdlib). Register `_G.copyTable = require("Modules.CopyTable")` in Main.lua for backward compat.

**Step 2 — Convert Global.lua.** Wrap the file contents in a local table:

```lua
-- src/Data/Global.lua (converted)
local copyTable = require("Modules.CopyTable")

local Global = {}

Global.colorCodes = { NORMAL = "^xC8C8C8", ... }  -- [existing colorCodes table]
Global.defaultColorCodes = copyTable(Global.colorCodes)
Global.ModFlag = { Attack = 0x00000001, ... }      -- [existing ModFlag table]
Global.KeywordFlag = { Aura = 0x00000001, ... }    -- [existing KeywordFlag table]
Global.SkillType = { Attack = 1, ... }             -- [existing SkillType table]

-- [existing helper functions, attached to Global instead of global]
function Global.updateColorCode(code, color) ... end
function Global.hexToRGB(hex) ... end
function Global.MatchKeywordFlags(keywordFlags, modKeywordFlags) ... end
function Global.ClearMatchKeywordFlagsCache() ... end

return Global
```

**Step 3 — Register globals for backward compat.** In `src/Modules/Main.lua`, before any module that uses ModFlag/KeywordFlag:

```lua
local Global = require("Data.Global")
ModFlag = Global.ModFlag
KeywordFlag = Global.KeywordFlag
SkillType = Global.SkillType
colorCodes = Global.colorCodes
defaultColorCodes = Global.defaultColorCodes
-- helper functions remain global
updateColorCode = Global.updateColorCode
hexToRGB = Global.hexToRGB
MatchKeywordFlags = Global.MatchKeywordFlags
ClearMatchKeywordFlagsCache = Global.ClearMatchKeywordFlagsCache
```

Existing `LoadModule("Data/Global")` calls continue to work — `LoadModule` executes the file, and since the globals are now set in Main.lua before the file loads, the file's previous global-setting behavior is replaced by Main.lua's explicit registration.

**Step 4 — Write the test.** `spec/models/Global_spec.lua`:

```lua
-- spec/models/Global_spec.lua
require("spec.test_helper")  -- sets package.path
local Global = require("Data.Global")

describe("Global", function()
    it("exports ModFlag enum", function()
        assert.is_number(Global.ModFlag.Attack)
        assert.is_number(Global.ModFlag.Spell)
        assert.not_equals(Global.ModFlag.Attack, Global.ModFlag.Spell)
    end)
    it("exports KeywordFlag enum", function()
        assert.is_number(Global.KeywordFlag.Fire)
        assert.is_number(Global.KeywordFlag.Cold)
    end)
    it("MatchKeywordFlags matches single flag", function()
        local result = Global.MatchKeywordFlags(Global.KeywordFlag.Fire, Global.KeywordFlag.Fire)
        assert.is_true(result)
    end)
end)
```

## Acceptance criteria

- [ ] `src/Modules/CopyTable.lua` exists, returns the `copyTable` function, has zero non-stdlib dependencies
- [ ] `src/Data/Global.lua` wraps all its content in a local `Global` table and `return Global`
- [ ] `Global.lua` uses `require("Modules.CopyTable")` instead of calling a global `copyTable`
- [ ] `spec/models/Global_spec.lua` passes with plain `busted` (no `HeadlessWrapper.lua`)
- [ ] `src/Modules/Main.lua` registers `ModFlag`, `KeywordFlag`, `SkillType`, `colorCodes`, and helpers as globals from the require
- [ ] The application starts, loads builds, and calculates stats normally (no behavioral change)
- [ ] Existing `spec/System/` tests continue to pass

## Blocked by

- [01-foundation-package-path](01-foundation-package-path.md)
