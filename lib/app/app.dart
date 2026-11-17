import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/projects/application/project_providers.dart';
import '../core/platform/windows_navigation.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class StudyPlannerApp extends ConsumerStatefulWidget {
  const StudyPlannerApp({super.key});

  @override
  ConsumerState<StudyPlannerApp> createState() => _StudyPlannerAppState();
}

class _StudyPlannerAppState extends ConsumerState<StudyPlannerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      attachWindowsNavigation((route) => ref.read(routerProvider).go(route));
    });
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);
    return MaterialApp.router(
      title: 'Study Planner',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => database.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.large),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível abrir os dados locais.'),
                    const Text(
                      'Seus dados não foram apagados. Verifique o armazenamento e tente novamente.',
                    ),
                    const SizedBox(height: AppTokens.medium),
                    FilledButton(
                      onPressed: () => ref.invalidate(databaseProvider),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        data: (_) => child!,
      ),
    );
  }
}
