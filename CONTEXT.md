# Path of Building — Domain Context

Path of Building (PoB) is an offline build planner for Path of Exile (PoE), the action RPG by Grinding Gear Games. It simulates character stats, damage, defenses, and skill interactions so players can theory-craft builds without logging into the game.

## Glossary

### Core Concepts

| Term | Meaning |
|------|---------|
| **Build** | A complete character configuration: class, passives, items, skills, config, notes. Serialized as XML. |
| **Build List** | The launcher screen showing all saved builds. Each build is a `.xml` file in the user's build directory. |
| **Mode** | Application state: `LIST` (build list browser) or `BUILD` (build editor with tabs). |
| **Tab** | A UI panel in BUILD mode: Tree, Skills, Items, Calcs, Config, Import, Compare, Notes, Party. |
| **Spec** | A passive skill tree specification. One build can have multiple specs. |
| **Slot** | An equipment slot (Helmet, Body Armour, Weapon 1, Ring 1, etc.) or inventory slot. |
| **Socket Group** | A set of linked gem sockets. Skills are defined by socket groups, not individual gems. |
| **Mod** | A modifier object: `{ name, type, value, flags, keywordFlags, source, ...tags }`. The atomic unit of stat computation. |
| **ModDB** | The central modifier database for an actor (player, enemy, minion). Keyed by mod name. |
| **ModList** | A flat-array ModStore for transient modifier collections (e.g. a skill's mods). |
| **ModStore** | Base class for ModDB/ModList. Provides parent-chain inheritance, condition evaluation, multiplier scaling. |
| **Environment (env)** | A single-use table holding all state for one calculation pass: actors, modDBs, config, active skills. |
| **Actor** | An entity with a modDB and output: player, enemy, minion, totem, etc. |
| **Active Skill** | A skill instance created from a socketed gem + supports. Contains effect list, buff list, flags, skillData. |
| **Calc** | Short for calculation. The engine that computes all stats from mods. |
| **Breakdown** | Structured trace of how each stat was computed, displayed in Calcs tab. |
| **Output** | Table of computed stat values for an actor (e.g. `output.TotalDPS`, `output.Life`). |
| **SimpleGraphic** | The custom C++ 2D rendering engine that hosts the Lua application. |
| **GGPK** | The game's content archive file (`Content.ggpk`). The Export subsystem reads it for data extraction. |
| **Dat View** | A separate mode/tool for browsing the game's `.dat` files extracted from GGPK. |
| **Headless Mode** | Running without the SimpleGraphic engine. The `HeadlessWrapper.lua` shims native functions for CLI/testing. |

### Mod System

| Term | Meaning |
|------|---------|
| **BASE** | Flat additive value. Summed. |
| **INC** | Increased/reduced percentage. Summed, applied multiplicatively. |
| **MORE** | More/less percentage. Multiplied together. |
| **FLAG** | Boolean flag. First match returns true. |
| **OVERRIDE** | Override value. First match wins. |
| **CHANCE** | Percentage chance. Summed. |
| **PEN** | Elemental/chaos penetration. Summed. |
| **GAIN** | Gain % of damage as extra damage (conversion-like). |
| **LOSE** | Negative GAIN. |
| **Flag** | A bitfield on mods indicating damage mode: `Attack`, `Spell`, `Hit`, `Dot`, `Cast`, `Melee`, `Area`, `Projectile`, etc. |
| **KeywordFlag** | A bitfield on mods indicating skill keywords: `Aura`, `Curse`, `Warcry`, `Physical`, `Fire`, `Cold`, `Lightning`, `Chaos`, `Trap`, `Mine`, `Totem`, `Minion`, `Poison`, `Bleed`, `Ignite`, etc. |
| **Tag** | An extra array element on a mod table (e.g. `mod[1]`) that gates applicability: `Condition`, `Multiplier`, `PerStat`, `SkillName`, `SocketedIn`, `SlotName`, `DistanceRamp`, etc. |
| **Condition** | A boolean flag that gates a mod (e.g. `DualWielding`, `Combat`, `Buffed`). |
| **Multiplier** | A numeric variable that scales a mod (e.g. `Rage`, `FrenzyCharge`, `Level`). |
| **ConditionList** | The set of all condition vars referenced by a build's mods. Used to suggest config options in the UI. |
| **MultiplierList** | The set of all multiplier vars referenced by a build's mods. |

### Calculation Engine

| Term | Meaning |
|------|---------|
| **initEnv** | Creates a calculation environment from build state. Called before each calc pass. |
| **perform** | The main calc orchestrator. Calls setup → defence → triggers → mirages → offence. |
| **setup** | Initializes modDBs, items, flasks, buffs, charges, enemy config for an actor. |
| **defence** | Computes defensive stats: armour, evasion, ES, life, mana, block, dodge, suppression, resistances, EHP. |
| **offence** | Computes offensive stats: weapon damage, conversion, added damage, speed, crit, accuracy, ailment DPS, total DPS. |
| **triggers** | Processes triggered skills (Cast on X, Trigger Socketed Gems, etc.) for DPS contribution. |
| **mirages** | Processes mirage/minion clone skills (Mirage Archer, The Saviour Reflection) for DPS contribution. |
| **EHP** | Effective Hit Pool — estimated damage required to kill the character, computed against various damage types. |
| **cachedPlayerDB** | A snapshot of the player's ModDB taken after initial setup. Used as parent for delta-only recalcs. |
| **cachedEnemyDB** | Same for enemy. |
| **specCopy** | Creates a deep copy of the calculation environment for caching. |
| **wipeEnv** | Clears transient state from an env between recalcs (leaving cached parent data intact). |
| **buildOutput** | The output table passed back to the UI after a MAIN-mode calc. Also collects condition/multiplier metadata. |

### Passive Tree

| Term | Meaning |
|------|---------|
| **Node** | A single passive skill on the tree. Has ID, name, stats, position, connections. |
| **Keystone** | A notable keystone passive at the end of a branch. |
| **Notable** | A notable passive (small keystone-like node). |
| **Mastery** | A mastery node that offers a choice of effects. |
| **Jewel Socket** | A node that accepts a jewel item. |
| **Cluster Jewel** | A jewel that creates a miniature subgraph of nodes attached to the tree. |
| **Timeless Jewel** | A legion jewel that replaces nodes within its radius with conqueror-specific alternates. |
| **Subgraph** | The temporary mini-tree created by a cluster jewel. Node IDs are offset by +65536. |
| **Conquered By** | A timeless jewel conqueror that replaces a node's stats. |
| **Tree Version** | A specific game patch's tree data (e.g. `3_28`, `2_6`). PoB supports all historic versions. |
| **Tree Conversion** | The process of re-mapping allocated nodes when switching between tree versions. |

### Items

| Term | Meaning |
|------|---------|
| **Base Type** | The item's foundation (e.g. "Vaal Regalia", "Opal Ring"). Defines slot, stat requirements, implicit mods. |
| **Implicit** | A mod inherent to the base type. Always active unless replaced by influence/exarch/eater. |
| **Explicit** | A mod from affixes, crafted, or veiled sources. |
| **Enchant** | A mod from the Labyrinth or Incursion. |
| **Rarity** | Normal, Magic, Rare, Unique. Determines affix count and name coloring. |
| **Influence** | Shaper, Elder, Crusader, Hunter, Redeemer, Warlord. Opens special affix pools. |
| **Item Set** | A pre-defined loadout of items for easy swapping. |
| **Weapon Set** | A set of weapon/item swaps for alternate weapon configurations. |
| **Crafting** | The in-app crafting simulator: select base, add/remove affixes, apply influences, etc. |

### Skills & Gems

| Term | Meaning |
|------|---------|
| **Gem** | A skill or support gem socketed in equipment. |
| **Active Skill Gem** | A gem that grants an active skill (e.g. "Fireball"). |
| **Support Gem** | A gem that modifies a linked active skill (e.g. "Greater Multiple Projectiles"). |
| **Granted Skill** | A skill granted by an item (e.g. "Level 20 Summon Skeletons" on a unique helmet). |
| **Socket Group** | A set of connected gem sockets. Active skill + supports must be in same group. |
| **Skill Effect** | A single gem's contribution to a skill: stat map, levels, quality, requirements. |
| **Skill Types** | Enum flags: `Spell`, `Attack`, `Aura`, `Curse`, `Warcry`, `Brand`, `Trap`, `Mine`, `Totem`, `Minion`, `Hit`, `Projectile`, `Area`, etc. |
| **Buff** | An effect from a skill that applies to self or party (auras, warcries, guard skills). |
| **Debuff** | An effect from a skill that applies to enemies (curses, exposure, ailments). |

### Data Export Pipeline

| Term | Meaning |
|------|---------|
| **GGPK** | The game's archive file (`Content.ggpk`). Contains all game assets including `.dat` files. |
| **GGPK Data** | The Lua class that reads/extracts files from a GGPK archive using `bun_extract_file.exe`. |
| **Dat File** | A binary `.dat` file from the game containing structured data (mods, skills, bases, etc.). |
| **Dat64 File** | A 64-bit variation of `.dat` files used in newer game versions. |
| **bun_extract_file.exe** | A native executable that extracts files from GGPK archives. Supports regex filtering. |
| **Oodle** | Oodle compression — used in GGPK for some data. Decompressed via bundled native DLLs. |
| **Export Script** | A Lua script in `Export/Scripts/` that reads game dat files and produces PoB's Lua data files (bases, mods, skills, uniques, etc.). |

### UI Framework

| Term | Meaning |
|------|---------|
| **Control** | Base UI element: position (x,y), size (w,h), anchor, shown/enabled flags. The base class for all Components. |
| **ControlHost** | Event dispatcher and renderer. Holds `self.controls` table of child controls. |
| **Anchor** | Peer-relative positioning: `{ point, other, otherPoint, collapse }`. |
| **Anchor Point** | A named position on a control: `TOPLEFT`, `TOP`, `TOPRIGHT`, `RIGHT`, `BOTTOMRIGHT`, `BOTTOM`, `BOTTOMLEFT`, `LEFT`, `CENTER`. |
| **selControl** | The currently keyboard-focused control. |
| **modFlag** | Dirty flag per tab. Aggregated into `main.unsaved`. Cleared on save. |
| **UndoHandler** | Mixin class providing undo/redo stacks. Tabs that implement `CreateUndoState`/`RestoreUndoState` get undo support. |
| **Tooltip** | A line-based hover info renderer. Triggered via `tooltipFunc` callback on controls. |

### Architecture

| Term | Meaning |
|------|---------|
| **Domain** | Pure game rules and models. No IO, no UI, no globals. |
| **API** | The public boundary that UI calls; one file per module in `src/api/`. |
| **Adapter** | An IO module named for what it loads (e.g. `BuildRepo.lua`), not how. |
| **Page** | A UI screen that composes components and owns its own UI state; tabs are pages. |
| **Component** | A reusable UI element with its own rendering and state (e.g. Button, EditBox). |
| **UI State** | Transient data owned by a page or component that does not affect calculations. |
| **UI Logic** | Event handling and flow coordination within a page that calls `api/`. |
| **Composition Root** | `src/main.lua` where the dependency graph is assembled on startup. |

## File Structure

### Current (as of migration start)

```
/
├── AGENTS.md                          — Agent configuration
├── CONTEXT.md                         — This file
├── src/
│   ├── Launch.lua                     — Entry point (SimpleGraphic)
│   ├── HeadlessWrapper.lua            — CLI/test harness shim
│   ├── GameVersions.lua               — Tree version metadata
│   ├── Modules/
│   │   ├── Main.lua                   — App orchestrator (LIST/BUILD mode)
│   │   ├── Build.lua                  — BUILD mode; owns all tabs
│   │   ├── BuildList.lua             — LIST mode; build browser
│   │   ├── Calcs.lua                 — Calc engine orchestrator
│   │   ├── CalcSetup.lua             — Environment init
│   │   ├── CalcPerform.lua           — Main calc pass
│   │   ├── CalcOffence.lua           — Offense calcs
│   │   ├── CalcDefence.lua           — Defense calcs
│   │   ├── CalcActiveSkill.lua       — Skill creation
│   │   ├── CalcTriggers.lua          — Trigger calcs
│   │   ├── CalcMirages.lua           — Mirage calcs
│   │   ├── CalcBreakdown.lua         — Calc trace display
│   │   ├── CalcSections.lua          — Calcs tab layout
│   │   ├── CalcFormat.lua            — Number formatting
│   │   ├── CalcTools.lua             — Shared calc utilities
│   │   ├── Data.lua                  — Game data loader
│   │   ├── ModParser.lua             — Mod text parser
│   │   ├── ModTools.lua              — Mod utilities
│   │   ├── ItemTools.lua             — Item utilities
│   │   ├── Common.lua                — Base utils, class system
│   │   ├── ConfigOptions.lua         — Config tab options
│   │   ├── ConfigVisibility.lua      — Config option visibility
│   │   └── BuildDisplayStats.lua, BuildListHelpers.lua, BuildSiteTools.lua, PantheonTools.lua, StatDescriber.lua, ToastNotification.lua
│   ├── Classes/
│   │   ├── Control.lua               — Base control
│   │   ├── ControlHost.lua           — Event loop / renderer
│   │   ├── (30+ UI controls: Button, Label, Edit, CheckBox, DropDown, Slider, ScrollBar, List, etc.)
│   │   ├── ItemsTab.lua, SkillsTab.lua, TreeTab.lua, CalcsTab.lua, ConfigTab.lua
│   │   ├── ImportTab.lua, CompareTab.lua, NotesTab.lua, PartyTab.lua
│   │   ├── Item.lua                  — Item data model
│   │   ├── ModDB.lua, ModList.lua, ModStore.lua — Mod storage
│   │   ├── PassiveTree.lua, PassiveTreeView.lua, PassiveSpec.lua — Tree system
│   │   ├── TradeQuery*.lua           — Trade API integration
│   │   ├── Tooltip.lua, TooltipHost.lua — Hover info
│   │   └── UndoHandler.lua           — Undo/redo mixin
│   ├── Data/
│   │   ├── Global.lua                — Constants, enum flags (ModFlag, KeywordFlag, SkillType)
│   │   ├── Gems.lua                  — All skill gem data
│   │   ├── (Mod files for each item category: ModItem.lua, ModJewel.lua, ModFlask.lua, etc.)
│   │   ├── Bases/                    — Item base type definitions
│   │   ├── Skills/                   — Skill gem data files
│   │   ├── Uniques/                  — Unique item data
│   │   ├── StatDescriptions/         — Stat description mappings
│   │   ├── TimelessJewelData/        — Legion jewel seed data
│   │   └── (various: Bosses, Minions, Spectres, Pantheons, Essence, ClusterJewels, etc.)
│   ├── Export/                       — GGPK data extraction tool
│   │   ├── Launch.lua                — Dat View entry point
│   │   ├── Main.lua                  — Dat View main module
│   │   ├── Scripts/                  — ~22 export scripts (skills, mods, bases, etc.)
│   │   ├── Classes/                  — GGPKData, DatFile, Dat64File, UI controls
│   │   └── ggpk/                     — README on bun_extract_file.exe usage
│   ├── Assets/                       — UI images (~70 PNGs)
│   └── TreeData/                     — Per-version tree specs + sprites
├── spec/                             — Busted test suites
│   └── System/                       — ~15 test files (calcs, items, attacks, defence, etc.)
├── runtime/                          — Pre-built binaries (DLLs, Lua runtime)
├── docs/
│   ├── adr/                          — Architecture Decision Records
│   └── agents/                       — Agent skill configs
└── (build files: Makefile, Dockerfile, rockspec, .github/workflows/)
```

## Key Technical Patterns

1. **Mixin-based calc engine**: `Calcs.lua` creates an empty `calcs` table, then each sub-module (`CalcSetup`, `CalcPerform`, etc.) attaches its functions to it via `LoadModule`.

2. **Multi-inheritance class system**: `newClass("Name", "Parent1", "Parent2", constructor)` from `Common.lua`. Used extensively for tabs (inherit `Control`, `ControlHost`, `UndoHandler`).

3. **Parent-chain mod caching**: `ModStore.parent` enables a performance optimization: the initial calc pass creates `cachedPlayerDB`, and subsequent passes set `env.modDB.parent = cachedPlayerDB`, computing only the delta.

4. **Flat UI tree with anchoring**: Controls are not nested in a DOM tree. They're stored flat in `ControlHost.controls` and positioned via peer-to-peer anchors. No parent-child traversal; no z-ordering beyond insertion order.

5. **Headless shim for testing**: `HeadlessWrapper.lua` reimplements all SimpleGraphic native C functions as Lua stubs, enabling tests on any platform with plain LuaJIT.

6. **External data extraction**: Game data (`.dat` files) is extracted from GGPK archives via a native `bun_extract_file.exe` tool, then processed by Lua export scripts to produce PoB's Lua data files.
