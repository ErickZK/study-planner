import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/projects/presentation/projects_page.dart';
import '../../features/catalog/presentation/catalog_page.dart';
import '../theme/app_theme.dart';

const destinations = <(String, String, IconData)>[
  ('/', 'Dashboard', Icons.home_outlined),
  ('/projects', 'Projetos', Icons.folder_outlined),
  ('/disciplines', 'Disciplinas', Icons.account_tree_outlined),
  ('/syllabus', 'Edital verticalizado', Icons.list_alt),
  ('/schedules', 'Cronogramas', Icons.calendar_month_outlined),
  ('/planner', 'Planner', Icons.view_agenda_outlined),
  ('/statistics', 'Estatísticas', Icons.bar_chart_outlined),
  ('/library', 'Biblioteca', Icons.library_books_outlined),
  ('/settings', 'Configurações', Icons.settings_outlined),
];
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          for (final d in destinations)
            GoRoute(
              path: d.$1,
              builder: (context, state) {
                if (d.$1 == '/') return const DashboardPage();
                if (d.$1 == '/projects') return const ProjectsPage();
                if (d.$1 == '/disciplines') return const CatalogPage();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.large),
                    child: Text('${d.$2}: módulo ainda não implementado.'),
                  ),
                );
              },
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class AppShell extends StatelessWidget {
  const AppShell({required this.path, required this.child, super.key});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final current = destinations.firstWhere(
      (d) => d.$1 == path,
      orElse: () => destinations.first,
    );
    Widget menu() => Builder(
      builder: (menuContext) => ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(AppTokens.large),
            child: Text('Study Planner'),
          ),
          for (final d in destinations)
            ListTile(
              selected: d.$1 == path,
              leading: Icon(d.$3),
              title: Text(d.$2),
              onTap: () {
                if (Scaffold.maybeOf(menuContext)?.isDrawerOpen ?? false) {
                  Scaffold.of(menuContext).closeDrawer();
                }
                context.go(d.$1);
              },
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppTokens.desktopBreakpoint;
        return Scaffold(
          appBar: AppBar(
            title: Text(current.$2),
            backgroundColor: Colors.white,
            leading: desktop
                ? null
                : Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Abrir navegação',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
          ),
          drawer: desktop ? null : Drawer(child: SafeArea(child: menu())),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop) ...[
                  SizedBox(width: 250, child: menu()),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
