import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../domain/catalog.dart';

class CatalogRepository {
  CatalogRepository(this.db);
  final AppDatabase db;
  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;
  Future<String> _id() async =>
      (await db
              .customSelect('SELECT lower(hex(randomblob(16))) AS id')
              .getSingle())
          .read<String>('id');
  void _validate(String name) {
    final error = validateCatalogName(name);
    if (error != null) throw CatalogException(error);
  }

  String? _description(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  Future<Catalog> load() => db.transaction(_load);
  Future<Catalog> _load() async {
    final disciplines = await db
        .customSelect(
          'SELECT * FROM disciplines WHERE deleted_at IS NULL ORDER BY position, id',
        )
        .get();
    final subjects = await db.customSelect(
      '''SELECT s.* FROM subjects s
      JOIN disciplines d ON d.id = s.discipline_id
      WHERE s.deleted_at IS NULL AND d.deleted_at IS NULL ORDER BY s.position, s.id''',
    ).get();
    DateTime date(QueryRow row, String key) =>
        DateTime.fromMillisecondsSinceEpoch(row.read<int>(key), isUtc: true);
    return Catalog(
      [
        for (final r in disciplines)
          Discipline(
            id: r.read<String>('id'),
            name: r.read<String>('name'),
            description: r.readNullable<String>('description'),
            position: r.read<int>('position'),
            createdAt: date(r, 'created_at'),
            updatedAt: date(r, 'updated_at'),
          ),
      ],
      [
        for (final r in subjects)
          Subject(
            id: r.read<String>('id'),
            disciplineId: r.read<String>('discipline_id'),
            parentId: r.readNullable<String>('parent_id'),
            name: r.read<String>('name'),
            description: r.readNullable<String>('description'),
            position: r.read<int>('position'),
            createdAt: date(r, 'created_at'),
            updatedAt: date(r, 'updated_at'),
          ),
      ],
    );
  }

  Future<List<Discipline>> search(String query) async =>
      (await load()).search(query);

  Future<void> _insertDiscipline(
    String id,
    String name,
    String? description,
    int position,
  ) => db.customStatement(
    '''INSERT INTO disciplines
      (id,name,description,position,created_at,updated_at) VALUES (?,?,?,?,?,?)''',
    [id, name.trim(), _description(description), position, _now, _now],
  );
  Future<void> _insertSubject(
    String id,
    String disciplineId,
    String? parentId,
    String name,
    String? description,
    int position,
  ) => db.customStatement(
    '''INSERT INTO subjects
      (id,discipline_id,parent_id,name,description,position,created_at,updated_at)
      VALUES (?,?,?,?,?,?,?,?)''',
    [
      id,
      disciplineId,
      parentId,
      name.trim(),
      _description(description),
      position,
      _now,
      _now,
    ],
  );

  Future<String> createDiscipline(String name, {String? description}) =>
      db.transaction(() async {
        _validate(name);
        final catalog = await _load();
        final id = await _id();
        await _insertDiscipline(
          id,
          name,
          description,
          catalog.disciplines.length,
        );
        await _positions('disciplines', [
          ...catalog.disciplines.map((d) => d.id),
          id,
        ]);
        return id;
      });
  Future<void> editDiscipline(String id, String name, {String? description}) =>
      db.transaction(() async {
        _validate(name);
        (await _load()).discipline(id);
        await db.customStatement(
          'UPDATE disciplines SET name=?,description=?,updated_at=? WHERE id=?',
          [name.trim(), _description(description), _now, id],
        );
      });
  Future<String> createSubject(
    String disciplineId,
    String name, {
    String? parentId,
    String? description,
  }) => db.transaction(() async {
    _validate(name);
    final catalog = await _load();
    catalog.discipline(disciplineId);
    if (parentId != null &&
        catalog.subject(parentId).disciplineId != disciplineId) {
      throw const CatalogException('O pai deve pertencer à mesma disciplina.');
    }
    final id = await _id();
    final siblings = catalog.children(disciplineId, parentId);
    await _insertSubject(
      id,
      disciplineId,
      parentId,
      name,
      description,
      siblings.length,
    );
    await _positions('subjects', [...siblings.map((s) => s.id), id]);
    return id;
  });
  Future<void> editSubject(String id, String name, {String? description}) =>
      db.transaction(() async {
        _validate(name);
        (await _load()).subject(id);
        await db.customStatement(
          'UPDATE subjects SET name=?,description=?,updated_at=? WHERE id=?',
          [name.trim(), _description(description), _now, id],
        );
      });

  Future<void> _positions(String table, List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await db.customStatement(
        'UPDATE $table SET position=?,updated_at=? WHERE id=?',
        [i, _now, ids[i]],
      );
    }
  }

  Future<void> reorderDiscipline(String id, int index) =>
      db.transaction(() async {
        final catalog = await _load();
        catalog.discipline(id);
        final ids = catalog.disciplines.map((d) => d.id).toList()..remove(id);
        if (index < 0 || index > ids.length)
          throw const CatalogException('Posição inválida.');
        ids.insert(index, id);
        await _positions('disciplines', ids);
      });

