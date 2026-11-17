const syllabusSchema = <String>[
  '''
  CREATE TABLE vertical_syllabi (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    schedule_id INTEGER NOT NULL UNIQUE,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE syllabus_disciplines (
    syllabus_id INTEGER NOT NULL,
    discipline_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    PRIMARY KEY (syllabus_id, discipline_id),
    FOREIGN KEY (syllabus_id) REFERENCES vertical_syllabi(id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE syllabus_topics (
    syllabus_id INTEGER NOT NULL,
    topic_id TEXT NOT NULL,
    parent_topic_id TEXT,
    position INTEGER NOT NULL,
    is_copy INTEGER NOT NULL DEFAULT 0,
    name_override TEXT,
    copy_source_id TEXT,
    PRIMARY KEY (syllabus_id, topic_id),
    FOREIGN KEY (syllabus_id) REFERENCES vertical_syllabi(id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE topic_progress (
    syllabus_id INTEGER NOT NULL,
    topic_id TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (syllabus_id, topic_id),
    FOREIGN KEY (syllabus_id) REFERENCES vertical_syllabi(id) ON DELETE CASCADE
  )
  ''',
  'CREATE INDEX syllabus_topics_parent_idx ON syllabus_topics(syllabus_id, parent_topic_id, position)',
];
