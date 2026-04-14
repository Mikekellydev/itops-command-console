#!/usr/bin/env bash
set -euo pipefail

# ============================================
# ITOps Command Console - Installer
# Ubuntu LTS / WSL Ubuntu
# Run from the repository root
# ============================================

PROJECT_NAME="itops-command-console"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ITOPS_HOME="${ITOPS_HOME:-$HOME/ITOps}"
DB_PATH="${DB_PATH:-$ITOPS_HOME/80_Time/DB/itops_enterprise.db}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

DASHBOARD_DIR_REL="95_Tools/dashboard"
DASHBOARD_DIR="$REPO_ROOT/$DASHBOARD_DIR_REL"
DASHBOARD_PY="$DASHBOARD_DIR/itops_dashboard.py"
VENV_DIR="$DASHBOARD_DIR/.venv"
REQUIREMENTS_FILE="$DASHBOARD_DIR/requirements.txt"
TICKET_TEMPLATE="$REPO_ROOT/Templates/ticket_template.md"
DAILY_TEMPLATE="$REPO_ROOT/Templates/daily_template.md"

log() { printf "\n[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
die() { printf "\nERROR: %s\n" "$*" >&2; exit 1; }

require_repo_files() {
  [[ -f "$DASHBOARD_PY" ]] || die "Missing dashboard file: $DASHBOARD_PY"
  [[ -f "$REQUIREMENTS_FILE" ]] || die "Missing requirements file: $REQUIREMENTS_FILE"
  [[ -f "$TICKET_TEMPLATE" ]] || die "Missing ticket template: $TICKET_TEMPLATE"
  [[ -f "$DAILY_TEMPLATE" ]] || die "Missing daily template: $DAILY_TEMPLATE"
}

install_apt_deps() {
  log "Installing OS dependencies (git, tmux, sqlite3, python3, python3-venv)..."
  if ! command -v apt >/dev/null 2>&1; then
    die "apt not found. This installer targets Ubuntu/WSL Ubuntu."
  fi
  sudo apt update
  sudo apt install -y git tmux sqlite3 python3 python3-venv
}

ensure_dirs() {
  log "Creating directory structure under $ITOPS_HOME ..."
  mkdir -p \
    "$ITOPS_HOME/10_Tickets" \
    "$ITOPS_HOME/20_Areas/Daily" \
    "$ITOPS_HOME/30_Resources" \
    "$ITOPS_HOME/80_Time/DB" \
    "$ITOPS_HOME/95_Tools"
}

init_or_migrate_db() {
  log "Initializing or migrating SQLite DB at $DB_PATH ..."
  mkdir -p "$(dirname "$DB_PATH")"

  sqlite3 "$DB_PATH" <<'SQL'
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;

BEGIN;

-- Core records table (ticket queue)
CREATE TABLE IF NOT EXISTS records (
  record_key    TEXT PRIMARY KEY,
  record_type   TEXT NOT NULL,                 -- INC, SR, CHG, PRB, KB
  priority      TEXT DEFAULT 'P3',             -- P1..P4
  severity      TEXT DEFAULT 'SEV3',           -- SEV1..SEV4
  status        TEXT NOT NULL DEFAULT 'New',   -- New, In Progress, On Hold, Resolved, Closed, Archived
  client        TEXT DEFAULT 'Internal',
  title         TEXT NOT NULL,
  description   TEXT,                          -- May be added later; ensure exists
  hold_reason   TEXT,
  folder_path   TEXT,
  opened_at     TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  resolved_at   TEXT,
  closed_at     TEXT
);

-- Worklog table
CREATE TABLE IF NOT EXISTS worklog (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  record_key TEXT NOT NULL,
  at         TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  entry      TEXT NOT NULL,
  entry_type TEXT NOT NULL DEFAULT 'work',
  author     TEXT DEFAULT 'me',
  FOREIGN KEY(record_key) REFERENCES records(record_key) ON DELETE CASCADE
);

-- Time entries table (kept even if not used yet)
CREATE TABLE IF NOT EXISTS time_entries (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  record_key TEXT,
  start_at   TEXT,
  end_at     TEXT,
  seconds    INTEGER,
  note       TEXT,
  FOREIGN KEY(record_key) REFERENCES records(record_key) ON DELETE SET NULL
);

-- Counters for auto increment keys per type
CREATE TABLE IF NOT EXISTS counters (
  record_type TEXT PRIMARY KEY,
  next_num    INTEGER NOT NULL
);

INSERT OR IGNORE INTO counters (record_type, next_num) VALUES
  ('INC', 1),
  ('SR',  1),
  ('CHG', 1),
  ('PRB', 1),
  ('KB',  1);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_records_status     ON records(status);
CREATE INDEX IF NOT EXISTS idx_records_priority   ON records(priority);
CREATE INDEX IF NOT EXISTS idx_records_opened_at  ON records(opened_at);
CREATE INDEX IF NOT EXISTS idx_worklog_record_key ON worklog(record_key);
CREATE INDEX IF NOT EXISTS idx_worklog_at         ON worklog(at);

COMMIT;
SQL

  # Ensure description column exists even if older schema was created without it
  # SQLite supports "ALTER TABLE ADD COLUMN" only; safe to try guarded by PRAGMA check.
  local has_desc
  has_desc="$(sqlite3 "$DB_PATH" "PRAGMA table_info(records);" | awk -F'|' '$2=="description"{print "yes"}')"
  if [[ "$has_desc" != "yes" ]]; then
    log "Adding missing column: records.description"
    sqlite3 "$DB_PATH" "ALTER TABLE records ADD COLUMN description TEXT;"
  fi

  log "DB ready."
}

setup_venv() {
  log "Creating dashboard virtual environment..."
  mkdir -p "$DASHBOARD_DIR"
  python3 -m venv "$VENV_DIR"
  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip
  pip install -r "$REQUIREMENTS_FILE"
  deactivate
  log "Dashboard venv ready."
}

ensure_bin_dir_and_path() {
  log "Ensuring $BIN_DIR exists and is on PATH..."
  mkdir -p "$BIN_DIR"

  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    # Add to bashrc idempotently
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
      printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
    fi
    log "Added ~/.local/bin to PATH in ~/.bashrc (restart shell or run: source ~/.bashrc)"
  fi
}

install_itdash_wrapper() {
  log "Installing itdash launcher..."
  cat > "$BIN_DIR/itdash" <<EOF
#!/usr/bin/env bash
set -euo pipefail
ITOPS_DB="\${ITOPS_DB:-\${DB_PATH:-$DB_PATH}}"
REPO_ROOT="$REPO_ROOT"
DASHBOARD_DIR="\$REPO_ROOT/$DASHBOARD_DIR_REL"
VENV="\$DASHBOARD_DIR/.venv"
PY="\$DASHBOARD_DIR/itops_dashboard.py"

if [[ ! -x "\$VENV/bin/python" ]]; then
  echo "Missing venv. Run: (cd \$REPO_ROOT && ./install.sh)" >&2
  exit 1
fi

export ITOPS_DB
exec "\$VENV/bin/python" "\$PY"
EOF
  chmod +x "$BIN_DIR/itdash"
}

install_itnew() {
  log "Installing itnew..."
  cat > "$BIN_DIR/itnew" <<EOF
#!/usr/bin/env bash
set -euo pipefail

DB="\${ITOPS_DB:-$DB_PATH}"
BASE="\${ITOPS_HOME:-$ITOPS_HOME}/10_Tickets"
TEMPLATE="$TICKET_TEMPLATE"

die() { printf 'ERROR: %s\n' "\$*" >&2; exit 1; }

pick_editor() {
  local editor
  for editor in "\${VISUAL:-}" "\${EDITOR:-}" micro nano vim vi; do
    if [[ -n "\$editor" ]] && command -v "\$editor" >/dev/null 2>&1; then
      printf '%s\n' "\$editor"
      return 0
    fi
  done
  return 1
}

render_ticket() {
  local dest="\$1"
  if [[ -f "\$TEMPLATE" ]]; then
    local esc_key esc_title
    esc_key="\$(printf '%s' "\$KEY" | sed 's/[\\/&]/\\\\&/g')"
    esc_title="\$(printf '%s' "\$TITLE" | sed 's/[\\/&]/\\\\&/g')"
    sed \
      -e "s/{{KEY}}/\$esc_key/g" \
      -e "s/{{TITLE}}/\$esc_title/g" \
      "\$TEMPLATE" > "\$dest"
    return
  fi

  cat > "\$dest" <<EOF2
# \$KEY - \$TITLE

## Summary

## Impact

## Actions

## Resolution
EOF2
}

[[ -f "\$DB" ]] || die "Database not found at \$DB. Run ./install.sh first."
mkdir -p "\$BASE"

read -p "Record Type (INC/SR/CHG/PRB/KB): " TYPE
TYPE="\$(echo "\$TYPE" | tr '[:lower:]' '[:upper:]')"
case "\$TYPE" in
  INC|SR|CHG|PRB|KB) ;;
  *) die "Record type must be one of: INC, SR, CHG, PRB, KB" ;;
