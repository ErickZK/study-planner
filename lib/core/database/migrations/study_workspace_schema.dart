const studyWorkspaceSchema = <String>[
  '''CREATE TABLE study_materials (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_id INTEGER NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('pdf','link')),
    title TEXT NOT NULL,
    location TEXT NOT NULL,
    is_used INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY(activity_id) REFERENCES activities(id) ON DELETE CASCADE
  )''',
  'CREATE INDEX study_materials_activity_idx ON study_materials(activity_id, created_at)',
  '''CREATE TABLE activity_notes (
    activity_id INTEGER PRIMARY KEY,
    content TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL,
    FOREIGN KEY(activity_id) REFERENCES activities(id) ON DELETE CASCADE
  )''',
  '''CREATE TABLE question_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_id INTEGER NOT NULL,
    study_session_id INTEGER,
    question_count INTEGER NOT NULL CHECK(question_count > 0),
    created_at INTEGER NOT NULL,
    FOREIGN KEY(activity_id) REFERENCES activities(id) ON DELETE CASCADE,
    FOREIGN KEY(study_session_id) REFERENCES study_sessions(id) ON DELETE SET NULL
  )''',
  'CREATE INDEX question_attempts_activity_idx ON question_attempts(activity_id, created_at)',
  '''CREATE TABLE question_answers (
    attempt_id INTEGER NOT NULL,
    question_number INTEGER NOT NULL CHECK(question_number > 0),
    selected_answer TEXT NOT NULL CHECK(selected_answer IN ('A','B','C','D','E')),
    is_correct INTEGER NOT NULL CHECK(is_correct IN (0,1)),
    PRIMARY KEY(attempt_id, question_number),
    FOREIGN KEY(attempt_id) REFERENCES question_attempts(id) ON DELETE CASCADE
  )''',
];
