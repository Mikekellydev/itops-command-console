# ITOps Command Console

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)
![Language](https://img.shields.io/badge/python-3.10+-blue)
![Database](https://img.shields.io/badge/database-SQLite-green)
![UI](https://img.shields.io/badge/UI-Textual-purple)

![Status](https://img.shields.io/badge/status-Active%20Development-brightgreen)

A terminal-native operational command system designed to demonstrate structured systems thinking, clean architecture, and deterministic workflow control.

Built with:

- SQLite (data integrity)
- Python + Textual (TUI dashboard)
- Bash (CLI tooling)
- tmux (operator command console)

---

## Why This Project Exists

Modern operational tools are often:

- SaaS-dependent
- Opaque in logic
- Over-abstracted
- Subscription-bound

ITOps Command Console demonstrates an alternative approach:

Local-first. Transparent. Deterministic. Durable.

This project reflects how I design internal systems: structured, minimal, maintainable, and predictable.

---

## What It Demonstrates

- Schema-driven workflow architecture
- Separation of concerns
- Terminal-native UI engineering
- Controlled state transitions
- Explicit lifecycle management
- Safe auto-increment key handling
- tmux orchestration patterns
- Clean CLI design

This is not a prototype. It is an intentionally structured operational backbone.

---

## System Architecture


Database Layer (SQLite)
↓
CLI Intake Tools (Bash)
↓
Dashboard UI (Textual)
↓
tmux Command Console Layout


Each layer is isolated.

No hidden automation. No implicit behavior.

---

## Capabilities

- Structured ticket types (INC, SR, CHG, PRB, KB)
- Priority + severity modeling
- Worklog tracking
- Folder-based record artifacts
- Lifecycle state enforcement
- High-priority filtering
- Deterministic schema design

---

## Example Workflow

1. Create ticket

itnew


2. Manage via dashboard

itdash


3. Track lifecycle transitions
4. Maintain structured worklogs
5. Archive safely

---

## What This Signals

This project demonstrates:

- Systems architecture mindset
- Operational discipline
- Terminal proficiency
- Clean separation of concerns
- Maintainable engineering patterns

It is intended as a portfolio artifact and internal tool blueprint.

---

## Author

Michael Kelly  
GitHub: https://github.com/mikekellydev
