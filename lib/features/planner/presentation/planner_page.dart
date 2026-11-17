import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/planner_ui.dart';
import '../../schedules/application/schedule_providers.dart';
import '../../schedules/data/schedule_repository.dart';
import '../application/planner_providers.dart';
import '../data/planner_repository.dart';
import 'activity_completion_dialog.dart';

class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({required this.scheduleId, super.key});
  final int scheduleId;

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  DateTime selected = DateTime.now();
  String mode = 'Mês';

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  DateTime get rangeStart => switch (mode) {
    'Mês' => DateTime(selected.year, selected.month, 1),
    'Semana' => selected.subtract(Duration(days: selected.weekday - 1)),
    _ => selected,
  };

  DateTime get rangeEnd => switch (mode) {
    'Mês' => DateTime(selected.year, selected.month + 1, 0),
    'Semana' => rangeStart.add(const Duration(days: 6)),
    _ => selected,
  };

  void _move(int amount) => setState(() {
    selected = switch (mode) {
      'Mês' => DateTime(selected.year, selected.month + amount, 1),
      'Semana' => selected.add(Duration(days: amount * 7)),
      _ => selected.add(Duration(days: amount)),
    };
  });

  Future<void> _activityDialog({
    PlannedActivity? activity,
    DateTime? date,
  }) async {
    final title = TextEditingController(text: activity?.title ?? '');
    final minutes = TextEditingController(
      text: '${activity?.plannedMinutes ?? 60}',
    );
    var chosenDate = activity == null
        ? (date ?? selected)
        : DateTime.parse(activity.date);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            activity == null ? 'Nova sessão de estudo' : 'Editar sessão',
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Disciplina ou atividade',
                    hintText:
                        'Ex.: Direito Administrativo — Atos administrativos',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: chosenDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDialogState(() => chosenDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: Text(_fullDate(chosenDate)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: minutes,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duração',
                          suffixText: 'min',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && title.text.trim().isNotEmpty) {
      final duration = int.tryParse(minutes.text) ?? 60;
      if (activity == null) {
        await ref
            .read(plannerRepositoryProvider)
            .create(
              widget.scheduleId,
              _date(chosenDate),
              title.text,
              plannedMinutes: duration.clamp(5, 600),
            );
      } else {
        await ref
            .read(plannerRepositoryProvider)
            .updateActivity(
              activity.id,
              title: title.text,
              date: _date(chosenDate),
              plannedMinutes: duration.clamp(5, 600),
            );
      }
      if (mounted) setState(() => selected = chosenDate);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    minutes.dispose();
  }

  Future<void> _delete(PlannedActivity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir esta sessão?'),
        content: Text(activity.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(plannerRepositoryProvider).delete(activity.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _moveActivity(
    PlannedActivity activity,
    DateTime destination,
  ) async {
    final target = _date(destination);
    if (target == activity.date) return;
    await ref
        .read(plannerRepositoryProvider)
        .updateActivity(activity.id, date: target);
    if (mounted) setState(() {});
  }

  Future<void> _rescheduleOverdue() async {
    final total = await ref
        .read(plannerRepositoryProvider)
        .rescheduleOverdue(widget.scheduleId);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          total == 0
              ? 'Não há atividades atrasadas.'
              : '$total atividade${total == 1 ? '' : 's'} reagendada${total == 1 ? '' : 's'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final from = _date(rangeStart);
    final to = _date(rangeEnd);
    final repository = ref.read(plannerRepositoryProvider);
    return FutureBuilder<StudySchedule>(
      future: ref.read(scheduleRepositoryProvider).get(widget.scheduleId),
      builder: (context, scheduleSnapshot) =>
          FutureBuilder<List<PlannedActivity>>(
            future: repository.listRange(widget.scheduleId, from, to),
            builder: (context, activitySnapshot) {
              if (!scheduleSnapshot.hasData || !activitySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final schedule = scheduleSnapshot.data!;
              final activities = activitySnapshot.data!;
              final completed = activities
                  .where((item) => item.status == 'done')
                  .length;
              final minutes = activities.fold<int>(
                0,
                (sum, item) => sum + item.plannedMinutes,
              );
              return Column(
                children: [
                  _PlannerHeader(
                    schedule: schedule,
                    mode: mode,
                    rangeLabel: _rangeLabel(rangeStart, rangeEnd, mode),
                    activities: activities.length,
                    completed: completed,
                    minutes: minutes,
                    onMode: (value) => setState(() => mode = value),
                    onPrevious: () => _move(-1),
                    onNext: () => _move(1),
                    onToday: () => setState(() => selected = DateTime.now()),
                    onAdd: () => _activityDialog(date: selected),
                    onReschedule: _rescheduleOverdue,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final calendar = mode == 'Mês'
                              ? _month(activities)
                              : mode == 'Semana'
                              ? _week(activities)
                              : _dayList(activities);
                          if (constraints.maxWidth < 1080 || mode != 'Mês') {
                            return calendar;
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: calendar),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 286,
                                child: _monthSummary(
                                  activities,
                                  completed,
                                  minutes,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _monthSummary(
    List<PlannedActivity> activities,
    int completed,
    int minutes,
  ) {
    final progress = activities.isEmpty ? 0.0 : completed / activities.length;
    final completedDays = activities
        .where((activity) => activity.status == 'done')
        .map((activity) => activity.date)
        .toSet()
        .length;
    final distribution = <String, int>{};
    for (final activity in activities) {
      final title = activity.title.toLowerCase();
      final discipline = demoDisciplines.firstWhere((name) {
        final token = name
            .toLowerCase()
            .replaceAll('dir. ', '')
            .replaceAll('proc. ', '');
        return title.contains(token.split(' ').first);
      }, orElse: () => 'Outros');
      distribution.update(
        discipline,
        (value) => value + activity.plannedMinutes,
        ifAbsent: () => activity.plannedMinutes,
      );
    }
    final rows = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return PlannerCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Resumo do mês', icon: Icons.bar_chart_outlined),
          const Divider(height: 24),
          _summaryRow(
            Icons.schedule_outlined,
            'Horas planejadas',
            _duration(minutes),
          ),
          const SizedBox(height: 14),
          _summaryRow(
            Icons.check_box_outlined,
            'Sessões concluídas',
            '$completed / ${activities.length}',
          ),
          const SizedBox(height: 8),
          MiniProgress(value: progress, color: AppTokens.green),
          const SizedBox(height: 14),
          _summaryRow(
            Icons.local_fire_department_outlined,
            'Sequência de estudos',
            '$completedDays dias',
          ),
          const Divider(height: 28),
          const Text(
            'Disciplinas (horas planejadas)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'Nenhuma sessão planejada neste mês.',
              style: TextStyle(color: AppTokens.muted),
            ),
          for (final entry in rows.take(12))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color:
                          disciplinePalette[(entry.key.hashCode & 0x7fffffff) %
                              disciplinePalette.length],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    _duration(entry.value),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 9),
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );

  Widget _dayList(List<PlannedActivity> activities) => ListView(
    children: [
      _DayColumn(
        date: selected,
        activities: activities,
        expanded: true,
        onAdd: () => _activityDialog(date: selected),
        onMove: _moveActivity,
        cardBuilder: _activityCard,
      ),
    ],
  );

  Widget _week(List<PlannedActivity> activities) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 720) {
        return ListView(
          children: [
            for (var index = 0; index < 7; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _dayForIndex(index, activities, expanded: true),
              ),
          ],
        );
      }
      final width = constraints.maxWidth < 1050 ? 1050.0 : constraints.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 6 ? 0 : 8),
                    child: _dayForIndex(index, activities),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _dayForIndex(
    int index,
    List<PlannedActivity> activities, {
    bool expanded = false,
  }) {
    final date = rangeStart.add(Duration(days: index));
    final key = _date(date);
    return _DayColumn(
      date: date,
      activities: activities.where((item) => item.date == key).toList(),
      expanded: expanded,
      onAdd: () => _activityDialog(date: date),
      onMove: _moveActivity,
      cardBuilder: _activityCard,
    );
  }

  Widget _month(List<PlannedActivity> activities) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 900 ? 900.0 : constraints.maxWidth;
      final height = constraints.maxHeight < 620
          ? 620.0
          : constraints.maxHeight;
      final grid = SizedBox(
        width: width,
        height: height,
        child: _monthGrid(activities),
      );
      if (width == constraints.maxWidth && height == constraints.maxHeight) {
        return grid;
      }
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: grid,
        ),
      );
    },
  );

  Widget _monthGrid(List<PlannedActivity> activities) {
    final first = DateTime(selected.year, selected.month, 1);
    final days = DateTime(selected.year, selected.month + 1, 0).day;
    final cells = first.weekday - 1 + days;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFFAFAFB),
            child: Row(
              children: [
                for (final label in _weekShort)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTokens.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemCount = ((cells + 6) ~/ 7) * 7;
                final rows = itemCount ~/ 7;
                final cellWidth = constraints.maxWidth / 7;
                final cellHeight = constraints.maxHeight / rows;
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: cellWidth / cellHeight,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    final day = index - first.weekday + 2;
                    if (day < 1 || day > days) {
                      return const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFFAFAFB),
                          border: Border.fromBorderSide(
                            BorderSide(color: AppTokens.border, width: .5),
                          ),
                        ),
                      );
                    }
                    final date = DateTime(selected.year, selected.month, day);
                    final dayItems = activities
                        .where((item) => item.date == _date(date))
                        .toList();
                    return _MonthCell(
                      date: date,
                      activities: dayItems,
                      onOpen: () => setState(() {
                        selected = date;
                        mode = 'Dia';
                      }),
                      onMove: _moveActivity,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityCard(PlannedActivity activity) {
    final palette = _activityPalette(activity.title);
    final card = _ActivityCard(
      activity: activity,
      color: palette.$1,
      softColor: palette.$2,
      onToggle: () async {
        if (activity.status == 'done') {
          await ref
              .read(plannerRepositoryProvider)
              .setStatus(activity.id, 'pending');
        } else {
          final completed = await completeActivityWithReview(
            context,
            ref,
            activity,
          );
          if (!completed) return;
        }
        if (mounted) setState(() {});
      },
      onStart: () =>
          context.go('/study/${activity.id}/${activity.plannedMinutes}'),
      onEdit: () => _activityDialog(activity: activity),
      onDelete: () => _delete(activity),
    );
    return AdaptiveDraggable<PlannedActivity>(
      data: activity,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 220, child: card),
      ),
      childWhenDragging: Opacity(opacity: .35, child: card),
      child: card,
    );
  }
}

class _PlannerHeader extends StatelessWidget {
  const _PlannerHeader({
    required this.schedule,
    required this.mode,
    required this.rangeLabel,
    required this.activities,
    required this.completed,
    required this.minutes,
    required this.onMode,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onAdd,
    required this.onReschedule,
  });
  final StudySchedule schedule;
  final String mode, rangeLabel;
  final int activities, completed, minutes;
  final ValueChanged<String> onMode;
  final VoidCallback onPrevious, onNext, onToday, onAdd, onReschedule;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1050;
        final modes = SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Dia',
              label: Text('Dia'),
              icon: Icon(Icons.view_day_outlined),
            ),
            ButtonSegment(
              value: 'Semana',
              label: Text('Semana'),
              icon: Icon(Icons.view_week_outlined),
            ),
            ButtonSegment(
              value: 'Mês',
              label: Text('Mês'),
              icon: Icon(Icons.calendar_view_month_outlined),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (value) => onMode(value.first),
        );
        final navigation = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          runSpacing: 6,
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            OutlinedButton(onPressed: onToday, child: const Text('Hoje')),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                rangeLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
        final metrics = Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _MiniMetric(
              icon: Icons.check_circle_outline,
              value: '$completed/$activities',
              label: 'concluídas',
            ),
            _MiniMetric(
              icon: Icons.schedule_outlined,
              value: _duration(minutes),
              label: 'planejadas',
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 3),
            Text(
              'Agenda adaptável · ${_duration(schedule.dailyMinutes)} por dia',
              style: const TextStyle(color: AppTokens.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onReschedule,
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                  label: const Text('Replanejar atrasos'),
                ),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova sessão'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (compact) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: modes,
              ),
              const SizedBox(height: 8),
              navigation,
              const SizedBox(height: 8),
              metrics,
            ] else
              Row(
                children: [
                  modes,
                  const SizedBox(width: 12),
                  navigation,
                  const Spacer(),
                  metrics,
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19),
      const SizedBox(width: 7),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTokens.muted),
          ),
        ],
      ),
    ],
  );
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.activities,
    required this.expanded,
    required this.onAdd,
    required this.onMove,
    required this.cardBuilder,
  });
  final DateTime date;
  final List<PlannedActivity> activities;
  final bool expanded;
  final VoidCallback onAdd;
  final Future<void> Function(PlannedActivity, DateTime) onMove;
  final Widget Function(PlannedActivity) cardBuilder;

  @override
  Widget build(BuildContext context) {
    final today = _sameDate(date, DateTime.now());
    return DragTarget<PlannedActivity>(
      onAcceptWithDetails: (details) => onMove(details.data, date),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: expanded ? const BoxConstraints(minHeight: 170) : null,
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? AppTokens.lavender : Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: today ? AppTokens.ink : AppTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: today ? AppTokens.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: today ? Colors.white : AppTokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _weekNames[date.weekday - 1],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Adicionar neste dia',
                    visualDensity: VisualDensity.compact,
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                child: Text(
                  'Arraste uma sessão para cá',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTokens.muted),
                ),
              ),
            for (final activity in activities)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: cardBuilder(activity),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.color,
    required this.softColor,
    required this.onToggle,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
  });
  final PlannedActivity activity;
  final Color color, softColor;
  final VoidCallback onToggle, onStart, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final done = activity.status == 'done';
    return Container(
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 9, 5, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(5),
                  child: Icon(
                    done ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color: done ? AppTokens.green : AppTokens.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    activity.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? AppTokens.muted : AppTokens.ink,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 17,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '${activity.plannedMinutes} min',
                  style: const TextStyle(fontSize: 11, color: AppTokens.muted),
                ),
                const Spacer(),
                if (!done)
                  InkWell(
                    onTap: onStart,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 20,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.activities,
    required this.onOpen,
    required this.onMove,
  });
  final DateTime date;
  final List<PlannedActivity> activities;
  final VoidCallback onOpen;
  final Future<void> Function(PlannedActivity, DateTime) onMove;

  @override
  Widget build(BuildContext context) {
    final completed = activities.where((item) => item.status == 'done').length;
    final minutes = activities.fold<int>(
      0,
      (total, item) => total + item.plannedMinutes,
    );
    final today = _sameDate(date, DateTime.now());
    final now = DateTime.now();
    final overdue =
        date.isBefore(DateTime(now.year, now.month, now.day)) &&
        activities.any((item) => item.status != 'done');
    return DragTarget<PlannedActivity>(
      onAcceptWithDetails: (details) => onMove(details.data, date),
      builder: (context, candidates, _) => InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: candidates.isNotEmpty ? AppTokens.lavender : Colors.white,
            border: Border.all(color: AppTokens.border, width: .5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 23,
                    height: 23,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: today ? AppTokens.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: today ? Colors.white : AppTokens.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (overdue)
                    const Tooltip(
                      message: 'Há sessões atrasadas',
                      child: Icon(
                        Icons.error_outline,
                        size: 14,
                        color: AppTokens.error,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              for (final item in activities.take(2))
                AdaptiveDraggable<PlannedActivity>(
                  data: item,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(width: 190, child: _monthActivity(item)),
                  ),
                  childWhenDragging: Opacity(
                    opacity: .3,
                    child: _monthActivity(item),
                  ),
                  child: _monthActivity(item),
                ),
              if (activities.length > 2)
                Text(
                  '+${activities.length - 2}',
                  style: const TextStyle(fontSize: 9, color: AppTokens.muted),
                ),
              const Spacer(),
              if (activities.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      completed == activities.length
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 12,
                      color: completed == activities.length
                          ? AppTokens.green
                          : AppTokens.muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$completed/${activities.length}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTokens.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _duration(minutes),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthActivity(PlannedActivity item) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 2),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: _activityPalette(item.title).$2,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      item.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
    ),
  );
}

const _weekShort = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _weekNames = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];
const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${minutes}min';
  return remainder == 0
      ? '${hours}h'
      : '${hours}h${remainder.toString().padLeft(2, '0')}';
}

