#!/usr/bin/env python3
import os
import sqlite3
from datetime import datetime
from typing import List, Tuple, Optional

from textual.app import App, ComposeResult
from textual.containers import Horizontal
from textual.widgets import Header, Footer, DataTable, Input, Label
from textual.reactive import reactive
from textual.screen import ModalScreen
from textual import events


DB_DEFAULT = os.path.expanduser("~/ITOps/80_Time/DB/itops_enterprise.db")


def q(db: str, sql: str, params: Tuple = ()) -> List[Tuple]:
    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row
    try:
        cur = con.execute(sql, params)
        rows = cur.fetchall()
        return [tuple(r) for r in rows]
    finally:
        con.close()


def one(db: str, sql: str, params: Tuple = ()) -> Optional[Tuple]:
    rows = q(db, sql, params)
    return rows[0] if rows else None


def exec_sql(db: str, sql: str, params: Tuple = ()) -> None:
    con = sqlite3.connect(db)
    try:
        con.execute(sql, params)
        con.commit()
    finally:
        con.close()


class PromptScreen(ModalScreen[Optional[str]]):
    """Modal prompt returning a string, or None on cancel."""
    DEFAULT_CSS = """
    PromptScreen { align: center middle; }
    #box {
        width: 80%;
        max-width: 100;
        border: round $primary;
        padding: 1 2;
        background: $panel;
    }
    #title { margin: 0 0 1 0; }
    Input { width: 1fr; }
    #hint { margin-top: 1; color: $text-muted; }
    """

    def __init__(self, title: str, placeholder: str = "", default: str = ""):
        super().__init__()
        self._title = title
        self._placeholder = placeholder
        self._default = default

    def compose(self) -> ComposeResult:
        yield Label(self._title, id="title")
        yield Input(placeholder=self._placeholder, id="inp")
        yield Label("Enter to submit. Esc to cancel.", id="hint")

    def on_mount(self) -> None:
        inp = self.query_one("#inp", Input)
        inp.value = self._default
        inp.focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id != "inp":
            return
        self.dismiss(event.value.strip())

    def on_key(self, event: events.Key) -> None:
        if event.key == "escape":
            self.dismiss(None)


