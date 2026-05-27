---
name: codebase_forensics
description: Analyzes git history to map architecture and risk.
triggers: ["evaluate codebase", "git forensics", "repo recon"]
---

Extract architecture, risk, and ownership from Git history. Do not read code first. Read history first.
PHASE 1: GLOBAL RECON

Run these to find where to look.

1. Identify Knowledge Owners (The "Who")

Command: git shortlog -sn --no-merges --all

    Logic: High commit count = Primary maintainer.

    Action: Find names for specific directories to locate "Silos."

2. Identify Hotspots (The "Where")

Command: git log --format=format: --name-only | sed '/^$/d' | sort | uniq -c | sort -nr | head -20

    Logic: High churn = High complexity or technical debt.

    Action: Target these files for Phase 2.

3. Identify Stable vs. Dead Code (The "Age")

Command: git log --reverse --format="%ai" --name-only | awk '!seen[$0]++' | head -n 20

    Logic: Oldest last-modified dates = Stable core or abandoned logic.

    Action: Ignore these during initial onboarding.

4. High-Level Intent (The "Why")

Command: git log --first-parent --oneline -n 50

    Logic: Shows only merge commits/top-level features.

    Action: Read these to understand project milestones.

PHASE 2: DEEP DIVE

Run these on "Hotspots" found in Phase 1.

1. Structural Coupling

Command: git log --format=format: --name-only --follow -- "[FILE_PATH]" | sed '/^$/d' | sort | uniq -c | sort -nr | head -10

    Logic: If File A always changes with File B, they are linked.

    Action: Map the "hidden" architecture.

2. Functional Evolution

Command: git log -L :[FUNCTION_NAME]:[FILE_PATH]

    Logic: Track changes to a specific function over time.

    Action: Understand why critical logic is the way it is.

PHASE 3: ANALYSIS & REPORTING
Analyze data. Look for these patterns:
The Hero Pattern: One person owns 90% of a hotspot. (High Bus Factor risk).
The Ping-Pong Pattern: A file has high churn but low net line growth. (Indicates constant bug-fixing/instability).
The Ghost City: Entire directories with no commits in 2+ years. (Candidates for removal).
Other insightful findings should also be reported if they look relevant.
