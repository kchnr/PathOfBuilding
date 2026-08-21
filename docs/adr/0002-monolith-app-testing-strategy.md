# Monolith App testing strategy

Every current test boots the full 1MB+ app through `HeadlessWrapper.lua` because there are no seams to cut at. ADR 0001's strict dependency direction creates those seams. We decided on a testing pyramid with one test category per source layer, each requiring exactly its layer's real dependencies and nothing above it. A `health/` category covers deterministic, automated checks on the codebase itself — structural rules, coverage, performance, and mutation resistance. All checks are automated and deterministic: same code produces the same result. The only thing that varies is the action taken on failure: some block the merge (gates), others report a warning (advisory).

## Considered Options

1. **Keep testing through (as it was) HeadlessWrapper for everything.** Rejected: slow feedback loop (seconds per run), no isolation, discourages test-writing.
2. **Test only the calculation engine in isolation.** Rejected: parsers, adapters, and UI state machines benefit from unit tests too, and wiring tests exercise the layers working together.
3. **Chosen: one test category per architectural layer.** Each layer is tested against its real dependencies and faked/stubbed layers above it. Fast unit tests for models/logic/UI-state are the default; integration and health tests gate on CI.

## Test categories

### `spec/models/` — Pure unit tests

Test data structure validation, deserialization, and computed properties. No dependencies — models import nothing outside themselves.

- **Harness**: plain `busted`, no `HeadlessWrapper.lua`
- **Speed**: < 10ms per test
- **Proportion**: most tests

### `spec/logic/` — Pure function tests

Test parsing, calculation, and transformation. Input is model instances; output is model instances or scalars. Depends only on `models/`.

- **Harness**: plain `busted` + model source files
- **Speed**: < 10ms per test
- **Proportion**: most tests

### `spec/adapters/` — IO integration tests

Test that external data (XML, HTTP responses, file data) is correctly transformed into model instances. Use fixture files and stubbed network calls — never real IO.

- **Harness**: `busted` + fixture files + network stubs
- **Speed**: ~50ms per test
- **Proportion**: some tests

### `spec/api/` — Orchestration integration tests

Test that `api/` correctly wires adapters and logic together into coherent workflows. Inject fake adapters to control IO; assert correct results.

- **Harness**: `busted` + fake adapters
- **Speed**: ~50ms per test
- **Proportion**: some tests

### `spec/ui/{feature}/` — UI behavior tests

Test state transitions, control creation, and event handling. No visual/pixel assertions. Inject a fake `api/`; assert state changes, control properties, and `api/` calls.

- **Harness**: `busted` + drawing stubs + fake `api/`
- **Speed**: ~10-20ms per test
- **Proportion**: some tests (fewer than domain tests)

### `spec/health/` — Deterministic codebase checks

Automated, deterministic checks on the codebase itself — not application behavior, but structural quality. Every check produces the same result given the same code and inputs. The distinction is what happens on failure.

#### Gate checks (fail = merge blocked)

- **Dependency drift** — fails if any source file imports across an ADR 0001 boundary. Binary: the import graph either respects the rules or it doesn't. Run as a pre-commit hook and CI gate. Enforces **monotonic progress**: a committed baseline records the current compliance state and the gate fails on any regression against it (new violations blocked); the ruleset tightens over time via intentional baseline updates, rather than gating only on the final aspirational rules.
- **No new globals** — fails if the set of project globals (assignments to names not declared `local` in `src/**/*.lua`) grows beyond a committed baseline captured at module-system bootstrap. Shrinking the set is always allowed (baseline updated downward intentionally). Guards the entire migration from issue 02 onward.
- **Flakiness detection** — fails a specific test if it flips pass/fail more than 2 times in the last 10 CI runs. The test is quarantined (marked skipped) until fixed. Binary: a test is either flaky by the metric or it isn't.

#### Advisory checks (fail = warning reported, merge allowed)

- **Coverage** — reports coverage per module. Flags a warning if a module drops below its historical floor (stored per-module in `spec/health/baselines/`). The drop is deterministic (same code → same coverage), but a drop doesn't block the merge — it surfaces the signal for review.
- **Performance** — runs benchmarks on functions with stored baselines. Flags a warning if a function regresses beyond a tolerance on 3 consecutive CI runs (avoids single-run noise). Baselines are updated intentionally via a separate command, not on every PR.
- **Mutation resistance** — runs mutation testing on files changed in the PR, using only the tests that cover those files. Reports surviving mutants. Advisory because mutation testing is inherently incomplete (not all mutants are meaningful) and the result requires human judgment.
- **Dead code** — reports files with no incoming imports or zero test coverage that also have no references in the dependency graph. Advisory: an orphaned file may be intentionally kept or an oversight; a human decides.

## What is not in scope

These are excluded because they are not automated or not deterministic:

- Manual QA, exploratory testing, and playtesting
- Visual/pixel regression testing (brittle, low signal for a calculation-heavy app)
- Load testing and stress testing (requires production-like environment, not deterministic in CI)
- Security auditing (requires specialized tooling and human review)

## Test determinism

Every test must produce the same pass/fail result given the same code and inputs. Non-deterministic tests erode trust in the suite and waste investigation time. Strategies per category:

