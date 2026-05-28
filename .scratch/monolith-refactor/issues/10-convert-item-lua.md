---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert `src/Classes/Item.lua` from a global-dependent class file into a standard Lua module that returns its class table. This is the data model for equippable items — a core data structure used by the Items tab, the calc engine, and the import system.

### Current coupling

Item.lua captures the `itemLib` global as an upvalue at load time:

```lua
-- Item.lua:57
local influenceInfo = itemLib.influenceInfo.all
```

It also uses `modLib` indirectly through item creation, and calls utility functions like `copyTable` and `sanitiseText` which are defined as globals in Common.lua.

### Conversion

```lua
-- AFTER
local itemLib = require("Modules.ItemTools")
local utils = require("Modules.Utils")   -- for copyTable, etc.
local modLib = require("Modules.ModTools")

local influenceInfo = itemLib.influenceInfo.all

local ItemClass = newClass("Item", function(self, raw, rarity, highQuality)
    if raw then
        self:ParseRaw(sanitiseText(raw), rarity, highQuality)
    end
end)
-- ... rest of methods ...

return ItemClass
```

### Verification

A `spec/models/Item_spec.lua` test creates Item instances from known raw text and verifies parsed fields:

```lua
local Item = require("Classes.Item")
describe("Item", function()
    it("parses a rare ring", function()
        local item = new("Item", "Rarity: Rare\n...", "RARE")
        assert.equals("Rare", item.rarity)
    end)
end)
```

## Acceptance criteria

- [ ] `src/Classes/Item.lua` uses `require()` for `itemLib`, `modLib`, and utilities instead of capturing globals
- [ ] `src/Classes/Item.lua` returns the Item class table
- [ ] The application starts, items display correctly in the Items tab
- [ ] Existing `spec/System/` tests continue to pass — especially TestItemParse and TestItemMods
- [ ] A `spec/models/Item_spec.lua` test passes with plain busted (no HeadlessWrapper)

## Blocked by

- [01-foundation-package-path](01-foundation-package-path.md)
- [04-split-common-utilities](04-split-common-utilities.md)
- [05-convert-modtools-itemtools](05-convert-modtools-itemtools.md)