String _fullDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _rangeLabel(DateTime start, DateTime end, String mode) {
  if (mode == 'Mês') return '${_months[start.month - 1]} de ${start.year}';
  if (mode == 'Dia') {
    return '${_weekNames[start.weekday - 1]}, ${start.day} de ${_months[start.month - 1]}';
  }
  return '${start.day} de ${_months[start.month - 1]} — ${end.day} de ${_months[end.month - 1]}';
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

(Color, Color) _activityPalette(String title) {
  final value = title.toLowerCase();
  if (value.contains('portugu')) {
    return (const Color(0xFF4F8CC9), const Color(0xFFEDF5FD));
  }
  if (value.contains('penal')) {
    return (const Color(0xFFD86F75), const Color(0xFFFFF0F1));
  }
  if (value.contains('constitucional')) {
    return (const Color(0xFFD49A24), const Color(0xFFFFF7E5));
  }
  if (value.contains('administrativo')) {
    return (const Color(0xFF56A76B), const Color(0xFFEDF8F0));
  }
  if (value.contains('civil')) {
    return (const Color(0xFF7C6FD0), const Color(0xFFF2F0FF));
  }
  if (value.contains('matem') || value.contains('lógico')) {
    return (const Color(0xFFB967A8), const Color(0xFFFCEFFA));
  }
  if (value.contains('inform')) {
    return (const Color(0xFF4E9BC7), const Color(0xFFEDF8FD));
  }
  if (value.contains('revis')) {
    return (const Color(0xFF6B7280), const Color(0xFFF1F2F4));
  }
  return (const Color(0xFF7B8494), const Color(0xFFF3F4F6));
}
