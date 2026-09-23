/// SQL schema for the local-first learning store.
///
/// The schema is intentionally kept as SQL rather than generated Drift table
/// classes: persistence still uses Drift's SQLite executor, while the package
/// remains usable before code generation is available in a fresh checkout.
const schemaVersion = 2;

const createSchema = <String>[
  '''CREATE TABLE IF NOT EXISTS schema_info (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    version INTEGER NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS learning_events (
    event_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    skill TEXT NOT NULL,
    occurred_at TEXT NOT NULL,
    correct INTEGER NOT NULL,
    latency_ms INTEGER NOT NULL,
    hint_count INTEGER NOT NULL,
    retry_count INTEGER NOT NULL,
    response TEXT,
    uploaded_at TEXT
  )''',
  '''CREATE INDEX IF NOT EXISTS learning_events_order
    ON learning_events (occurred_at, event_id)''',
  '''CREATE TABLE IF NOT EXISTS review_projections (
    item_id TEXT NOT NULL,
    skill TEXT NOT NULL,
    difficulty REAL NOT NULL,
    stability REAL NOT NULL,
    last_review_at TEXT,
    due_at TEXT NOT NULL,
    reps INTEGER NOT NULL,
    algorithm_version TEXT NOT NULL,
    PRIMARY KEY (item_id, skill)
  )''',
  '''CREATE TABLE IF NOT EXISTS confusion_edges (
    edge_key TEXT PRIMARY KEY,
    expected TEXT NOT NULL,
    response TEXT NOT NULL,
    exposure_count INTEGER NOT NULL,
    error_count INTEGER NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS outbox_metadata (
    event_id TEXT PRIMARY KEY REFERENCES learning_events(event_id),
    uploaded_at TEXT
  )''',
  '''CREATE TABLE IF NOT EXISTS device_identity (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    device_id TEXT NOT NULL,
    platform TEXT NOT NULL,
    app_version TEXT NOT NULL,
    next_event_sequence INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS sync_cursor (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )''',
];
