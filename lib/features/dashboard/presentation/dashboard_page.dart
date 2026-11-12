import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../syllabus/data/syllabus_repository.dart';
import '../../projects/application/project_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(AppTokens.large),
    children: [
      Text(
        'Seu espaço de estudo',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text('Organize seus estudos. Tudo fica neste dispositivo.'),
      const SizedBox(height: AppTokens.large),
      ref
          .watch(projectsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Não foi possível carregar os projetos.'),
                TextButton(
                  onPressed: () => ref.invalidate(projectsProvider),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
            data: (projects) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  projects.isEmpty
                      ? 'Nenhum projeto por enquanto.'
                      : 'Seus projetos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final project in projects)
                  FutureBuilder(
                    future: SyllabusRepository(ref.read(databaseProvider).requireValue)
                        .loadForProject(project.id),
                    builder: (context, snapshot) {
                      final syllabus = snapshot.data;
                      final subtitle = syllabus == null
                          ? 'Configurar edital verticalizado'
                          : '${syllabus.disciplineIds.length} disciplinas · ${syllabus.leaves.length} assuntos · ${(syllabus.completion * 100).round()}%';
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(project.name),
                        subtitle: Text(subtitle),
                        onTap: () => context.go('/syllabus/${project.id}'),
                      );
                    },
                  ),
                const SizedBox(height: AppTokens.medium),
                FilledButton.icon(
                  onPressed: () => context.go('/projects'),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar projeto'),
                ),
              ],
            ),
          ),
      const SizedBox(height: AppTokens.large),
      const Divider(),
      const Text('Acompanhamento de estudos'),
      const Text(
        'Indicadores estarão disponíveis quando os módulos de estudo forem implementados.',
      ),
    ],
  );
}