class ITOpsDashboard(App):
    TITLE = "ITOps Enterprise Dashboard"
    SUB_TITLE = "SQLite Backed"

    # Enterprise clean UI tweaks (reduces the heavy search outline)
    CSS = """
    Screen { background: #111111; }

    Header, Footer {
        background: #0b2a4a;
        color: white;
    }

    Horizontal { height: auto; }

    Input {
        border: none;
        background: #1a1a1a;
        color: white;
        padding: 0 1;
    }

    Input:focus {
        border: none;
        background: #222222;
    }

    #search { height: 1; }

    DataTable { background: #000000; }
    """

    db_path: str = reactive(DB_DEFAULT)
    p12_only: bool = reactive(False)
    ic_view: bool = reactive(False)

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)

        yield Label(
            "Keys: r refresh | p P1/P2 | i Incident View | n new log | h hold | x resolve | c close | o open | q quit"
        )

        with Horizontal():
            yield Label("Search:")
            yield Input(placeholder="INC-1234", id="search")

        table = DataTable(id="queue")
        table.cursor_type = "row"
        yield table

        yield Footer()

    def on_mount(self) -> None:
        t = self.query_one("#queue", DataTable)
        t.add_columns("Key", "Type", "Priority", "Severity", "Status", "Client", "Title")
        self.refresh_queue()

    def refresh_queue(self) -> None:
        table = self.query_one("#queue", DataTable)
        table.clear()

        base = """
        SELECT record_key, record_type, priority, severity, status, client, title
        FROM records
        WHERE status IN ('New','In Progress','On Hold')
        """

        if self.p12_only:
            base += " AND priority IN ('P1','P2')"

        if self.ic_view:
            base += " AND record_type='INC' AND severity IN ('SEV1','SEV2')"

        base += """
        ORDER BY
        CASE priority
            WHEN 'P1' THEN 1
            WHEN 'P2' THEN 2
            WHEN 'P3' THEN 3
            WHEN 'P4' THEN 4
            ELSE 9
        END,
        opened_at ASC;
        """

        rows = q(self.db_path, base, ())

        for r in rows:
            table.add_row(
                r[0] or "",
                r[1] or "",
                r[2] or "",
                r[3] or "",
                r[4] or "",
                r[5] or "",
                r[6] or "",
            )

        if table.row_count > 0:
            table.move_cursor(row=0, column=0)

    def get_selected_key(self) -> Optional[str]:
        table = self.query_one("#queue", DataTable)
        if table.row_count == 0 or table.cursor_row is None:
            return None
        try:
            row = table.get_row_at(table.cursor_row)
            return row[0] if row else None
        except Exception:
            return None

    def open_ticket_folder(self) -> None:
        record_key = self.get_selected_key()
        if not record_key:
            self.notify("No record selected", severity="warning")
            return

        row = one(self.db_path, "SELECT folder_path FROM records WHERE record_key=?", (record_key,))
        if not row or not row[0]:
            self.notify("No folder_path for this record", severity="warning")
            return

        folder = row[0]
        if folder and os.path.isdir(folder):
            ticket = os.path.join(folder, "ticket.md")
            os.system(f'micro "{ticket}"')
        else:
            self.notify("Folder missing on disk", severity="warning")

    async def add_worklog(self) -> None:
        record_key = self.get_selected_key()
        if not record_key:
            self.notify("No record selected", severity="warning")
            return

        note = await self.push_screen_wait(
            PromptScreen(
                title=f"Worklog entry for {record_key}",
                placeholder="What did you do, decide, change, validate",
            )
        )
        if note is None or not note.strip():
            return

        now = datetime.now().isoformat(timespec="seconds")

        exec_sql(
            self.db_path,
            """
            INSERT INTO worklog (record_key, at, entry, entry_type, author)
            VALUES (?,?,?,?,?);
            """,
            (record_key, now, note.strip(), "work", "me"),
        )
        exec_sql(self.db_path, "UPDATE records SET updated_at=? WHERE record_key=?;", (now, record_key))

        self.notify(f"Logged work to {record_key}")
        self.refresh_queue()

    async def set_hold(self) -> None:
        record_key = self.get_selected_key()
        if not record_key:
            self.notify("No record selected", severity="warning")
            return

        reason = await self.push_screen_wait(
            PromptScreen(
                title=f"Hold reason for {record_key}",
                placeholder="Waiting on customer, vendor, internal team",
            )
        )
        if reason is None:
            return

        now = datetime.now().isoformat(timespec="seconds")

        exec_sql(
            self.db_path,
            """
            UPDATE records
            SET status='On Hold', hold_reason=?, updated_at=?
            WHERE record_key=?;
            """,
            (reason.strip() if reason.strip() else None, now, record_key),
        )

        self.notify(f"Set hold on {record_key}")
        self.refresh_queue()

    def resolve_record(self) -> None:
        record_key = self.get_selected_key()
        if not record_key:
            self.notify("No record selected", severity="warning")
            return

        now = datetime.now().isoformat(timespec="seconds")
        exec_sql(
            self.db_path,
            """
            UPDATE records
            SET status='Resolved', resolved_at=COALESCE(resolved_at, ?), updated_at=?
            WHERE record_key=?;
            """,
            (now, now, record_key),
        )

        self.notify(f"Resolved {record_key}")
        self.refresh_queue()

    def close_record(self) -> None:
        record_key = self.get_selected_key()
        if not record_key:
            self.notify("No record selected", severity="warning")
            return

        now = datetime.now().isoformat(timespec="seconds")
        exec_sql(
            self.db_path,
            """
            UPDATE records
            SET status='Closed', closed_at=COALESCE(closed_at, ?), updated_at=?
            WHERE record_key=?;
            """,
            (now, now, record_key),
        )

        self.notify(f"Closed {record_key}")
        self.refresh_queue()

    async def on_key(self, event: events.Key) -> None:
        k = event.key.lower()

        if k == "q":
            self.exit()
            return
        if k == "r":
            self.refresh_queue()
            return
        if k == "p":
            self.p12_only = not self.p12_only
            self.refresh_queue()
            return
        if k == "i":
            self.ic_view = not self.ic_view
            self.refresh_queue()
            return
        if k == "o":
            self.open_ticket_folder()
            return
        if k == "x":
            self.resolve_record()
            return
        if k == "c":
            self.close_record()
            return
        if k == "n":
            await self.add_worklog()
            return
        if k == "h":
            await self.set_hold()
            return


if __name__ == "__main__":
    ITOpsDashboard().run()
