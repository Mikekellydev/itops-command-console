# ITOps Command Console Architecture

## Overview

The system is intentionally small:

1. Bash creates records and launches the operator workspace.
2. SQLite stores queue state and worklog history.
3. Textual provides the active-queue interface.
4. Markdown files hold longer operational notes.

That split keeps the workflow easy to understand and easy to debug.

## Core Components

### SQLite

Primary tables:

- `records` stores the ticket queue and lifecycle state
- `worklog` stores timestamped operational notes
- `counters` assigns the next numeric ID per record type
- `time_entries` is reserved for future effort tracking

Design choices:

- WAL mode for durability and responsiveness
- explicit timestamps for lifecycle changes
- simple schema that can be migrated forward with small installer updates

### CLI Layer

`itnew` is the intake path.

Responsibilities:

- validate record type, priority, severity, and title
- atomically allocate the next key
- create the matching folder and Markdown ticket
- insert the initial database row

`itops_ent` is the workspace launcher.

Responsibilities:

- start or reattach the tmux session
- open the dashboard
- create today’s daily note from template if missing
- leave a shell pane available for ad hoc commands

### Dashboard

The Textual app is a queue manager, not a workflow engine.

Responsibilities:

- list active records
- filter by priority, incident severity, and search text
- write explicit state changes to the database
- open the Markdown artifact for the selected record

## Data Model

Ticket identity follows:

- `INC-0001`
- `SR-0001`
- `CHG-0001`
- `PRB-0001`
- `KB-0001`

Lifecycle states currently used in the UI:

- `New`
- `In Progress`
- `On Hold`
- `Resolved`
- `Closed`

## Source Control Boundary

The repository now separates source from operator state:

- templates, code, docs, and examples are tracked
- runtime DB files are not tracked
- daily logs are not tracked
- live ticket content is not tracked
- local virtual environments are not tracked

That keeps the repo safe to publish while preserving the local-first workflow.

## Next Improvements

- add automated tests around key allocation and status transitions
- add a lightweight migration version table
- expose record detail and worklog history directly in the dashboard
- add export/report views for demos or handoff summaries
