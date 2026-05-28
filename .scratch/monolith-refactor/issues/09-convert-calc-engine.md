---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert the nine calc engine modules from global-dependent LoadModule style into standard Lua modules using `require()`. This is the largest single conversion: the calc engine is the heart of the application. **This slice only converts the import mechanism — it does NOT decompose or restructure the calc engine.** That decomposition is a later PRD phase.

### The nine modules and their relationship

`src/Modules/Calcs.lua` is the orchestrator. It creates a `calcs = {}` table, then loads each sub-module via `LoadModule("Modules/CalcSetup", calcs)`, passing the shared `calcs` table as a vararg. Each sub-module receives it as `local calcs = ...` and attaches its functions to it:

```
Calcs.lua (orchestrator)
  ├── CalcSetup.lua      — environment initialization
  ├── CalcPerform.lua    — main calc pass orchestrator
  ├── CalcActiveSkill.lua — active skill creation
  ├── CalcDefence.lua    — defence calculations
  ├── CalcOffence.lua    — offence calculations  
  ├── CalcTriggers.lua   — trigger skill DPS
  ├── CalcMirages.lua    — mirage/minion clone DPS
  ├── CalcBreakdown.lua  — calc trace display
  └── CalcSections.lua   — calcs tab layout
```

### Conversion approach: replace vararg injection with require

**Currently** (Calcs.lua):
```lua
local calcs = { }
calcs.breakdownModule = "Modules/CalcBreakdown"
LoadModule("Modules/CalcSetup", calcs)
LoadModule("Modules/CalcPerform", calcs)
LoadModule("Modules/CalcActiveSkill", calcs)
-- ... etc
```

Each sub-module:
```lua
local calcs = ...    -- receives shared table via vararg
function calcs.someFunction() ... end
```

**After conversion** — each sub-module returns the shared table:

```lua
-- CalcSetup.lua (converted)
local calcs = ...    -- still receives via vararg OR is created locally
function calcs.initEnv(build, mode) ... end
return calcs         -- NEW
```

**Calcs.lua (converted)**:
```lua
local calcs = { }
calcs.breakdownModule = "Modules/CalcBreakdown"

-- Replace LoadModule calls with require
local CalcSetup = require("Modules.CalcSetup")     -- returns the same calcs table we passed
local CalcPerform = require("Modules.CalcPerform")
-- ... etc

-- Still register global for backward compat
_G.calcs = calcs
return calcs
```

### The key question: how does each sub-module receive the shared table?

Option A (safer): Keep the vararg pattern. `Calcs.lua` passes `calcs` as `...` when requiring the sub-module. But `require()` doesn't pass varargs... we'd need to change the sub-module to accept the table differently.

Option B (recommended): Each sub-module creates its own functions locally, then Calcs.lua explicitly attaches them:

```lua
-- CalcSetup.lua
local setup = {}
function setup.initEnv(build, mode) ... end
return setup

-- Calcs.lua
local calcs = require("Modules.CalcSetup")  -- calcs IS the setup table
-- OR
local setup = require("Modules.CalcSetup")
for k, v in pairs(setup) do calcs[k] = v end
```

Option C (simplest, keep existing pattern): Make each sub-module import `calcs` from a require:

```lua
-- CalcSetup.lua
local calcs = require("Modules.Calcs")   -- circular? No, Calcs requires this first
-- ... but circular requires are fragile
```

**Decision: use Option B.** Each sub-module returns its own functions table. `Calcs.lua` merges them into the shared `calcs` table. This is explicit, testable, and avoids any circular require issues.

### Step-by-step for each sub-module

1. Wrap all functions in a local table (e.g., `local setup = {}`)
2. Replace global upvalue captures with `require()`:
   - `local calcs = ...` → `local modLib = require("Modules.ModTools")` etc.
   - Remove references to the shared `calcs` table if the function doesn't need it
3. Add `return setup` at the end
4. In `Calcs.lua`: `local setup = require("Modules.CalcSetup"); for k, v in pairs(setup) do calcs[k] = v end`
5. `Calcs.lua` returns the assembled `calcs` table
6. `Main.lua` registers `_G.calcs` for backward compat

### Verification

The ultimate verification is that the application calculates the same DPS and stats for existing builds before and after. Run a known build through both the old and new code and diff the output tables.

## Acceptance criteria

- [ ] All nine calc modules return their function tables
- [ ] `Calcs.lua` assembles the shared `calcs` table from the nine module returns
- [ ] `Calcs.lua` returns the assembled `calcs` table
- [ ] `Main.lua` registers `_G.calcs` for backward compat
- [ ] The application starts, loads builds, and produces identical calculation results
- [ ] All existing `spec/System/` tests continue to pass — especially TestAttacks, TestDefence, TestAilments, TestTriggers
- [ ] No calc sub-module captures `calcs` as a global — every function receives what it needs as explicit parameters or from the module's own internal state

## Blocked by

- [01-foundation-package-path](01-foundation-package-path.md)
- [04-split-common-utilities](04-split-common-utilities.md)
- [05-convert-modtools-itemtools](05-convert-modtools-itemtools.md)
- [06-convert-modstore-chain](06-convert-modstore-chain.md)
- [08-convert-calctools-pantheon](08-convert-calctools-pantheon.md)
