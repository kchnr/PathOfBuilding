---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert `src/Modules/CalcTools.lua` and `src/Modules/PantheonTools.lua` from global-dependent modules into standard Lua modules. These sit above ModStore/MoDB in the dependency chain and are the last prerequisites before converting the calc engine itself.

### CalcTools.lua

Provides shared calculation utilities: gem level validation, skill type checking, support gem applicability, stat table building, mod value computation. It currently captures globals like `modLib`, `data`, and potentially `calcs`.

### PantheonTools.lua

Parses pantheon mod definitions. Uses `modLib.parseMod` and `ModFlag`/`KeywordFlag`.

### Pattern

Same established pattern:
1. Replace upvalue captures like `local x = globalY` with `local lib = require("Modules.Something")` at the top
2. Wrap public API in a local table and return it
3. `Main.lua` registers the globals for backward compat

### Verification

After conversion, a `spec/logic/CalcTools_spec.lua` test proves the module loads without HeadlessWrapper. Focus tests on the pure functions: gem level validation, skill type matching, stat interpolation — these should take known inputs and return known outputs.

## Acceptance criteria

- [ ] `src/Modules/CalcTools.lua` uses `require()` for its dependencies instead of capturing globals
- [ ] `src/Modules/CalcTools.lua` returns its public API table
- [ ] `src/Modules/PantheonTools.lua` uses `require()` and returns its table
- [ ] `Main.lua` registers the required globals
- [ ] The application starts and calculates stats normally
- [ ] Existing `spec/System/` tests continue to pass
- [ ] A `spec/logic/CalcTools_spec.lua` test passes with plain busted (no HeadlessWrapper)


