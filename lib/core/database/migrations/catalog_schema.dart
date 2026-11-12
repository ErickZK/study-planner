/// Incremental v1 -> v2; projects and existing identities are preserved.
const catalogSchema = <String>[
  '''CREATE TABLE disciplines (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
    description TEXT,
    position INTEGER NOT NULL CHECK(position >= 0),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
  )''',
  '''CREATE TABLE subjects (
    id TEXT NOT NULL PRIMARY KEY,
    discipline_id TEXT NOT NULL REFERENCES disciplines(id) ON DELETE RESTRICT,
    parent_id TEXT,
    name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
    description TEXT,
    position INTEGER NOT NULL CHECK(position >= 0),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE(id, discipline_id),
    CHECK(parent_id IS NULL OR parent_id <> id),
    FOREIGN KEY(parent_id, discipline_id)
      REFERENCES subjects(id, discipline_id) ON DELETE RESTRICT
  )''',
  'CREATE INDEX disciplines_order ON disciplines(deleted_at, position, id)',
  'CREATE INDEX subjects_tree ON subjects(discipline_id, parent_id, deleted_at, position, id)',
  '''CREATE TRIGGER subjects_no_cycle BEFORE UPDATE OF parent_id ON subjects
  WHEN NEW.parent_id IS NOT NULL BEGIN
    SELECT RAISE(ABORT, 'subject_cycle') WHERE EXISTS (
      WITH RECURSIVE ancestors(id, parent_id) AS (
        SELECT id, parent_id FROM subjects WHERE id = NEW.parent_id
        UNION
        SELECT s.id, s.parent_id FROM subjects s
          JOIN ancestors a ON s.id = a.parent_id
      ) SELECT 1 FROM ancestors WHERE id = NEW.id
    );
  END''',
];
