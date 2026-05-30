---
feature: monolith-refactor
status: ready-for-human
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Configure Lua's built-in `package.path` so that `require("Data.Global")` resolves to `src/Data/Global.lua`, `require("Classes.ModStore")` resolves to `src/Classes/ModStore.lua`, etc. This is the foundation: once done, any module can use `require("path.to.file")` to load project source files. No module conversions happen yet — this only makes `require()` capable of finding project files.

### Where to configure

Three places need `package.path`:

1. **`src/Launch.lua`** — the real app entry point. Currently it only calls `PLoadModule("Modules/Main")`. Add `package.path` configuration BEFORE that call so `require()` works throughout the app.

2. **`src/HeadlessWrapper.lua`** — the CLI/test shim. Currently provides `LoadModule` via `loadfile(fileName)`. Add `package.path` configuration here too.

3. **A new `spec/test_helper.lua`** — the bootstrap for new layer-specific tests. This file sets `package.path`, then loads `common` (utilities + class system) so tests can `require()` module files without HeadlessWrapper. Future test files will require this helper.

### The path pattern

```
package.path = package.path .. ";src/?.lua;src/?/init.lua"
```

This means `require("Data.Global")` looks for `src/Data/Global.lua`, and `require("Classes.ModStore")` looks for `src/Classes/ModStore.lua`. The dot notation maps to directory separators.

### Verify it works

Create a one-line test: `spec/test_helper_spec.lua` that requires the test helper, then does `require("Data.Global")` and asserts it returns a table with a `ModFlag` field. This test runs with plain `busted` (no `HeadlessWrapper.lua`).

## Acceptance criteria

- [x] `package.path` is configured in `src/Launch.lua` before any module loading
- [x] `package.path` is configured in `src/HeadlessWrapper.lua`
- [x] `spec/test_helper.lua` exists, configures `package.path`, and loads `common`
- [x] `spec/test_helper_spec.lua` passes: `require("Data.Global")` returns a table with `ModFlag`
- [x] The application still starts and runs normally (no behavioral change — `require()` is just available now, existing `LoadModule` calls are untouched)
- [x] Existing `spec/System/` tests continue to pass
  - 237/238 pass. 1 pre-existing failure in TestTradeQueryCurrency_spec.lua
    (sorting order — unrelated to this issue)

## Blocked by

None — can start immediately.
