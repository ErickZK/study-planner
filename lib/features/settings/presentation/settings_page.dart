import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:study_planner/app/theme/app_theme.dart';

import '../../../app/widgets/planner_ui.dart';
import '../../../core/platform/windows_taskbar_widget.dart';
import '../../../core/platform/android_home_widget.dart';
import '../../projects/application/project_providers.dart';
import '../../schedules/application/schedule_providers.dart';
import '../../schedules/data/schedule_repository.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _settingsSection = 0;
  int? _focusScheduleId;
  int? _focusMinutes;
  int? _shortBreakMinutes;
  int? _longBreakMinutes;
  int? _roundsPerLongBreak;
  bool _savingFocus = false;

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmação'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteAllData() async {
    if (!await _confirm('Apagar todos os dados locais?')) return;
    await ref.read(databaseProvider).requireValue.clearAllData();
    ref.invalidate(databaseProvider);
    if (mounted) showPlannerNotice(context, 'Todos os dados foram apagados');
  }

  Future<void> _openWidget() async {
    if (Platform.isAndroid) {
      final requested = await requestAndroidHomeWidget();
      if (!requested && mounted) {
        showPlannerNotice(context, 'Abra o seletor de widgets da tela inicial');
      }
      return;
    }
    await startWindowsTaskbarWidget();
  }

  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.settings_outlined,
    title: 'Configurações',
    subtitle: 'Personalize o foco, os widgets e os dados locais.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 980;
        final selectedPanel = switch (_settingsSection) {
          0 => _widgetPanel(),
          1 => _focusPanel(),
          _ => _dataPanel(),
        };
        return Column(
          children: [
            if (narrow) ...[
              _settingsMenu(horizontal: true),
              const SizedBox(height: 12),
              selectedPanel,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 250, child: _settingsMenu()),
                  const SizedBox(width: 14),
                  Expanded(child: selectedPanel),
                ],
              ),
          ],
        );
      },
    ),
  );

  Widget _settingsMenu({bool horizontal = false}) {
    final items = const [
      (Icons.widgets_outlined, 'Widget'),
      (Icons.timer_outlined, 'Foco 🍅'),
      (Icons.storage_outlined, 'Dados locais'),
    ];
    if (horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: i == _settingsSection,
                  avatar: Icon(items[i].$1, size: 17),
                  label: Text(items[i].$2),
                  onSelected: (_) => setState(() => _settingsSection = i),
                ),
              ),
          ],
        ),
      );
    }
    return PlannerCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            ListTile(
              dense: true,
              selected: i == _settingsSection,
              selectedTileColor: AppTokens.lavender,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: Icon(items[i].$1),
              title: Text(
                items[i].$2,
                style: TextStyle(
                  fontWeight: i == _settingsSection
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              onTap: () => setState(() => _settingsSection = i),
            ),
        ],
      ),
    );
  }

  Widget _widgetPanel() => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          Platform.isAndroid ? 'Widget do Android' : 'Widget do Windows',
          icon: Icons.widgets_outlined,
        ),
        const SizedBox(height: 5),
        Text(
          Platform.isAndroid
              ? 'Acompanhe o pomodoro e as tarefas na tela inicial.'
              : 'Acompanhe seu estudo na barra de tarefas do Windows.',
          style: TextStyle(color: AppTokens.muted),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _openWidget,
          child: Container(
            height: 165,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF65B7FF),
                  Color(0xFF0757DD),
                  Color(0xFF0B2A78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xEAF4F6FA),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_arrow_up),
                      SizedBox(width: 10),
                      Icon(Icons.balance),
                      SizedBox(width: 7),
                      Text(
                        '02:17:36',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 18),
                      Icon(Icons.volume_up_outlined),
                      SizedBox(width: 12),
                      Icon(Icons.wifi),
                      SizedBox(width: 12),
                      Icon(Icons.battery_full),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _openWidget,
          icon: const Icon(Icons.open_in_new),
          label: Text(
            Platform.isAndroid ? 'Adicionar à tela inicial' : 'Abrir widget',
          ),
        ),
      ],
    ),
  );

  Widget _focusPanel() => ref
      .watch(allSchedulesProvider)
      .when(
        loading: () => const PlannerCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        error: (_, _) => PlannerCard(
          child: Center(
            child: TextButton.icon(
              onPressed: () => ref.invalidate(allSchedulesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ),
        ),
        data: (schedules) {
          if (schedules.isEmpty) {
            return const PlannerCard(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text('🍅', style: TextStyle(fontSize: 38)),
                    SizedBox(height: 10),
                    Text(
                      'Crie um plano de estudos para configurar o Pomodoro.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final schedule = schedules.firstWhere(
            (item) => item.id == _focusScheduleId,
            orElse: () => schedules.first,
          );
          final focus = _focusMinutes ?? schedule.focusMinutes;
          final shortBreak = _shortBreakMinutes ?? schedule.breakMinutes;
          final longBreak = _longBreakMinutes ?? schedule.longBreakMinutes;
          final rounds = _roundsPerLongBreak ?? schedule.roundsPerLongBreak;
          return PlannerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  'Configuração de foco',
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Defina o ritmo de cada planejamento. O aplicativo e os widgets usam estes mesmos valores.',
                  style: TextStyle(color: AppTokens.muted),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  key: ValueKey('schedule-${schedule.id}'),
                  initialValue: schedule.id,
                  decoration: const InputDecoration(labelText: 'Planejamento'),
                  items: [
                    for (final item in schedules)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    final selected = schedules.firstWhere(
                      (item) => item.id == id,
                    );
                    setState(() {
                      _focusScheduleId = selected.id;
                      _focusMinutes = selected.focusMinutes;
                      _shortBreakMinutes = selected.breakMinutes;
                      _longBreakMinutes = selected.longBreakMinutes;
                      _roundsPerLongBreak = selected.roundsPerLongBreak;
                    });
                  },
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 680
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _focusDropdown(
                          width: width,
                          label: 'Tempo de foco',
                          emoji: '🍅',
                          value: focus,
                          values: const [15, 20, 25, 30, 40, 45, 50, 60],
                          onChanged: (value) =>
                              setState(() => _focusMinutes = value),
                        ),
                        _focusDropdown(
                          width: width,
                          label: 'Pausa curta',
                          emoji: '☕',
                          value: shortBreak,
                          values: const [3, 5, 10, 15],
                          onChanged: (value) =>
                              setState(() => _shortBreakMinutes = value),
                        ),
                        _focusDropdown(
                          width: width,
                          label: 'Pausa longa',
                          emoji: '🌿',
                          value: longBreak,
                          values: const [10, 15, 20, 25, 30],
                          onChanged: (value) =>
                              setState(() => _longBreakMinutes = value),
                        ),
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('rounds-$rounds-${schedule.id}'),
                            initialValue: rounds,
                            decoration: const InputDecoration(
                              prefixText: '🔁  ',
                              labelText: 'Ciclos antes da pausa longa',
                            ),
                            items: [
                              for (final value in const [2, 3, 4, 5, 6])
                                DropdownMenuItem(
                                  value: value,
                                  child: Text('$value ciclos'),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _roundsPerLongBreak = value),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTokens.lavender,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text('⏱️', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$focus min de foco + $shortBreak min de pausa. A cada $rounds ciclos: $longBreak min de pausa longa.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _savingFocus
                      ? null
                      : () => _saveFocus(
                          schedule,
                          focus,
                          shortBreak,
                          longBreak,
                          rounds,
                        ),
                  icon: _savingFocus
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Salvar configuração'),
                ),
              ],
            ),
          );
        },
      );

  Widget _focusDropdown({
    required double width,
    required String label,
    required String emoji,
    required int value,
    required List<int> values,
    required ValueChanged<int?> onChanged,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<int>(
      key: ValueKey('$label-$value-${_focusScheduleId ?? 0}'),
      initialValue: value,
      decoration: InputDecoration(prefixText: '$emoji  ', labelText: label),
      items: [
        for (final minutes in values)
          DropdownMenuItem(value: minutes, child: Text('$minutes minutos')),
      ],
      onChanged: onChanged,
    ),
  );

  Future<void> _saveFocus(
    StudySchedule schedule,
    int focus,
    int shortBreak,
    int longBreak,
    int rounds,
  ) async {
    setState(() => _savingFocus = true);
    await ref
        .read(scheduleRepositoryProvider)
        .update(
          schedule.id,
          focusMinutes: focus,
          breakMinutes: shortBreak,
          longBreakMinutes: longBreak,
          roundsPerLongBreak: rounds,
        );
    ref.invalidate(allSchedulesProvider);
    ref.invalidate(schedulesProvider(schedule.projectId));
    ref.invalidate(allSchedulesProvider);
    await refreshAndroidHomeWidget();
    if (!mounted) return;
    setState(() {
      _savingFocus = false;
      _focusMinutes = focus;
      _shortBreakMinutes = shortBreak;
      _longBreakMinutes = longBreak;
      _roundsPerLongBreak = rounds;
    });
    showPlannerNotice(context, 'Configuração de foco salva');
  }

  Widget _dataPanel() => PlannerCard(
    child: Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppTokens.error),
              onPressed: _deleteAllData,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Apagar todos os dados'),
            );
            final heading = const Row(
              children: [
                Icon(Icons.storage_outlined, size: 27),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dados locais',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Remova os dados armazenados neste dispositivo.',
                        style: TextStyle(color: AppTokens.muted),
                      ),
                    ],
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 1050) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 12), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                actions,
              ],
            );
          },
        ),
      ],
    ),
  );
}
