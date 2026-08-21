---
feature: monolith-refactor
status: ready-for-agent
---

## Problem Statement

The Path of Building codebase has three structural problems that make development and testing intractable:

1. **Global coupling** — domain code reads `data`, `modLib`, `itemLib`, `calcLib`, and `main` from anywhere via a shared global namespace. There is no `require()` system; every file depends on a specific startup loading order to establish globals before any code executes.
2. **No IO boundary** — file and network calls are mixed into pure logic. There is no way to test calculation logic without bootstrapping the entire data-loading pipeline.
3. **No UI boundary** — tab code calls calc engine internals directly and reads other tabs' internal state. Every test requires booting the full 1MB+ application through `HeadlessWrapper.lua`.

The consequence: tests take seconds each, writing new tests is prohibitively difficult, and every refactor risks cascading breakage across modules with no clear boundaries.

## Solution

Restructure the codebase into the five-directory target architecture defined in ADR 0001 (`ui/`, `api/`, `models/`, `logic/`, `adapters/`) with strict one-way dependency rules and a standard Lua `require()` module system. Execute the migration incrementally using a strangler-fig pattern — old code continues working while new module boundaries are established one file at a time, each backed by layer-specific tests per ADR 0002.

The migration is broken into phases (see [Phases](#phases) below), each producing a shippable application with zero behavioral regressions. **Phase 1 (issues 01–14)** establishes the module system and converts every file to `require()` in place; **Phase 2+** (future PRDs) decomposes the calc engine, relocates files into the target directories, and extracts the adapter/api/ui boundaries.

## Phases

The migration is split into phases. **Issues 01–14 are Phase 1.** Phases 2+ are future PRDs, each with its own ADR.

### Phase 1 — Module system + import-mechanism conversion (issues 01–14)

Establish standard `require()` and convert **every** source file to a return-style module, **in place** (no directory moves yet). Each converted file both returns its table (for `require()`) and registers its legacy global (for unconverted consumers), per the dual-access decision. Files stay at current paths, so imports use current paths (e.g. `require("Data.Global")`, `require("Classes.ModStore")`), **not** the ADR 0001 target paths (`models.Global`). Target-path imports arrive in Phase 2 when files move.

Phase 1 also installs the health gates: dependency-drift with monotonic-progress enforcement, and the no-new-globals freeze (issue 14 Parts C–D).

**Outcome:** every source file is require-able in isolation; no behavioral change; the global namespace is frozen; the drift gate protects boundary progress. This is the prerequisite for all later extraction.

Phase 1 deliberately does **not** decompose the calc engine, move files into `models/`/`logic/`/`adapters/`/`api/`/`ui/`, extract the `api/` boundary, or reorganize UI into feature directories. Those are Phase 2+.

### Phase 2+ — Decomposition, restructuring, boundaries (future PRDs)

Each item gets its own PRD + ADR + issues before implementation, per the iterative principle:

- **Calc engine decomposition** — split the shared-mutable-state engine into `logic/` functions (see "Future phase: calc engine decomposition"). Driven by the build-optimization feature.
- **Directory moves** — relocate converted files into `models/`, `logic/`, `adapters/`, `api/`, `ui/`; imports switch to target paths; the drift gate ruleset tightens to full ADR 0001.
- **Adapter extraction** — `GameDataRepo`, `BuildRepo`, `PoeTradeClient` (user stories 16–18).
- **API boundary** — the `api/` layer UI imports from (user stories 19–21).
- **UI feature-directory reorganization** — `ui/{feature}/` Page/State/Controls (user stories 22–25; see "Future phase: UI feature-directory reorganization").

The user stories below describe the **end state** across all phases; issues 01–14 deliver the Phase 1 subset.

## User Stories

### Module system infrastructure

1. As a contributor, I want to use `require("models.Global")` to import constants, so that I don't need to boot the full app to write a test.
2. As a contributor, I want module files to return their public API as a table, so that `require()` returns a predictable value I can use in tests.
3. As a maintainer, I want the current `LoadModule`-based startup to continue working alongside `require()`, so that unconverted modules aren't broken during migration.
4. As a contributor, I want `package.path` configured to include `src/` subdirectories, so that `require("logic.ModStore")` resolves to `src/logic/ModStore.lua`.

### Model extraction

5. As a contributor, I want `Global.lua` (ModFlag, KeywordFlag, SkillType enums) in `models/` with zero dependencies, so that it's the canonical example of a testable pure-data module.
6. As a contributor, I want the Mod data structure documented as a table schema, so that I know which fields are required and which are optional tags.
7. As a contributor, I want Item data-structure validation decoupled from `itemLib` globals, so that I can construct Item instances in tests without loading game data.
8. As a contributor, I want Build and BuildSnapshot data structures extracted to `models/`, so that serialization/deserialization can be tested independently.

### Logic extraction

9. As a contributor, I want number-formatting utilities in `logic/CalcFormat.lua` testable independently, so that display formatting bugs can be caught in unit tests.
10. As a contributor, I want `copyTable`, `round`, `formatValue` and other pure utilities extracted from `Common.lua` into `logic/`, so that they're importable without the class system.
11. As a contributor, I want `ModStore.lua` converted to use `require()` for its `modLib.createMod` dependency instead of capturing a global, so that it can be tested without the full app boot.
12. As a contributor, I want `ModDB.lua` and `ModList.lua` extractable and testable with plain `busted`, so that the central mod storage layer has fast regression tests.
13. As a contributor, I want `ModParser.lua` testable with plain `busted` using model inputs, so that mod-parsing regressions are caught in milliseconds.
14. As a contributor, I want individual calc functions (damage computation, ailment computation, etc.) extractable to `logic/` one at a time, so that the 5000-line calc modules can be decomposed incrementally.
15. As a contributor, I want `ConfigOptions.lua` data definitions extractable to `models/` or `logic/`, so that config option structures are testable.

### Adapter extraction

16. As a contributor, I want game-data loading extracted to `adapters/GameDataRepo.lua` with fixture-file tests, so that IO is separated from pure logic.
17. As a contributor, I want build XML save/load extracted to `adapters/BuildRepo.lua`, so that serialization can be tested without the UI.
18. As a contributor, I want trade-query HTTP calls extracted to `adapters/PoeTradeClient.lua` with network stubs, so that trade integration can be tested deterministically.

### API boundary

19. As a contributor, I want a single `api/` boundary layer that UI code imports from, so that UI never directly touches logic or adapters.
20. As a contributor, I want `api/` tested with fake adapters injected, so that orchestration workflows are verified without real IO.
21. As a contributor, I want each `api/` module (calcs, items, builds, skills, tree, config) to be a thin orchestrator, so that its behavior is clear and testable.

### UI extraction

22. As a contributor, I want UI state machines extracted into `ui/{feature}/State.lua` files with pure busted tests, so that tab behavior can be tested without rendering.
23. As a contributor, I want UI controls extracted into feature directories, so that controls that change together live together.
24. As a contributor, I want shared controls (Button, DropDown, EditControl, Tooltip) in `ui/shared/`, so that they're discoverable and not duplicated.
25. As a contributor, I want each tab page to import only `api/` and `ui/shared/`, so that UI inter-tab coupling is visible and enforced.

### Codebase health

26. As a maintainer, I want a dependency-drift check that fails CI if any file imports across an ADR 0001 boundary, so that the architecture is enforced automatically.
27. As a maintainer, I want existing `spec/System/` tests to continue passing throughout migration, so that behavioral regressions are caught immediately.
28. As a maintainer, I want system tests retired only after their coverage is replaced by faster layer-specific tests, so that no coverage is lost.
29. As a maintainer, I want per-module coverage floors stored in baselines, so that I'm warned if coverage drops below historical levels.
30. As a contributor, I want the default `busted` command to run `models/` + `logic/` tests in under one second, so that I get instant feedback during development.

## Implementation Decisions

### Module system: standard Lua `require()`

Instead of building a custom loader, the migration adopts Lua's built-in `require()` system. `package.path` is configured once (in `Launch.lua` and the test helper) to include `src/?.lua` and `src/?/init.lua`. Every converted module file returns its public API as a local table; consumers use `require("path.to.module")` to import it.

### Strangler-fig migration with dual access during transition

During migration, each converted module both returns a table (for `require()`) AND registers a global entry in `Main.lua` (for backward compatibility with unconverted `LoadModule`-based consumers). This means converted and unconverted files coexist — the global `modLib` still exists alongside `require("Modules.ModTools")` returning the same table. Globals are only removed once every consumer has been converted.

### No file moves until converted

Files stay at their current paths while being converted to `return`-style modules. They move to their target directory (`models/`, `logic/`, etc.) only after conversion and testing are complete. This avoids breaking the existing `Main.lua` loading sequence and the class system's `LoadModule("Classes/"..className)` calls.

### Class system adaptation

The class system in `Common.lua` currently calls `LoadModule("Classes/"..className)` lazily. During migration this remains unchanged — class files are converted to return their class table, `LoadModule` still loads and executes them, and `common.classes[className]` is still populated. Once all class consumers use `require()`, the lazy loader can be removed.

### Extraction order: bottom-up by dependency weight

Modules are extracted from the bottom of the dependency graph upward. The approximate order:

1. Pure constants/enums (`Global.lua`)
2. Pure utility functions (number formatting, table operations)
3. Data structure definitions and validation (Mod, Item — after globals decoupled)
4. Mod storage classes (`ModStore` → `ModList`/`ModDB` — after `modLib` injected)
5. Mod parsing (`ModParser` — after mod storage available)
6. Calc sub-functions (individual damage calcs, ailment calcs — extracted from monolithic calc modules)
7. Game data loading (adapters)
8. API boundary layer
9. UI features (state → controls → pages, simplest tabs first)

### Calc engine decomposition pattern

The calc engine is currently a shared mutable table pattern: `calcs = {}` is created in `Calcs.lua` and mutated by sub-modules via `local calcs = ...`. During extraction, individual functions from `CalcOffence.lua`, `CalcDefence.lua`, etc. are pulled into `logic/` as pure functions that take explicit inputs and return results. The shared `calcs` table is retained as the orchestrator that wires them together.

### Proof-of-concept: Global.lua

The first module converted is `src/Data/Global.lua` — pure constants (`ModFlag`, `KeywordFlag`, `SkillType`, `defaultColorCodes`) with zero dependencies. It is the only module proven to have no hidden coupling. This conversion establishes the pattern: add `return Global` at end of file, register in `Main.lua` as `ModFlag = require("Data.Global").ModFlag` for backward compat, write `spec/models/Global_spec.lua` with plain busted.

## Testing Decisions

### Test-first principle

No module is extracted or refactored without first writing layer-specific tests against its CURRENT behavior. The test serves as both a regression safety net and proof that the module's dependencies are understood.

### Layer-specific test categories

| Category | Real deps | Harness | Speed target |
|----------|-----------|---------|-------------|
| `spec/models/` | Nothing | Plain busted | <10ms each |
| `spec/logic/` | `models/` only | Plain busted + model files | <10ms each |
| `spec/adapters/` | `models/` + fixtures | Busted + fixture files | ~50ms each |
| `spec/api/` | `models/` + `logic/` + fake adapters | Busted + fake adapters | ~50ms each |
| `spec/ui/` | `ui/{feature}/` + fake `api/` | Busted + drawing stubs | 10-20ms each |
| `spec/health/` | Full codebase | Dependency graph scanner | CI gate/advisory |

### What makes a good test

- Tests exercise only the module's external contract (inputs → outputs), not internal implementation
- Tests run without `HeadlessWrapper.lua` — if they need it, the module has hidden coupling that must be fixed first
- Tests are deterministic: same inputs always produce the same pass/fail result
- For `logic/` tests: functions accept explicit RNG seeds or timestamps, never call global `math.random` or `os.time`

### Existing test retirement

`spec/System/` tests continue to pass during migration and are only retired once their coverage is fully replaced by faster layer-specific tests in `spec/logic/`, `spec/adapters/`, or `spec/api/`.

### Codebase health checks (`spec/health/`)

Implemented incrementally as the module system matures:

- **Dependency drift** (gate): fails if any source file imports across an ADR 0001 boundary
- **Coverage floors** (advisory): warns if per-module coverage drops below stored baseline
- **Dead code** (advisory): reports files with no imports and no test coverage
- **Flakiness detection, performance, mutation resistance**: deferred until test suite is large enough to benefit from them

## Out of Scope

- Visual/pixel regression testing (brittle, low signal for a calculation-heavy app)
- Load testing and stress testing
- Security auditing
- Maintaining or refactoring the export system (`src/Export/`)
- Changing game mechanics, mod parsing logic, or calculation algorithms — this migration preserves all current behavior
- Adding new UI features or game data — the migration is purely structural
- Removing or rewriting the SimpleGraphic rendering engine — `HeadlessWrapper.lua` remains for CLI/testing

## Further Notes

### Migration does not block shipping

Each phase produces a fully working application. The strangler-fig pattern means old code paths remain intact until their replacements are validated. Features, bug fixes, and game data updates can continue on the old structure in parallel with migration work on new structure files.

### ADRs may be challenged during migration

ADR 0001 and ADR 0002 are the starting blueprint. As modules are extracted, boundary decisions may reveal cases where the rules need adjustment (e.g., a constant needed by both `models/` and `logic/` that currently lives in `Data/`). When this happens, the conflict is surfaced explicitly and the ADR is updated rather than silently violated.

### Glossary vocabulary

All PRDs, issues, commit messages, and design discussions use the terms defined in `CONTEXT.md`'s glossary. No synonyms are introduced.

### Future driver: build optimization

A planned future feature — automated build optimization / "find best builds" — runs the calculation engine many times (potentially thousands to millions of evaluations) while searching the build space. This is a primary motivating driver for the strict layering and for the calc-engine extraction, not merely a testability concern: the search needs to invoke calc functions in isolation, fast, with no coupling to IO, UI libraries, or other heavy dependencies. Performance here is not just "don't regress" — it must eventually be fast enough for search. This driver is recorded now so boundary and performance decisions throughout the migration are made with it in mind.

### Future phase: calc engine decomposition

Issue 09 converts only the calc engine's *import mechanism* (LoadModule → require). The actual decomposition — splitting the shared-mutable-state engine into `logic/` functions — is a later PRD phase and must be planned in detail before implementation:

- **Challenge.** The engine is not a set of pure functions that happen to share a table; a calc pass deliberately mutates `env` / `actor.output` / `modDB` in place (e.g. `modDB:NewMod(...)` mid-pass). "Pure functions with explicit inputs" must be reconciled with this mutation-centric design rather than assumed.
- **Preserve the delta optimization.** The parent-chain mod caching (`ModStore.parent`, `cachedPlayerDB`, delta passes) is load-bearing for recompute-on-every-keystroke performance and is also what makes repeated evaluations affordable for the future build optimizer. The decomposition must preserve it, and perf must be measured (not assumed) before and after.
- **Spike first.** Before committing the phase, extract one sub-module (e.g. `doActorLifeMana`) into `logic/` with tests and report whether the shared-state model survives. Revise the approach based on findings.
- **Behavior-preserving.** The existing `spec/System/` tests (TestAttacks, TestDefence, TestAilments, TestTriggers) are the regression net; no expected behavior changes. Add layer-specific tests iteratively as seams emerge.
- **Dedicated ADR.** Write an ADR for the calc-engine decomposition before implementation, recording the spike findings and the chosen seam strategy.

Detailed planning is deferred until issues 01–09 are complete, per the iterative principle.

### Future phase: UI feature-directory reorganization

Issues 11 and 12 convert UI class files to return-style modules (the import mechanism only). The feature-directory reorganization described in ADR 0001 (user stories 22–25 — `ui/{feature}/` with Page/State/Controls, shared controls in `ui/shared/`, UI importing only `api/`) is a later phase. It is a major effort — comparable to the calc-engine decomposition — because the UI is a flat control tree with peer-to-peer anchoring, multi-inheritance tabs, and cross-tab state reads. It deserves its own ADR and issue breakdown before implementation, and can proceed as its own organized track so work continues independently of the logic-side migration.
