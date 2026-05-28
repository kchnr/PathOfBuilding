---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert the three composition-root modules — `src/Modules/Build.lua`, `src/Modules/BuildList.lua`, and `src/Modules/Main.lua` — into standard Lua modules. Then, once every source file has been converted, strip the legacy backward-compatibility globals from Main.lua and enable the dependency drift health check.

### Part A: Convert Build.lua, BuildList.lua, and Main.lua

These are the top-level orchestrators. Build.lua creates the BUILD mode with all tabs. BuildList.lua creates the LIST mode with the build browser. Main.lua is the composition root that loads everything and switches between modes.

**Main.lua conversion:**

Currently Main.lua is a sequence of `LoadModule("Modules/Common")`, `LoadModule("Modules/Data")`, etc. After conversion, it becomes:

```lua
-- src/Modules/Main.lua (converted)
local common = require("Modules.Common")        -- still sets _G.common
local Utils = require("Modules.Utils")          -- pure functions
local Global = require("Data.Global")
local data = require("Modules.Data")
local modLib = require("Modules.ModTools")
local itemLib = require("Modules.ItemTools")
local calcs = require("Modules.Calcs")
local BuildList = require("Modules.BuildList")
local Build = require("Modules.Build")
-- ... etc

-- Backward compat globals (TEMPORARY — removed in Part B)
_G.common = common
_G.ModFlag = Global.ModFlag
_G.KeywordFlag = Global.KeywordFlag
-- ... all other globals ...
_G.calcs = calcs
_G.data = data
_G.modLib = modLib
_G.itemLib = itemLib

-- Mode management
main = new("ControlHost")
function main:Init() ... end
function main:SetMode(mode, ...) ... end

return main
```

**Build.lua and BuildList.lua conversion:** Both are large modules. They currently capture globals (`main`, `data`, `modLib`, `calcs`, etc.). Replace all with `require()` at the top. Return their mode tables or main objects.

### Part B: Strip legacy globals

Once every source file uses `require()` and no file depends on the globals, remove the backward-compat global registrations from Main.lua. This is the point of no return — it's marked HITL because it requires human judgment about whether any globals are still needed.

### Part C: Dependency drift health check

Create `spec/health/dependency_drift_spec.lua` that scans all `require()` calls in `src/**/*.lua` and verifies they respect ADR 0001's dependency rules. This runs as a CI gate.

For this slice, the health check starts with "no `require()` to `Classes/` from outside the UI layer" and "no `require()` to `Modules/` from Classes/ that isn't a utility" — relaxed rules that tighten as restructuring progresses in future PRDs.

### Verification

Run the full application and verify every feature works: build list → load/edit build → all tabs → save → switch builds. The existing system tests serve as the regression suite.

## Acceptance criteria

### Part A

- [ ] `src/Modules/Main.lua` uses `require()` for all module loading instead of `LoadModule`
- [ ] `src/Modules/Main.lua` returns the `main` object
- [ ] `src/Modules/Build.lua` uses `require()` for all dependencies and returns its mode table
- [ ] `src/Modules/BuildList.lua` uses `require()` for all dependencies and returns its mode table
- [ ] The application starts and switches between LIST and BUILD modes normally
- [ ] All features work: creating builds, editing items/skills/tree, calculating stats, saving/loading, importing
- [ ] All existing `spec/System/` tests continue to pass

### Part B

- [ ] No source file captures a project-internal global as an upvalue — verified by grep
- [ ] Backward-compat globals removed from Main.lua
- [ ] Full application smoke test passes
- [ ] All existing tests pass

### Part C

- [ ] `spec/health/dependency_drift_spec.lua` exists and scans all `require()` calls
- [ ] Fails CI if any `require()` violates relaxed ADR 0001 rules (e.g., `Classes/` importing from `Modules/` in non-utility cases)
- [ ] Runs as a CI gate (`busted --run health`)

## Blocked by

### Part A
- All previous issues (01 through 13)

### Part B
- Part A complete
- Verification that no globals are captured

### Part C
- Part B complete

## Note

Part B is HITL because removing globals requires human verification that nothing is missed. Once done, the module system conversion is complete — all source files use standard Lua `require()`, and the dependency drift check prevents regression.
