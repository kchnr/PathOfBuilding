---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert `src/Modules/CalcFormat.lua` from a global-namespace module into a standard Lua module that returns its public API. This is the second conversion after Global.lua, chosen because it's small, pure, and has few consumers.

### Current state

`CalcFormat.lua` defines formatting functions like number display formatting, tooltip label formatting, and stat display utilities. It creates no globals of its own (it's currently loaded via `LoadModule` and attaches functions to whatever table receives them through the calc mixin or through direct calls). Its functions are pure: they take numbers/strings and return formatted strings.

### Pattern to follow

Same pattern established in issue 02:
1. Wrap the module's public API in a local table
2. Change any captured globals to `require()` calls
3. Add `return` at the end
4. Register globals in `Main.lua` for backward compat (if the module currently exports any globals)
5. The existing `LoadModule` call in `Main.lua` is replaced with a require + global registration

### What to check

Identify what CalcFormat currently exports — it may export formatting functions as globals or it may just be mixed into `calcs` via the LoadModule pattern. Check the actual file and its consumers. If it only attaches to the `calcs` table, the conversion is just adding `return` and changing the `LoadModule` call site.

## Acceptance criteria

- [ ] `src/Modules/CalcFormat.lua` returns its public API table
- [ ] Any globals it previously set are now registered in `Main.lua` via require
- [ ] The application starts and runs normally (no behavioral change)
- [ ] Existing `spec/System/` tests continue to pass


