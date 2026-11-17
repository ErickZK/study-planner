import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/core/database/seeds/tjsp_2026_material_seed.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';
import 'package:study_planner/features/planner/data/planner_repository.dart';
import 'package:study_planner/features/projects/data/project_repository.dart';
import 'package:study_planner/features/syllabus/data/syllabus_repository.dart';

void main() {
  test('imports supplied TJSP material without duplicating the plan', () async {
    final database = AppDatabase(NativeDatabase.memory());
    await database.initialize();
    addTearDown(database.close);
    await ProjectRepository(database).create('TJSP 2026');
    final project = (await ProjectRepository(database).list()).single;
    final importer = Tjsp2026MaterialSeed(database);

    final first = await importer.importIntoProject(
      project.id,
      startDate: DateTime(2026, 11, 9),
    );
    final second = await importer.importIntoProject(
      project.id,
      startDate: DateTime(2026, 11, 9),
    );
    final syllabus = await SyllabusRepository(
      database,
    ).loadForSchedule(first.scheduleId);
    final catalog = await CatalogRepository(database).load();
    final firstWeekActivities = await PlannerRepository(
      database,
    ).listRange(first.scheduleId, '2026-11-09', '2026-11-14');
    final allActivities = await PlannerRepository(
      database,
    ).listRange(first.scheduleId, '2026-11-09', '2027-03-20');

    expect(first.disciplines, 13);
    expect(first.topics, 277);
    expect(first.activities, 248);
    expect(first.alreadyImported, isFalse);
    expect(second.scheduleId, first.scheduleId);
    expect(second.alreadyImported, isTrue);
    expect(syllabus.disciplineIds, hasLength(13));
    expect(syllabus.leaves.length, first.topics);
    expect(catalog.subjects, hasLength(277));
    expect(firstWeekActivities, hasLength(12));
    expect(allActivities, hasLength(248));
    expect(
      firstWeekActivities.map((activity) => activity.title),
      contains('Revisar os dois Módulos que sentiu mais dificuldade na semana'),
    );
    expect(allActivities.last.date, '2027-03-20');
    expect(allActivities.last.title, contains('Revisar os dois Módulos'));
  });
}
