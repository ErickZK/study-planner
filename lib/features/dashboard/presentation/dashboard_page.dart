import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../projects/application/project_providers.dart';
import '../../../app/theme/app_theme.dart';

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
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(project.name),
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