| Category | Non-determinism source | Strategy |
|---|---|---|
| `models/` | None inherent | No special handling needed |
| `logic/` | `math.random`, `os.time` | Expose a seed parameter; logic functions accept an explicit RNG or timestamp rather than calling globals |
| `adapters/` | Network, filesystem, system clock | Use fixture files and stubbed responses. Never hit the real network. Fake `os.time()` when timestamps matter |
| `api/` | Real adapters, system clock | Inject fake adapters that return controlled data. Freeze time when api/ depends on it |
| `ui/` | Event timing, rendering output | Control the event sequence explicitly. Drawing output is stubbed — never assert on pixel values, image loads, or screen coordinates |
| `health/` | Dependency drift | Binary lint: same import graph → same result |
| `health/` | No new globals | Same source → same global-assignment set. Baseline diff is deterministic |
| `health/` | Flakiness | Fixed metric: N flips in M runs. Same history → same result. Requires CI run history |
| `health/` | Coverage | Same code → same coverage numbers. Per-module floor stored in baselines |
| `health/` | Performance | Same code on same runner type → same benchmarks within tolerance. Multiple runs (median of 5), compare against stored baseline |
| `health/` | Mutation | Same code + same operators + same tests → same kill count. Targeted to changed files only to keep runtime manageable |
| `health/` | Dead code | Same import graph → same orphan list. Deterministic |

If a test cannot be made deterministic at its layer, the module under test likely has hidden coupling (a global clock, an ambient RNG, a network call buried in what looked like pure logic). That coupling is the real problem — fix the module, don't work around it in the test.

## How tests enforce the architecture

A test file for a module must `require` its dependencies. The dependency rules from ADR 0001 determine what's reachable:

- A `spec/logic/` test cannot `require` anything from `adapters/` — the test would fail to load, revealing a boundary violation.
- A `spec/ui/skills/` test for `SkillsState.lua` cannot `require` `api/` — the test would fail, proving state is impure.
- A test that passes without `HeadlessWrapper.lua` proves the module under test has no hidden coupling to the app globals.

Writing a test is the fastest way to discover an architectural violation: if you can't write the test without pulling in half the app, the module is coupled to things it shouldn't be.

## Test dependency map

Each test category requires exactly its layer's real dependencies. Layers above the one under test are faked or absent.

| Test category | Real dependencies | Faked/absent |
|---|---|---|
| `spec/models/` | Nothing | Everything |
| `spec/logic/` | `models/` | `adapters/`, `api/`, `ui/` |
| `spec/adapters/` | `models/`, fixture files | `logic/`, `api/`, `ui/` |
| `spec/api/` | `models/`, `logic/` | Real `adapters/` (use fakes), `ui/` |
| `spec/ui/` | `ui/{feature}/`, `ui/shared/` | Real `api/` (use fake), drawing output |
| `spec/health/` | Full codebase | N/A — these measure the codebase itself |

If a test in `spec/logic/` requires `HeadlessWrapper.lua` to pass, the architecture is violated.

## Test directory structure

```
spec/
├── models/                     — mirrors src/models/
│   ├── Item_spec.lua
│   ├── Mod_spec.lua
│   └── Build_spec.lua
├── logic/                      — mirrors src/logic/
│   ├── ItemParser_spec.lua
│   ├── ModStore_spec.lua
│   ├── EvalMod_spec.lua
│   └── CalcEngine_spec.lua
├── adapters/                   — mirrors src/adapters/
│   ├── BuildRepo_spec.lua
│   └── GameDataRepo_spec.lua
├── api/                        — mirrors src/api/
│   ├── calcs_spec.lua
│   └── builds_spec.lua
├── ui/                         — mirrors src/ui/
│   ├── skills/
│   │   ├── SkillsState_spec.lua
│   │   └── SkillsPage_spec.lua
│   ├── items/
│   │   └── ItemsPage_spec.lua
│   └── shared/
│       └── DropDown_spec.lua
├── health/                     — deterministic codebase checks
│   ├── dependency_drift_spec.lua
│   ├── flakiness_spec.lua
│   ├── coverage_spec.lua
│   ├── perf_benchmark_spec.lua
│   ├── mutation_resistance_spec.lua
│   ├── dead_code_spec.lua
│   └── baselines/              — stored thresholds and benchmark data
│       ├── coverage_floors.json
│       └── perf_baselines.json
└── fixtures/                   — shared test data
    ├── items/
    │   └── rare_ring.txt
    └── builds/
        └── basic_marauder.xml
```

Naming convention: `{ModuleName}_spec.lua` in the directory matching the source layer and feature.

## Running tests

| Command | What it runs | When |
|---|---|---|
| `busted` (default) | `models/` + `logic/` | Development — runs in < 1s on save |
| `busted --run integration` | `adapters/` + `api/` | Pre-commit — validates wiring |
| `busted --run ui` | `ui/` | Before UI refactors |
| `busted --run health` | `health/` | Pre-commit / CI gate |
| `busted --run all` | Everything | Full CI pipeline |

The default run must be fast enough to run on every save. Slower tests gate on CI, not developer workflow.

## Transition

The existing `spec/System/` tests are integration tests that boot the full app. They continue to pass during migration and are gradually triaged into their target categories:

- Pure parsing tests → `spec/logic/`
- IO tests → `spec/adapters/`
- Full-pipeline calculation tests → `spec/api/`
- UI-specific tests → `spec/ui/{feature}/`

Once a system test's coverage is fully replaced by faster layer-specific tests, retire it. During migration, the system tests serve as regression safety nets.