esac

read -p "Priority (P1-P4) [P3]: " PRI
PRI="\${PRI:-P3}"
PRI="\$(echo "\$PRI" | tr '[:lower:]' '[:upper:]')"
case "\$PRI" in
  P1|P2|P3|P4) ;;
  *) die "Priority must be one of: P1, P2, P3, P4" ;;
esac

read -p "Severity (SEV1-SEV4) [SEV3]: " SEV
SEV="\${SEV:-SEV3}"
SEV="\$(echo "\$SEV" | tr '[:lower:]' '[:upper:]')"
case "\$SEV" in
  SEV1|SEV2|SEV3|SEV4) ;;
  *) die "Severity must be one of: SEV1, SEV2, SEV3, SEV4" ;;
esac

read -p "Client [Internal]: " CLIENT
CLIENT="\${CLIENT:-Internal}"

read -p "Title: " TITLE
[[ -n "\${TITLE// }" ]] || die "Title is required."

# Ensure counters exists (self healing)
sqlite3 "\$DB" <<SQL
BEGIN;
CREATE TABLE IF NOT EXISTS counters (record_type TEXT PRIMARY KEY, next_num INTEGER NOT NULL);
COMMIT;
SQL

# Atomic increment
NUM="\$(sqlite3 "\$DB" <<SQL
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO counters (record_type, next_num) VALUES ('\$TYPE', 1);
SELECT next_num FROM counters WHERE record_type='\$TYPE';
UPDATE counters SET next_num = next_num + 1 WHERE record_type='\$TYPE';
COMMIT;
SQL
)"

