---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert the two UI base classes — `src/Classes/Control.lua` and `src/Classes/ControlHost.lua` — into standard Lua modules that return their class tables. These are the root of the UI class hierarchy. All other UI controls and tab pages inherit from them.

### Current state

- `Control.lua` — base UI element: position, size, anchors, drawing. Creates `ControlClass` via `newClass("Control", ...)`.
- `ControlHost.lua` — event dispatcher and renderer: holds `self.controls` table, dispatches mouse/key events. Creates `ControlHostClass` via `newClass("ControlHost", "Control", ...)`.

Both use `common` (class system) and Lua stdlib. Neither captures project-specific globals as upvalues that would prevent loading — but they are lazily loaded via `getClass("Control")` → `LoadModule("Classes/Control")`, so the class system still handles their loading.

### Conversion

Minimal change: add `return ControlClass` / `return ControlHostClass` at the end of each file. The class system's `getClass()` still works. This enables `require("Classes.Control")` for direct access while maintaining backward compatibility.

No global upvalue changes needed — these files are already fairly clean.

### Why this is its own slice

Every other UI class depends on Control and ControlHost. If the conversion breaks, the entire UI breaks. Converting them as a focused, small slice minimizes risk before tackling the ~50 UI class files.

## Acceptance criteria

- [ ] `src/Classes/Control.lua` returns the Control class table
- [ ] `src/Classes/ControlHost.lua` returns the ControlHost class table
- [ ] The application starts and renders the UI normally
- [ ] Existing `spec/System/` tests continue to pass


