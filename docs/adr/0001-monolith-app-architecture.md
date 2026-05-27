# Monolith App architecture with strict dependency direction

The codebase has three problems: global coupling (domain reads `data`, `modLib`, `calcLib`, and `main` from anywhere), no IO boundary (file and network calls mixed into pure logic), and no UI boundary (tabs call domain code and read each other's internal state directly). Every test requires booting the full 1MB+ app. We decided to restructure into five directories — `ui/`, `api/`, `models/`, `logic/`, and `adapters/` — with a strict one-way import rule and feature-colocated UI.

## Considered Options

1. **Keep the current structure** (`Modules/` + `Classes/` — flat, no boundaries). Rejected: global coupling makes testing and navigation intractable.
2. **Traditional layered monolith** (`presentation/` → `business/` → `data/`). Rejected: cross-cutting changes require touching every layer; "business" becomes a dumping ground.
3. **Hexagonal/ports-and-adapters** (domain at center, ports define IO contracts, adapters implement them). Most correct but overkill — PoB is a single process with no network boundaries or swappable IO providers.
4. **Chosen: five directories with one-way import rule.** `api/` is the single boundary the UI imports. Adapters are only reachable through `api/`. A single adapter file per IO concern, named for what it loads.

## Why `api/` not `services/`

"Service" implies internal plumbing. "API" makes the boundary explicit: this is what UI imports, nothing else.

## Why `adapters/` is shared

No module has enough IO to justify its own adapter subdirectory. A file per IO concern is sufficient.

## Why `models/` and `logic/` instead of `domain/`

`api/` is the sole gatekeeper to both models and logic. UI receives models through `api/` but never imports logic directly. Separating them makes this boundary visible — `api/` can export a model to UI without exporting the logic that built it.

## Top-level dependency map

| Directory | Can import | Cannot import |
|-----------|------------|---------------|
| `ui/` | `api/` | `models/`, `logic/`, `adapters/` |
| `api/` | `models/`, `logic/`, `adapters/` | `ui/` |
| `models/` | Nothing outside itself | Everything outside itself |
| `logic/` | `models/` | `adapters/`, `api/`, `ui/` |
| `adapters/` | `models/` (plus native libs) | `logic/`, `api/`, `ui/` |
| `main.lua` | Everything | Nothing — it's the composition root |
| `assets/` | Static files only — no code | N/A |

## UI internal structure

UI is organized by feature, not by type. Controls and pages that change together are kept together. Separating by type (`controls/`, `pages/`) scatters related code across directories and makes it unclear which controls belong to which tab. Each tab or screen is a self-contained directory holding its page, state, and controls together. Shared controls live in `ui/shared/` and are only moved there once a second consumer needs them.

### UI internal dependency map

| UI component | Can import | Cannot import |
|---|---|---|
| `ui/{feature}/*Page.lua` | `api/`, `ui/shared/`, sibling files in same feature | Other feature directories |
| `ui/{feature}/*State.lua` | `ui/shared/` (utilities only, no api/) | `api/`, other feature directories |
| `ui/{feature}/*Control.lua` | `api/` (for user-triggered actions), `ui/shared/`, sibling files including state | Other feature directories |
| `ui/shared/*` | other `ui/shared/` files | Anything else |

### What a feature directory contains

A feature directory is a self-contained vertical slice. It always includes:

- **Page** — top-level screen entry point. Composes controls, wires events, calls `api/` for data and actions. One per feature.
- **State** — pure state machine (data + transition functions). No rendering, no `api/` calls. Receives data from the page, exposes it to controls. Zero or one per feature (omit if the feature has no meaningful state beyond control-local values).
- **Controls** — individual UI elements that render and handle user input. May call `api/` for user-triggered actions (e.g. clicking "Refresh"). One or more per feature.

A feature may also include local constants, types, or small utility modules — these follow the same import rules as controls.

## Target structure

```
├── src/
│   ├── api/                     — UI imports from here; sole gatekeeper to models, logic, adapters
│   │   ├── items.lua
│   │   ├── calcs.lua
│   │   ├── builds.lua
│   │   ├── skills.lua
│   │   ├── tree.lua
│   │   └── config.lua
│   ├── models/                  — Pure data structures; never import outside themselves
│   │   ├── Item.lua
│   │   ├── Mod.lua
│   │   ├── Build.lua
│   │   └── BuildSnapshot.lua
│   ├── logic/                   — Pure functions; may import models only
│   │   ├── ModStore.lua
│   │   ├── ModDB.lua
│   │   ├── ModList.lua
│   │   ├── EvalMod.lua
│   │   ├── ItemParser.lua
│   │   ├── CalcEngine.lua
│   │   └── CalcOutput.lua
│   ├── adapters/                — IO; may import models; named for what they load
│   │   ├── BuildRepo.lua
│   │   ├── GameDataRepo.lua
│   │   └── PoeTradeClient.lua
│   ├── ui/                      — Presentation; imports only api/
│   │   ├── shared/              — Controls used by 2+ features
│   │   │   ├── Button.lua
│   │   │   ├── EditControl.lua
│   │   │   ├── DropDown.lua
│   │   │   └── Tooltip.lua
│   │   ├── skills/              — Skills tab: page + controls + state
│   │   │   ├── SkillsPage.lua
│   │   │   ├── SkillsState.lua
│   │   │   ├── SkillListControl.lua
│   │   │   └── GemSelectControl.lua
│   │   ├── items/               — Items tab
│   │   │   ├── ItemsPage.lua
│   │   │   ├── ItemsState.lua
│   │   │   └── ItemSlotControl.lua
│   │   ├── tree/                — Passive tree tab
│   │   │   ├── TreePage.lua
│   │   │   ├── TreeState.lua
│   │   │   └── PassiveTreeView.lua
│   │   ├── calcs/               — Calcs tab
│   │   │   ├── CalcsPage.lua
│   │   │   └── CalcBreakdownControl.lua
│   │   ├── config/
│   │   ├── compare/
│   │   └── import/
│   └── main.lua                 — Composition root
├── assets/                      — Static resources
│   ├── Data/                    — Game reference data
│   ├── TreeData/                — Per-version tree specs
│   └── Images/                  — UI images
└── …                            — build files, spec/, runtime/, docs/
```
