const topicReviewSchema = <String>[
  '''CREATE TABLE topic_reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    syllabus_id INTEGER NOT NULL,
    topic_id TEXT NOT NULL,
    activity_id INTEGER,
    due_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','completed')),
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    FOREIGN KEY(syllabus_id) REFERENCES vertical_syllabi(id) ON DELETE CASCADE,
    FOREIGN KEY(activity_id) REFERENCES activities(id) ON DELETE SET NULL
  )''',
  '''CREATE UNIQUE INDEX topic_reviews_pending_idx
     ON topic_reviews(syllabus_id, topic_id) WHERE status='pending' ''',
  'CREATE INDEX topic_reviews_due_idx ON topic_reviews(status, due_date)',
];
