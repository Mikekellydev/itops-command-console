# ITOps Command Console

Local-first incident and operations tracking for terminal-first operators.

The project combines SQLite, Bash, tmux, and a Textual dashboard into a small command console for managing tickets, daily logs, and operational workflow without SaaS dependencies.

## Why It Matters

- Local-first: records stay on your machine.
- Explicit: state changes are driven by visible SQL and simple scripts.
- Fast: create a record, open the console, and move through the queue from the keyboard.
- Portable: the repo is small enough to understand quickly and adapt for personal or team workflows.

## Stack

- Python 3
- Textual
- SQLite
- Bash
- tmux

## Quick Start

Target platform: Ubuntu LTS or WSL Ubuntu.

```bash
git clone https://github.com/mikekellydev/itops-command-console.git
cd itops-command-console
./install.sh
```

After install:

```bash
itops_ent
```

Core commands:

```bash
itnew
itdash
itops_ent
```

## Workflow

1. Run `itnew` to create a new record and matching Markdown artifact.
2. Run `itdash` to manage the active queue from the terminal UI.
3. Run `itops_ent` for the full tmux layout: dashboard, daily log, and shell.
4. Keep long-form notes in the ticket file and short timeline entries in the database worklog.

## Dashboard Keys

- `/` focus search
- `Esc` leave search
- `r` refresh
- `p` toggle P1/P2 filter
- `i` toggle high-severity incident view
- `n` add worklog entry
- `h` place record on hold
- `x` resolve record
- `c` close record
- `o` or `Enter` open the selected ticket file
- `q` quit

## Project Layout

- `10_Tickets/` ticket folders grouped by type
- `20_Areas/Daily/` daily operational notes
- `80_Time/DB/` SQLite database location
- `95_Tools/dashboard/` Textual app and Python dependencies
- `Templates/` ticket and daily note templates
- `docs/` architecture, examples, and launch notes
- `docs/website/` static project page for GitHub Pages or other static hosting

## Public Repo Hygiene

This repo is set up so runtime artifacts should stay local:

- the SQLite database is ignored
- daily logs are ignored
- live ticket folders are ignored
- the dashboard virtual environment is ignored

Public examples live in:

- [docs/examples/sample-ticket.md](docs/examples/sample-ticket.md)
- [docs/examples/sample-daily-log.md](docs/examples/sample-daily-log.md)

## Validation

Manual smoke test:

1. Run `itnew` and confirm a folder and DB record are created.
2. Run `itdash` and confirm the new record appears.
3. Use `n`, `h`, `x`, and `c` on a test record and confirm the state changes work.
4. Run `sqlite3 "$ITOPS_DB" "select record_key,status from records order by opened_at desc limit 5;"` if you need a quick DB check.

## Docs

- [docs/index.md](docs/index.md)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/EVENT-LAUNCH-CHECKLIST.md](docs/EVENT-LAUNCH-CHECKLIST.md)

## Author

Michael Kelly  
GitHub: <https://github.com/mikekellydev>
