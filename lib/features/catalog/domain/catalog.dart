class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

String? validateCatalogName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Informe um nome.';
  if (value.trim().length > 120) return 'Use até 120 caracteres.';
  return null;
}

class Discipline {
  const Discipline({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final String? description;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Subject {
  const Subject({
    required this.id,
    required this.disciplineId,
    this.parentId,
    required this.name,
    this.description,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String disciplineId;
  final String? parentId;
  final String name;
  final String? description;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// One snapshot, two queries. Tree traversal is iterative, with no depth cap.
class Catalog {
  Catalog(List<Discipline> disciplines, List<Subject> subjects)
    : disciplines = List.unmodifiable(disciplines),
      subjects = List.unmodifiable(subjects) {
    for (final subject in subjects) {
      byId[subject.id] = subject;
      (_children[subject.parentId] ??= []).add(subject);
    }
  }
  final List<Discipline> disciplines;
  final List<Subject> subjects;
  final Map<String, Subject> byId = {};
  final Map<String?, List<Subject>> _children = {};

  List<Subject> children(String disciplineId, String? parentId) =>
      List.unmodifiable(
        (_children[parentId] ?? const <Subject>[]).where(
          (s) => s.disciplineId == disciplineId,
        ),
      );

  Discipline discipline(String id) => disciplines.firstWhere(
    (d) => d.id == id,
    orElse: () => throw const CatalogException('Disciplina não encontrada.'),
  );
  Subject subject(String id) =>
      byId[id] ?? (throw const CatalogException('Assunto não encontrado.'));

  /// Preorder ensures parents precede children when cloning.
  List<Subject> subtree(String id) {
    final result = <Subject>[];
    final stack = [subject(id)];
    final seen = <String>{};
    while (stack.isNotEmpty) {
      final item = stack.removeLast();
      if (!seen.add(item.id))
        throw const CatalogException('Hierarquia inválida.');
      result.add(item);
      stack.addAll(children(item.disciplineId, item.id).reversed);
    }
    return result;
  }

  List<Discipline> search(String query) {
    final text = query.trim().toLowerCase();
    return disciplines
        .where(
          (d) =>
              '${d.name} ${d.description ?? ''}'.toLowerCase().contains(text),
        )
        .toList();
  }

  List<(Subject, int)> visible(String disciplineId, Set<String> expanded) {
    final rows = <(Subject, int)>[];
    final stack = [
      for (final s in children(disciplineId, null).reversed) (s, 0),
    ];
    while (stack.isNotEmpty) {
      final row = stack.removeLast();
      rows.add(row);
      if (expanded.contains(row.$1.id)) {
        stack.addAll([
          for (final s in children(disciplineId, row.$1.id).reversed)
            (s, row.$2 + 1),
        ]);
      }
    }
    return rows;
  }

  List<Subject> validParents(String id) {
    final item = subject(id);
    final excluded = subtree(id).map((s) => s.id).toSet();
    return subjects
        .where(
          (s) =>
              s.disciplineId == item.disciplineId && !excluded.contains(s.id),
        )
        .toList();
  }
}
