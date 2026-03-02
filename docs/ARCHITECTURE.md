# ITOps Command Console – Engineering Deep Dive

## Design Goals

- Deterministic behavior
- Minimal dependencies
- Explicit SQL
- Layer isolation
- Offline-first operation

---

## Database Design

Core tables:

- records
- worklog
- counters

Design decisions:

- SQLite WAL mode enabled
- Atomic counter handling
- Foreign key enforcement
- Timestamp normalization
- Explicit lifecycle states

Schema evolution handled via manual migrations.

---

## CLI Layer

itnew:
- Prompts for metadata
- Atomically increments counter
- Creates ticket folder
- Inserts record
- Opens markdown template

No hidden behavior.

---

## Dashboard Layer

Built with Textual.

Responsibilities:

- Render queue
- Handle key-driven state transitions
- Write explicit DB updates
- Provide deterministic filtering

No background threads beyond UI workers.

---

## Layout Layer

tmux orchestrates:

Top pane:
- Dashboard (approx 60%)

Bottom:
- Daily log
- Interactive shell

Layout isolated from business logic.

---

## Future Enhancements

- Migration framework
- Config-based layout profiles
- SLA aging column
- Structured export
- Role-based profiles

---

## Philosophy

Clarity over abstraction.
Explicit over implicit.
Local control over cloud dependency.