  Future<void> placeDisciplineBefore(String id, String targetId) =>
      db.transaction(() async {
        final catalog = await _load();
        catalog.discipline(id);
        catalog.discipline(targetId);
        if (id == targetId) return;
        final ids = catalog.disciplines.map((d) => d.id).toList()..remove(id);
        ids.insert(ids.indexOf(targetId), id);
        await _positions('disciplines', ids);
      });

  Future<void> placeSubjectBefore(String id, String targetId) =>
      db.transaction(() async {
        final catalog = await _load();
        final source = catalog.subject(id);
        final target = catalog.subject(targetId);
        if (id == targetId) return;
        final siblings = catalog
            .children(target.disciplineId, target.parentId)
            .where((s) => s.id != source.id)
            .toList();
        await moveSubject(
          id,
          target.parentId,
          index: siblings.indexWhere((s) => s.id == targetId),
        );
      });

  /// Moves only inside the discipline; the subtree retains all its identities.
  Future<void> moveSubject(
    String id,
    String? parentId, {
    int? index,
  }) => db.transaction(() async {
    final catalog = await _load();
    final item = catalog.subject(id);
    if (parentId != null) {
      final parent = catalog.subject(parentId);
      if (parent.disciplineId != item.disciplineId ||
          catalog.subtree(id).any((s) => s.id == parentId)) {
        throw const CatalogException(
          'Destino inválido: não mova para si, descendentes ou outra disciplina.',
        );
      }
    }
    final old =
        catalog
            .children(item.disciplineId, item.parentId)
            .map((s) => s.id)
            .toList()
          ..remove(id);
    final destination =
        catalog.children(item.disciplineId, parentId).map((s) => s.id).toList()
          ..remove(id);
    final position = index ?? destination.length;
    if (position < 0 || position > destination.length)
      throw const CatalogException('Posição inválida.');
    await db.customStatement(
      'UPDATE subjects SET parent_id=?,updated_at=? WHERE id=?',
      [parentId, _now, id],
    );
    if (item.parentId != parentId) await _positions('subjects', old);
    destination.insert(position, id);
    await _positions('subjects', destination);
  });

  Future<String> duplicateSubject(String id) => db.transaction(() async {
    final catalog = await _load();
    final source = catalog.subject(id);
    final mapping = <String, String>{};
    for (final item in catalog.subtree(id)) {
      final copyId = await _id();
      mapping[item.id] = copyId;
      await _insertSubject(
        copyId,
        item.disciplineId,
        item.id == id ? source.parentId : mapping[item.parentId],
        item.name,
        item.description,
        item.id == id
            ? catalog.children(item.disciplineId, source.parentId).length
            : item.position,
      );
    }
    await _positions('subjects', [
      ...catalog
          .children(source.disciplineId, source.parentId)
          .map((s) => s.id),
      mapping[id]!,
    ]);
    return mapping[id]!;
  });
  Future<String> duplicateDiscipline(String id) => db.transaction(() async {
    final catalog = await _load();
    final source = catalog.discipline(id);
    final copyId = await _id();
    await _insertDiscipline(
      copyId,
      source.name,
      source.description,
      catalog.disciplines.length,
    );
    final mapping = <String, String>{};
    for (final root in catalog.children(id, null)) {
      for (final item in catalog.subtree(root.id)) {
        final subjectId = await _id();
        mapping[item.id] = subjectId;
        await _insertSubject(
          subjectId,
          copyId,
          item.parentId == null ? null : mapping[item.parentId],
          item.name,
          item.description,
          item.position,
        );
      }
    }
    await _positions('disciplines', [
      ...catalog.disciplines.map((d) => d.id),
      copyId,
    ]);
    return copyId;
  });

  /// Logical removal preserves identities for future historical references.
  Future<void> deleteSubject(String id) => db.transaction(() async {
    final catalog = await _load();
    final source = catalog.subject(id);
    for (final item in catalog.subtree(id)) {
      await db.customStatement(
        'UPDATE subjects SET deleted_at=?,updated_at=? WHERE id=?',
        [_now, _now, item.id],
      );
    }
    await _positions(
      'subjects',
      catalog
          .children(source.disciplineId, source.parentId)
          .where((s) => s.id != id)
          .map((s) => s.id)
          .toList(),
    );
  });
  Future<void> deleteDiscipline(String id) => db.transaction(() async {
    final catalog = await _load();
    catalog.discipline(id);
    await db.customStatement(
      'UPDATE subjects SET deleted_at=?,updated_at=? WHERE discipline_id=? AND deleted_at IS NULL',
      [_now, _now, id],
    );
    await db.customStatement(
      'UPDATE disciplines SET deleted_at=?,updated_at=? WHERE id=?',
      [_now, _now, id],
    );
    await _positions(
      'disciplines',
      catalog.disciplines.where((d) => d.id != id).map((d) => d.id).toList(),
    );
  });
}
