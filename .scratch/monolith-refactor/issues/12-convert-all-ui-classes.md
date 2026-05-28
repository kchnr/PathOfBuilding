---
feature: monolith-refactor
status: ready-for-agent
---

## Parent

[PRD: Monolith Refactor](../PRD.md)

## What to build

Convert all remaining UI class files (~50 files in `src/Classes/`) into standard Lua modules that return their class tables. This covers: all tab pages, all controls, the passive tree system, tooltips, undo handler, trade query modules, and compare helpers.

### Files to convert

**Tab pages:** ItemsTab, SkillsTab, TreeTab, CalcsTab, ConfigTab, ImportTab, CompareTab, NotesTab, PartyTab

**Controls:** ButtonControl, LabelControl, EditControl, CheckBoxControl, DropDownControl, SliderControl, ScrollBarControl, ListControl, TextListControl, FolderListControl, PathControl, DraggerControl, RectangleOutlineControl, SectionControl, PopupDialog, GemSelectControl, ItemSlotControl, ItemDBControl, ItemListControl, ItemSetListControl, SkillListControl, MinionListControl, MinionSearchListControl, BuildListControl, ExtBuildListControl, ExtBuildListProvider, PassiveSpecListControl, NotableDBControl, SharedItemListControl, SharedItemSetListControl, ConfigSetListControl, PowerReportListControl, CalcBreakdownControl, CalcSectionControl, PassiveMasteryControl

**Tree system:** PassiveTree, PassiveTreeView, PassiveSpec

**Trade:** TradeQueryRequests, TradeQueryGenerator, TradeQueryRateLimiter, TradeQueryCurrency, PoBArchivesProvider

**Other:** CompareEntry, CompareBuySimilar, CompareCalcsHelpers, CompareTradeHelpers, ComparePowerReportListControl, SearchHost, Tooltip, TooltipHost, UndoHandler

### Pattern (same as established in issue 06 and 11)

For each class file:
1. Check for any global upvalue captures and replace with `require()`
2. Add `return ClassTable` at the end
3. The class system's `getClass()` still works because `newClass()` still registers in `common.classes`

### Common global captures to watch for

Many UI files capture:
- `main.buildPath` or other `main` fields — used for file operations
- `buildSites` — used by ImportTab and trade modules
- `itemLib.influenceInfo` — used by ItemsTab and ItemSlotControl
- `data` — game data references in controls
- `modLib` — mod creation in UI code
- `colorCodes` — from Global.lua (already require-able after issue 02)

Each one gets a `require()` at the top of the file.

### Verification

The application UI is fully functional: all tabs render, all controls respond to input, builds can be created/edited/saved. The best verification is a manual smoke test through all tabs, plus the existing system tests.

## Acceptance criteria

- [ ] All ~50 UI class files return their class tables
- [ ] No UI class file captures project globals as upvalues — all dependencies are explicit `require()` calls
- [ ] The application starts and all tabs render correctly
- [ ] All UI controls respond to user input normally
- [ ] Builds can be created, edited, saved, and loaded
- [ ] Existing `spec/System/` tests continue to pass

## Blocked by

- [11-convert-ui-base-classes](11-convert-ui-base-classes.md)
- [05-convert-modtools-itemtools](05-convert-modtools-itemtools.md)
- [02-convert-global-lua](02-convert-global-lua.md)
- [10-convert-item-lua](10-convert-item-lua.md)

## Note

This is the largest slice by file count. It can be worked on in parallel sub-batches:
- Tab pages (~9 files) can be converted independently of each other
- Controls (~25 files) can be converted in any order
- Tree system (~3 files) needs PassiveTree first then PassiveTreeView/PassiveSpec
- Trade modules (~5 files) are self-contained
