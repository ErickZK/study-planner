import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../app/theme/app_theme.dart';
import '../../planner/application/planner_providers.dart';
import '../../planner/data/planner_repository.dart';
import '../../planner/presentation/activity_completion_dialog.dart';
import '../application/dashboard_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dashboardProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(dashboardProvider),
            child: const Text(
              'Não foi possível carregar o painel. Tentar novamente',
            ),
          ),
        ),
        data: (data) => LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                narrow ? 16 : 32,
                20,
                narrow ? 16 : 32,
                32,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(DateTime.now()),
                            style: const TextStyle(
                              color: AppTokens.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            data.schedule == null
                                ? 'Seu espaço de estudo'
                                : 'Bom estudo! 👋',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            data.schedule?.name ??
                                'Organize seus estudos em um só lugar.',
                            style: const TextStyle(color: AppTokens.muted),
                          ),
                        ],
                      ),
                    ),
                    if (!narrow && data.next != null)
                      OutlinedButton.icon(
                        onPressed: () => _start(context, data.next!),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Foco'),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                _metrics(data, narrow),
                const SizedBox(height: 18),
                if (data.schedule == null)
                  _card(
                    'Comece seu planejamento',
                    Icons.calendar_month_outlined,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nenhum cronograma por enquanto.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.go('/schedules'),
                          icon: const Icon(Icons.add),
                          label: const Text('Criar cronograma'),
                        ),
                      ],
                    ),
                  )
                else if (narrow) ...[
                  _tasks(context, ref, data),
                  const SizedBox(height: 16),
                  _next(context, data),
                  const SizedBox(height: 16),
                  _weekly(data),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _tasks(context, ref, data)),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _next(context, data),
                            const SizedBox(height: 16),
                            _weekly(data),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      );

  Widget _metrics(DashboardData d, bool narrow) {
    final goal = (d.schedule?.dailyMinutes ?? 0) * 60;
    final coverage = d.syllabusTotal == 0
        ? 0.0
        : d.syllabusDone / d.syllabusTotal;
    final scheduleProgress = d.scheduleTotal == 0
        ? 0.0
        : d.scheduleDone / d.scheduleTotal;
    final rows = <(String, String, String, IconData, double?)>[
      (
        'Meta do dia',
        _duration(d.todaySeconds),
        goal == 0 ? '' : ' / ${_duration(goal)}',
        Icons.track_changes,
        goal == 0 ? null : (d.todaySeconds / goal).clamp(0, 1).toDouble(),
      ),
      (
        'Edital (cobertura)',
        '${(coverage * 100).round()}%',
        '',
        Icons.description_outlined,
        coverage,
      ),
      (
        'Cronograma',
        '${(scheduleProgress * 100).round()}%',
        '',
        Icons.calendar_today_outlined,
        scheduleProgress,
      ),
      ('Revisões pendentes', '${d.reviews}', '', Icons.layers_outlined, null),
      (
        'Questões (mês)',
        '${d.monthQuestions}',
        '',
        Icons.bar_chart_outlined,
        null,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: narrow ? 2 : 5,
        mainAxisExtent: narrow ? 112 : 110,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (_, i) {
        final x = rows[i];
        final tints = <Color>[
          AppTokens.lavender,
          AppTokens.yellowSoft,
          AppTokens.blueSoft,
          AppTokens.greenSoft,
          AppTokens.redSoft,
        ];
        final colors = <Color>[
          AppTokens.purple,
          AppTokens.orange,
          AppTokens.blue,
          AppTokens.green,
          AppTokens.coral,
        ];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(
                        color: tints[i],
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(x.$4, size: 18, color: colors[i]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        x.$1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: x.$2,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: x.$3,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (x.$5 != null)
                  LinearProgressIndicator(
                    value: x.$5,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                    color: colors[i],
                    backgroundColor: AppTokens.border,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(String title, IconData icon, Widget body, {Widget? action}) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: 14),
              body,
            ],
          ),
        ),
      );

  Widget _tasks(BuildContext context, WidgetRef ref, DashboardData d) => _card(
    'Cronograma de hoje',
    Icons.calendar_month_outlined,
    d.activities.isEmpty
        ? const Text(
            'Nenhuma atividade para hoje.',
            style: TextStyle(color: AppTokens.muted),
          )
        : Column(
            children: [
              for (final a in d.activities) _activity(context, ref, a),
            ],
          ),
    action: TextButton.icon(
      onPressed: () => context.go('/planner/${d.schedule!.id}'),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Tarefa'),
    ),
  );

  Widget _activity(BuildContext context, WidgetRef ref, PlannedActivity a) =>
      Container(
        decoration: BoxDecoration(
          color: a.status == 'done' ? null : AppTokens.lavender,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Checkbox(
              value: a.status == 'done',
              onChanged: (value) async {
                if (value == true) {
                  final completed = await completeActivityWithReview(
                    context,
                    ref,
                    a,
                  );
                  if (!completed) return;
                } else {
                  await ref
                      .read(plannerRepositoryProvider)
                      .setStatus(a.id, 'pending');
                }
                ref.invalidate(dashboardProvider);
              },
            ),
            Expanded(
              child: InkWell(
                onTap: () => _start(context, a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: a.status == 'done'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Text(
                        '${a.plannedMinutes} min planejados',
                        style: const TextStyle(
                          color: AppTokens.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Iniciar ${a.title}',
              onPressed: () => _start(context, a),
              icon: const Icon(Icons.play_circle_outline),
            ),
          ],
        ),
      );

  Widget _next(BuildContext context, DashboardData d) => _card(
    'Próximo estudo',
    Icons.menu_book_outlined,
    d.next == null
        ? const Text(
            'Nenhum estudo pendente hoje.',
            style: TextStyle(color: AppTokens.muted),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.next!.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${d.next!.plannedMinutes} min planejados',
                style: const TextStyle(color: AppTokens.muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _start(context, d.next!),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar sessão'),
                ),
              ),
            ],
          ),
  );

  Widget _weekly(DashboardData d) => _card(
    'Progresso semanal',
    Icons.bar_chart_outlined,
    Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(_duration(d.weekSeconds)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final seconds in d.weekDays)
                Container(
                  width: 20,
                  height:
                      (seconds == 0 ? 4 : (seconds / 14400 * 65).clamp(8, 65))
                          .toDouble(),
                  decoration: BoxDecoration(
                    color: seconds == 0 ? AppTokens.border : AppTokens.ink,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('Seg'),
            Text('Ter'),
            Text('Qua'),
            Text('Qui'),
            Text('Sex'),
            Text('Sáb'),
            Text('Dom'),
          ],
        ),
      ],
    ),
  );

  void _start(BuildContext context, PlannedActivity a) =>
      context.go('/study/${a.id}/${a.plannedMinutes}');
  String _duration(int seconds) =>
      '${seconds ~/ 3600}h${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}';
}
