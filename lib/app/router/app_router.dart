import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/catalog/presentation/catalog_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/syllabus/presentation/syllabus_page.dart';
import '../../features/schedules/presentation/schedules_page.dart';
import '../../features/planner/presentation/planner_page.dart';
import '../../features/planner/presentation/study_session_page.dart';
import '../../features/overview/presentation/overview_pages.dart';
import '../../features/schedules/application/schedule_providers.dart';
import '../../core/platform/windows_taskbar_widget.dart';
import '../theme/app_theme.dart';

const destinations = <(String, String, IconData)>[
  ('/', 'Página inicial', Icons.home_outlined),
  ('/schedules', 'Plano de estudos', Icons.calendar_month_outlined),
  ('/planner', 'Calendário', Icons.view_week_outlined),
  ('/statistics', 'Estatísticas', Icons.bar_chart_outlined),
  ('/syllabus', 'Conteúdo do edital', Icons.list_alt),
  ('/disciplines', 'Disciplinas e assuntos', Icons.account_tree_outlined),
  ('/settings', 'Configurações', Icons.settings_outlined),
];
String startupRoute = '/';
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: startupRoute,
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
                if (d.$1 == '/disciplines') return const CatalogPage();
                if (d.$1 == '/settings') return const SettingsPage();
                if (d.$1 == '/syllabus') {
                  return const _ScheduleChooser();
                }
                if (d.$1 == '/schedules') {
                  return const SchedulesPage();
                }
                if (d.$1 == '/planner') return const _PlannerChooser();
                if (d.$1 == '/statistics') return const StatisticsPage();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.large),
                    child: Text('${d.$2}: módulo ainda não implementado.'),
                  ),
                );
              },
            ),
          GoRoute(
            path: '/syllabus/:scheduleId',
            builder: (context, state) => SyllabusPage(
              scheduleId: int.parse(state.pathParameters['scheduleId']!),
            ),
          ),
          GoRoute(
            path: '/planner/:scheduleId',
            builder: (context, state) => PlannerPage(
              scheduleId: int.parse(state.pathParameters['scheduleId']!),
            ),
          ),
          GoRoute(
            path: '/study/:activityId/:plannedMinutes',
            builder: (context, state) => StudySessionPage(
              activityId: int.parse(state.pathParameters['activityId']!),
              plannedMinutes: int.parse(
                state.pathParameters['plannedMinutes']!,
              ),
            ),
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
      (d) =>
          d.$1 == path ||
          (d.$1 == '/syllabus' && path.startsWith('/syllabus/')) ||
          (d.$1 == '/schedules' && path.startsWith('/schedules/')) ||
          (d.$1 == '/planner' && path.startsWith('/planner/')) ||
          (d.$1 == '/planner' && path.startsWith('/study/')),
      orElse: () => destinations.first,
    );
    bool selected(String route) =>
        route == path ||
        (route == '/syllabus' && path.startsWith('/syllabus/')) ||
        (route == '/schedules' && path.startsWith('/schedules/')) ||
        (route == '/planner' &&
            (path.startsWith('/planner/') || path.startsWith('/study/')));

    Widget menu() => Builder(
      builder: (menuContext) {
        Widget section(String label) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 7),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );

        Widget item(
          String route,
          String label,
          IconData icon, {
          VoidCallback? action,
        }) {
          final tint = switch (route) {
            '/' => AppTokens.yellowSoft,
            '/schedules' => AppTokens.blueSoft,
            '/planner' => AppTokens.cyanSoft,
            '/statistics' => AppTokens.lavender,
            '/syllabus' => AppTokens.yellowSoft,
            '/disciplines' => AppTokens.redSoft,
            _ => AppTokens.hover,
          };
          final iconColor = switch (route) {
            '/' => AppTokens.orange,
            '/schedules' => AppTokens.blue,
            '/planner' => AppTokens.teal,
            '/statistics' => AppTokens.purple,
            '/syllabus' => AppTokens.orange,
            '/disciplines' => AppTokens.coral,
            _ => AppTokens.muted,
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              minLeadingWidth: 22,
              minTileHeight: 39,
              horizontalTitleGap: 10,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13),
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              selectedColor: AppTokens.ink,
              selectedTileColor: tint.withValues(alpha: .72),
              selected: selected(route),
              leading: Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              title: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected(route)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              onTap: () {
                if (Scaffold.maybeOf(menuContext)?.isDrawerOpen ?? false) {
                  Scaffold.of(menuContext).closeDrawer();
                }
                action?.call();
                if (action == null) context.go(route);
              },
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(11, 16, 11, 10),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(10, 3, 10, 20),
                    child: Row(
                      children: [
                        Text('⚖️', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'TJSP Planner',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  item('/', 'Página inicial', Icons.home_outlined),
                  section('Planejamento'),
                  item(
                    '/schedules',
                    'Plano de estudos',
                    Icons.calendar_month_outlined,
                  ),
                  item('/planner', 'Calendário', Icons.event_outlined),
                  item('/statistics', 'Estatísticas', Icons.bar_chart_outlined),
                  item(
                    '/syllabus',
                    'Conteúdo do edital',
                    Icons.description_outlined,
                  ),
                  section('Disciplinas'),
                  item(
                    '/disciplines',
                    'Gerenciar disciplinas',
                    Icons.account_tree_outlined,
                  ),
                  const Divider(height: 22),
                  item('/settings', 'Configurações', Icons.settings_outlined),
                  if (Platform.isWindows)
                    item(
                      '/widget',
                      'Widget do Windows',
                      Icons.widgets_outlined,
                      action: startWindowsTaskbarWidget,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTokens.hover,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('🎯', style: TextStyle(fontSize: 17)),
                ),
              ),
              title: const Text(
                'TJSP 2026',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: const Text(
                'Escrevente Técnico Judiciário',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5),
              ),
              trailing: const Icon(Icons.keyboard_arrow_down, size: 18),
              onTap: () => context.go('/schedules'),
            ),
          ],
        );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppTokens.desktopBreakpoint;
        return Scaffold(
          appBar: desktop
              ? null
              : AppBar(
                  title: desktop ? null : Text(current.$2),
                  backgroundColor: AppTokens.background,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Abrir navegação',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
          drawer: desktop ? null : Drawer(child: SafeArea(child: menu())),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: const [
                    '/',
                    '/schedules',
                    '/planner',
                    '/syllabus',
                    '/settings',
                  ].indexOf(current.$1).clamp(0, 4),
                  onDestinationSelected: (index) => context.go(
                    const [
                      '/',
                      '/schedules',
                      '/planner',
                      '/syllabus',
                      '/settings',
                    ][index],
                  ),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Início',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      label: 'Plano',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.event_outlined),
                      label: 'Calendário',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.description_outlined),
                      label: 'Edital',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.more_horiz),
                      label: 'Mais',
                    ),
                  ],
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop) ...[
                  Material(
                    color: Colors.white,
                    child: SizedBox(
                      width: AppTokens.sidebarWidth,
                      child: menu(),
                    ),
                  ),
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

class _ScheduleChooser extends ConsumerWidget {
  const _ScheduleChooser();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(allSchedulesProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(allSchedulesProvider),
            child: const Text('Tentar novamente'),
          ),
        ),
        data: (schedules) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Editais verticalizados',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            const Text(
              'Cada edital pertence a um cronograma. Escolha qual deseja editar.',
            ),
            const SizedBox(height: 14),
            if (schedules.isEmpty)
              const Text('Crie um cronograma para começar.'),
            for (final schedule in schedules)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(schedule.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/syllabus/${schedule.id}'),
                ),
              ),
            if (schedules.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () => context.go('/schedules'),
                  child: const Text('Criar cronograma'),
                ),
              ),
          ],
        ),
      );
}

class _PlannerChooser extends ConsumerWidget {
  const _PlannerChooser();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(allSchedulesProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(allSchedulesProvider),
            child: const Text('Tentar novamente'),
          ),
        ),
        data: (schedules) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Planner', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            if (schedules.isEmpty)
              TextButton(
                onPressed: () => context.go('/schedules'),
                child: const Text('Criar cronograma'),
              ),
            for (final schedule in schedules)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(schedule.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/planner/${schedule.id}'),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('/schedules'),
                child: const Text('Gerenciar cronogramas'),
              ),
            ),
          ],
        ),
      );
}
