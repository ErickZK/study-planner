import sqlite3
from pathlib import Path


database_path = Path(
    r"C:\Users\Erick\AppData\Roaming\br.com.studyplanner\study_planner\study_planner.sqlite"
)

connection = sqlite3.connect(database_path)
try:
    connection.execute("PRAGMA foreign_keys = OFF")
    tables = [
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
        )
    ]
    for table in tables:
        escaped = table.replace('"', '""')
        connection.execute(f'DROP TABLE IF EXISTS "{escaped}"')
    has_sequence = connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'sqlite_sequence'"
    ).fetchone()
    if has_sequence:
        connection.execute("DELETE FROM sqlite_sequence")
    connection.execute("PRAGMA user_version = 0")
    connection.commit()
    connection.execute("VACUUM")
finally:
    connection.close()

verification = sqlite3.connect(database_path)
try:
    remaining = verification.execute(
        "SELECT count(*) FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
    ).fetchone()[0]
    user_version = verification.execute("PRAGMA user_version").fetchone()[0]
finally:
    verification.close()

print(f"Tabelas removidas: {len(tables)}")
print(f"Tabelas restantes: {remaining}")
print(f"Versao do esquema: {user_version}")