PADDED="\$(printf "%04d" "\$NUM")"
KEY="\${TYPE}-\${PADDED}"

FOLDER="\$BASE/\$TYPE/\$KEY"
mkdir -p "\$FOLDER"

render_ticket "\$FOLDER/ticket.md"

# Escape single quotes for SQLite
ESC_TITLE="\$(printf "%s" "\$TITLE" | sed "s/'/''/g")"
ESC_CLIENT="\$(printf "%s" "\$CLIENT" | sed "s/'/''/g")"

sqlite3 "\$DB" <<SQL
INSERT INTO records (
  record_key, record_type, priority, severity, status, client, title, description, folder_path, opened_at, updated_at
) VALUES (
  '\$KEY', '\$TYPE', '\$PRI', '\$SEV', 'New', '\$ESC_CLIENT', '\$ESC_TITLE', '', '\$FOLDER',
  datetime('now','localtime'), datetime('now','localtime')
);
SQL

echo "Created \$KEY"
if editor="\$(pick_editor)"; then
  "\$editor" "\$FOLDER/ticket.md"
else
  echo "No editor found. Open file: \$FOLDER/ticket.md"
fi
EOF
  chmod +x "$BIN_DIR/itnew"
}

install_itops_ent() {
  log "Installing itops_ent tmux command console..."
  cat > "$BIN_DIR/itops_ent" <<EOF
#!/usr/bin/env bash
set -euo pipefail

SESSION="itops_ent"
ITOPS_HOME="\${ITOPS_HOME:-$ITOPS_HOME}"
DB_PATH="\${ITOPS_DB:-$DB_PATH}"
DAILY_TEMPLATE="$DAILY_TEMPLATE"

pick_editor() {
  local editor
  for editor in "\${VISUAL:-}" "\${EDITOR:-}" micro nano vim vi; do
    if [[ -n "\$editor" ]] && command -v "\$editor" >/dev/null 2>&1; then
      printf '%s\n' "\$editor"
      return 0
    fi
  done
  return 1
}

EDITOR_CMD="\$(pick_editor || true)"
DAILY_FILE="\$ITOPS_HOME/20_Areas/Daily/\$(date +%F).md"

# If session exists, attach
if tmux has-session -t "\$SESSION" 2>/dev/null; then
  exec tmux attach -t "\$SESSION"
fi

mkdir -p "\$ITOPS_HOME/20_Areas/Daily"
if [[ ! -f "\$DAILY_FILE" ]]; then
  if [[ -f "\$DAILY_TEMPLATE" ]]; then
    sed "s/{{DATE}}/\$(date +%F)/g" "\$DAILY_TEMPLATE" > "\$DAILY_FILE"
  else
    printf '# Daily Log %s\n\n## Today focus\n\n1.\n2.\n3.\n\n## Task Work Log\nTime   Task   Work Done\n\n## Notes worth keeping\n' "\$(date +%F)" > "\$DAILY_FILE"
  fi
fi

# Create new session
tmux new-session -d -s "\$SESSION" -n console

# Split: top 60%, bottom 40% then bottom split 50/50
tmux split-window -v -p 40 -t "\$SESSION:0"
tmux split-window -h -p 50 -t "\$SESSION:0.1"

# Top pane: dashboard
tmux send-keys -t "\$SESSION:0.0" "export ITOPS_DB=\"\$DB_PATH\"; itdash" C-m

# Bottom-left: daily note
if [[ -n "\$EDITOR_CMD" ]]; then
  tmux send-keys -t "\$SESSION:0.1" "cd \"\$ITOPS_HOME\" && \"\$EDITOR_CMD\" \"\$DAILY_FILE\"" C-m
else
  tmux send-keys -t "\$SESSION:0.1" "cd \"\$ITOPS_HOME\" && less \"\$DAILY_FILE\"" C-m
fi

# Bottom-right: shell
tmux send-keys -t "\$SESSION:0.2" "cd \"\$ITOPS_HOME\" && clear" C-m

# Attach
exec tmux attach -t "\$SESSION"
EOF
  chmod +x "$BIN_DIR/itops_ent"
}

post_install_notes() {
  log "Install complete."

  echo ""
  echo "Next steps"
  echo "1) Reload your shell PATH if needed"
  echo "   source ~/.bashrc"
  echo ""
  echo "2) Start the console"
  echo "   itops_ent"
  echo ""
  echo "3) Create a ticket"
  echo "   itnew"
  echo ""
  echo "Database"
  echo "  $DB_PATH"
  echo ""
}

main() {
  log "Starting installer for $PROJECT_NAME"
  require_repo_files
  install_apt_deps
  ensure_dirs
  init_or_migrate_db
  setup_venv
  ensure_bin_dir_and_path
  install_itdash_wrapper
  install_itnew
  install_itops_ent
  post_install_notes
}

main "$@"
