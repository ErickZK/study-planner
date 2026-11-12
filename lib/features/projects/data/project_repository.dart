import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class Project {
  const Project(this.id, this.name);
  final int id;
  final String name;
}

class ProjectRepository {
  ProjectRepository(this.database);
  final AppDatabase database;

  static String? validateName(String value) {
    if (value.trim().isEmpty) return 'Informe o nome do projeto.';
    if (value.trim().length > 120) return 'Use até 120 caracteres.';
    return null;
  }

  Future<List<Project>> list() async {
    final rows = await database
        .customSelect('SELECT id, name FROM projects ORDER BY created_at, id')
        .get();
    return rows
        .map((r) => Project(r.read<int>('id'), r.read<String>('name')))
        .toList();
  }

  Future<Project?> find(int id) async {
    final rows = await database.customSelect(
      'SELECT id, name FROM projects WHERE id=?',
      variables: [Variable(id)],
    ).get();
    if (rows.isEmpty) return null;
    return Project(rows.single.read<int>('id'), rows.single.read<String>('name'));
  }

  Future<void> create(String name) async {
    final error = validateName(name);
    if (error != null) throw ArgumentError(error);
    await database.customInsert(
      'INSERT INTO projects (name, created_at) VALUES (?, ?)',
      variables: [
        Variable(name.trim()),
        Variable(DateTime.now().toUtc().millisecondsSinceEpoch),
      ],
    );
  }
}
