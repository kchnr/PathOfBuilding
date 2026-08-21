---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert `src/Modules/ConfigOptions.lua` and `src/Modules/ConfigVisibility.lua` from global-namespace modules into standard Lua modules. These define the data structures for the Config tab's buff/condition/debuff options and their visibility rules.

### Pattern

Both files define large data tables that describe UI configuration options. They use `modLib.createMod` and `modLib.flag` to create mod definitions, and reference `ModFlag`/`KeywordFlag` for bitfield values.

Conversion follows the established pattern:

1. Add `local modLib = require("Modules.ModTools")` at the top
2. Add `local Global = require("Data.Global")` for `ModFlag`/`KeywordFlag` if needed
3. Wrap the file's public API in a local table and return it
4. In `Main.lua`: replace `LoadModule("Modules/ConfigOptions")` with the require + global registration

These files are low risk because they're data definitions consumed primarily by the Config tab — if they break, only the Config tab is affected, not the core calc engine.

## Acceptance criteria

- [ ] `src/Modules/ConfigOptions.lua` returns its public API table
- [ ] `src/Modules/ConfigVisibility.lua` returns its public API table
- [ ] Any captured globals changed to `require()` calls
- [ ] `Main.lua` registers the required globals
- [ ] The application starts and the Config tab displays options normally
- [ ] Existing `spec/System/` tests continue to pass


