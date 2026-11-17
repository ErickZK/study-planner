import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/planner_repository.dart';
import '../application/planner_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/planner_ui.dart';
import '../../../core/platform/android_home_widget.dart';
import '../../syllabus/application/syllabus_providers.dart';
import 'activity_completion_dialog.dart';

class StudySessionPage extends ConsumerStatefulWidget {
  const StudySessionPage({
    required this.activityId,
    required this.plannedMinutes,
    super.key,
  });
  final int activityId, plannedMinutes;
  @override
  ConsumerState<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends ConsumerState<StudySessionPage> {
  int pomodoroFocusSeconds = 25 * 60;
  int shortBreakSeconds = 5 * 60;
  int longBreakSeconds = 15 * 60;
  int roundsPerLongBreak = 4;

  Timer? ticker;
  int finishedSeconds = 0;
  int activeBaseSeconds = 0;
  int? runningStartedAt;
  int? sessionId;
  String state = 'idle';
  bool transitioning = false;
  int difficulty = 1;
  int workspaceTab = 0;
  int questionCount = 10;
  List<String?> questionAnswers = List.filled(10, null);
  List<bool?> questionResults = List.filled(10, null);
  List<StudyMaterialRecord> materials = const [];
  List<QuestionAttemptRecord> questionAttempts = const [];
  List<StudySessionRecord> history = const [];
  String activityTitle = 'Sessão de estudo';
  final notesController = TextEditingController();
  final questionCountController = TextEditingController(text: '10');
  bool notesDirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    ticker?.cancel();
    notesController.dispose();
    questionCountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(plannerRepositoryProvider);
    final results = await Future.wait([
      repo.sessions(widget.activityId),
      repo.findActivity(widget.activityId),
      repo.pomodoroSettings(widget.activityId),
      repo.materials(widget.activityId),
      repo.activityNotes(widget.activityId),
      repo.questionAttempts(widget.activityId),
    ]);
    final records = results[0] as List<StudySessionRecord>;
    final activity = results[1] as PlannedActivity?;
    final settings = results[2] as PomodoroSettings;
    final loadedMaterials = results[3] as List<StudyMaterialRecord>;
    final loadedNotes = results[4] as String;
    final loadedAttempts = results[5] as List<QuestionAttemptRecord>;
    if (!mounted) return;
    final openRecords = records
        .where(
          (record) =>
              record.status == 'paused' ||
              record.status == 'running' ||
              record.status == 'break',
        )
        .toList();
    final open = openRecords.isEmpty ? null : openRecords.last;
    ticker?.cancel();
    setState(() {
      history = records;
      activityTitle = activity?.title ?? 'Sessão de estudo';
      materials = loadedMaterials;
      questionAttempts = loadedAttempts;
      if (!notesDirty) notesController.text = loadedNotes;
      pomodoroFocusSeconds = settings.focusMinutes * 60;
      shortBreakSeconds = settings.shortBreakMinutes * 60;
      longBreakSeconds = settings.longBreakMinutes * 60;
      roundsPerLongBreak = settings.roundsPerLongBreak;
      sessionId = open?.id;
      state = open?.status ?? 'idle';
      finishedSeconds = records
          .where((record) => record.status == 'finished')
          .fold(0, (sum, record) => sum + record.seconds);
      activeBaseSeconds = open?.accumulatedSeconds ?? 0;
      runningStartedAt = open?.startedAt;
    });
    if (open?.status == 'running' || open?.status == 'break') {
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    await refreshAndroidHomeWidget();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (transitioning) return;
    if (state == 'running' && focusBlockElapsed >= pomodoroFocusSeconds) {
      unawaited(_completeFocusBlock());
    } else if (state == 'break' && breakRemaining <= 0) {
      unawaited(_skipBreak());
    }
  }

  String _format(int seconds) =>
      '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  int get currentSessionSeconds {
    if (state != 'running' || runningStartedAt == null) {
      return activeBaseSeconds;
    }
    final delta =
        (DateTime.now().toUtc().millisecondsSinceEpoch - runningStartedAt!) ~/
        1000;
    return activeBaseSeconds + delta.clamp(0, 86400 * 30);
  }

  int get elapsed => finishedSeconds + currentSessionSeconds;
  int get focusCycleStart =>
      (activeBaseSeconds ~/ pomodoroFocusSeconds) * pomodoroFocusSeconds;
  int get focusBlockElapsed =>
      (currentSessionSeconds - focusCycleStart).clamp(0, pomodoroFocusSeconds);
  int get focusRemaining =>
      (pomodoroFocusSeconds - focusBlockElapsed).clamp(0, pomodoroFocusSeconds);
  int get breakElapsed {
    if (state != 'break' || runningStartedAt == null) return 0;
    return ((DateTime.now().toUtc().millisecondsSinceEpoch -
                runningStartedAt!) ~/
            1000)
        .clamp(0, currentBreakSeconds);
  }

  int get currentBreakSeconds {
    final completed = activeBaseSeconds ~/ pomodoroFocusSeconds;
    return completed > 0 && completed % roundsPerLongBreak == 0
        ? longBreakSeconds
        : shortBreakSeconds;
  }

  int get breakRemaining =>
      (currentBreakSeconds - breakElapsed).clamp(0, currentBreakSeconds);
  int get completedPomodoros => currentSessionSeconds ~/ pomodoroFocusSeconds;
  int get plannedPomodoros =>
      ((widget.plannedMinutes * 60) + pomodoroFocusSeconds - 1) ~/
      pomodoroFocusSeconds;

  Future<void> _start() async {
    final id = await ref
        .read(plannerRepositoryProvider)
        .startSession(widget.activityId);
    setState(() {
      sessionId = id;
      state = 'running';
      activeBaseSeconds = 0;
      runningStartedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    });
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    await refreshAndroidHomeWidget();
  }

  Future<void> _pause() async {
    if (sessionId == null) return;
    final seconds = currentSessionSeconds;
    await ref.read(plannerRepositoryProvider).pauseSession(sessionId!, seconds);
    ticker?.cancel();
    setState(() {
      activeBaseSeconds = seconds;
      runningStartedAt = null;
      state = 'paused';
    });
    await refreshAndroidHomeWidget();
  }

  Future<void> _resume() async {
    if (sessionId == null) return;
    await ref.read(plannerRepositoryProvider).resumeSession(sessionId!);
    runningStartedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() => state = 'running');
    await refreshAndroidHomeWidget();
  }

  Future<void> _completeFocusBlock() async {
    if (sessionId == null || transitioning) return;
    transitioning = true;
    final completedSeconds = focusCycleStart + pomodoroFocusSeconds;
    await ref
        .read(plannerRepositoryProvider)
        .startPomodoroBreak(sessionId!, completedSeconds);
    if (!mounted) return;
    setState(() {
      activeBaseSeconds = completedSeconds;
      runningStartedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      state = 'break';
      transitioning = false;
    });
    await refreshAndroidHomeWidget();
  }

  Future<void> _skipBreak() async {
    if (sessionId == null || transitioning) return;
    transitioning = true;
    await ref.read(plannerRepositoryProvider).resumeSession(sessionId!);
    if (!mounted) return;
    setState(() {
      runningStartedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      state = 'running';
      transitioning = false;
    });
    ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    await refreshAndroidHomeWidget();
  }

  Future<void> _startBreakEarly() async {
    if (sessionId == null || transitioning || state == 'break') return;
    transitioning = true;
    final seconds = currentSessionSeconds;
    await ref
        .read(plannerRepositoryProvider)
        .startPomodoroBreak(sessionId!, seconds);
    if (!mounted) return;
    ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() {
      activeBaseSeconds = seconds;
      runningStartedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      state = 'break';
      transitioning = false;
    });
    await refreshAndroidHomeWidget();
  }

  Future<void> _finish() async {
    if (sessionId == null) return;
    final repository = ref.read(plannerRepositoryProvider);
    final activity = await repository.findActivity(widget.activityId);
    if (activity == null || !mounted) return;
    final selection = await showActivityCompletionDialog(
      context,
      ref,
      activity,
    );
    if (selection == null || !mounted) return;
    try {
      final sessionSeconds = currentSessionSeconds;
      await repository.completeActivityWithTopics(
        activity.id,
        selection.studiedTopicIds,
        reviewTopicIds: selection.reviewTopicIds,
        sessionId: sessionId,
        actualSeconds: sessionSeconds,
      );
      ticker?.cancel();
      setState(() {
        state = 'finished';
        finishedSeconds += sessionSeconds;
        activeBaseSeconds = 0;
        runningStartedAt = null;
        sessionId = null;
      });
      ref.invalidate(
        activitiesProvider((
          scheduleId: activity.scheduleId,
          date: activity.date,
        )),
      );
      ref.invalidate(syllabusProvider(activity.scheduleId));
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.play_circle_outline,
    title: 'Sessão de estudo',
    subtitle: 'Pomodoro sincronizado com o Planner e o widget.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        return Column(
          children: [
            if (narrow) ...[
              _timerCard(),
              const SizedBox(height: 12),
              _sessionSide(),
              const SizedBox(height: 12),
              _studyWorkspace(),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: _timerCard()),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: _sessionSide()),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: _studyWorkspace()),
                  const SizedBox(width: 14),
                  const Expanded(flex: 3, child: SizedBox()),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _historyPanel(),
          ],
        );
      },
    ),
  );

  Widget _timerCard() {
    final plannedSeconds = widget.plannedMinutes * 60;
    final isBreak = state == 'break';
    final phaseTotal = isBreak ? currentBreakSeconds : pomodoroFocusSeconds;
    final phaseElapsed = isBreak ? breakElapsed : focusBlockElapsed;
    final progress = (phaseElapsed / phaseTotal).clamp(0, 1).toDouble();
    final countdown = isBreak ? breakRemaining : focusRemaining;
    final phaseColor = isBreak
        ? const Color(0xFF12BBD4)
        : const Color(0xFFFF625F);
    final surface = isBreak ? const Color(0xFFF7F1E8) : const Color(0xFF2E3A52);
    final primaryText = isBreak ? const Color(0xFF273248) : Colors.white;
    final secondaryText = isBreak
        ? const Color(0xFF667085)
        : const Color(0xFFBFC8D8);
    return PlannerCard(
      color: surface,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityTitle,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sessão planejada · ${widget.plannedMinutes} min · foco de ${pomodoroFocusSeconds ~/ 60} min',
                      style: TextStyle(color: secondaryText, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isBreak ? '☕ DESCANSO' : '🍅 FOCO',
                  style: TextStyle(
                    color: phaseColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 520;
              final diameter = compact ? 258.0 : 300.0;
              final ring = SizedBox(
                width: diameter,
                height: diameter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(diameter),
                      painter: _PomodoroRingPainter(
                        progress: progress,
                        color: phaseColor,
                        trackColor: isBreak
                            ? const Color(0xFFDCD5CB)
                            : const Color(0xFF4B5870),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatClock(countdown),
                          style: TextStyle(
                            color: primaryText,
                            fontSize: compact ? 48 : 58,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          isBreak
                              ? 'PAUSA CURTA'
                              : state == 'paused'
                              ? 'PAUSADO'
                              : 'TEMPO DE FOCO',
                          style: TextStyle(
                            color: phaseColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              return ring;
            },
          ),
          const SizedBox(height: 18),
          _pomodoroControls(phaseColor, primaryText, secondaryText),
          const SizedBox(height: 17),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < plannedPomodoros.clamp(1, 8); index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == completedPomodoros ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index <= completedPomodoros
                        ? phaseColor
                        : secondaryText.withValues(alpha: .32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            'Ciclo ${math.min(completedPomodoros + 1, plannedPomodoros)} de $plannedPomodoros  ·  ${_format(elapsed)} de ${_format(plannedSeconds)} estudados',
            style: TextStyle(color: secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatClock(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _pomodoroControls(Color accent, Color foreground, Color secondary) {
    final active = state == 'running' || state == 'paused' || state == 'break';
    final primaryIcon = state == 'break'
        ? Icons.coffee_rounded
        : state == 'running'
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;
    Future<void> primaryAction() async {
      if (state == 'idle' || state == 'finished') return _start();
      if (state == 'running') return _pause();
      if (state == 'paused') return _resume();
      return _skipBreak();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PomodoroControl(
          icon: primaryIcon,
          tooltip: state == 'running' ? 'Pausar' : 'Iniciar ou continuar',
          foreground: Colors.white,
          background: accent,
          size: 68,
          iconSize: 34,
          onPressed: state == 'break' ? null : primaryAction,
        ),
        const SizedBox(width: 24),
        _PomodoroControl(
          icon: Icons.skip_next_rounded,
          tooltip: state == 'break' ? 'Pular descanso' : 'Ir para o descanso',
          foreground: secondary,
          onPressed: active
              ? (state == 'break' ? _skipBreak : _startBreakEarly)
              : null,
        ),
      ],
    );
  }

  Widget _sessionSide() => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Sessão atual', icon: Icons.schedule),
        const SizedBox(height: 12),
        _infoRow(
          Icons.play_circle_outline,
          'Etapa',
          state == 'break'
              ? 'Pausa curta'
              : state == 'running'
              ? 'Foco'
              : state == 'paused'
              ? 'Pausado'
              : 'Pronto',
        ),
        _infoRow(
          Icons.repeat,
          'Pomodoros',
          '$completedPomodoros/$plannedPomodoros',
        ),
        _infoRow(
          Icons.track_changes,
          'Tempo planejado',
          '${widget.plannedMinutes ~/ 60}h${(widget.plannedMinutes % 60).toString().padLeft(2, '0')}',
        ),
        _infoRow(Icons.timer_outlined, 'Tempo efetivo', _format(elapsed)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                state == 'running' || state == 'paused' || state == 'break'
                ? _finish
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTokens.green.withValues(alpha: .24),
              disabledForegroundColor: AppTokens.muted,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Concluir sessão atual'),
          ),
        ),
        const Divider(height: 26),
        const SectionTitle('Tópicos do edital', icon: Icons.layers_outlined),
        const SizedBox(height: 8),
        for (final topic in const [
          'Conceitos, requisitos e atributos',
          'Classificação dos atos administrativos',
          'Anulação, revogação e convalidação',
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 8, color: AppTokens.green),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(topic)),
              ],
            ),
          ),
        const Divider(height: 26),
        const Text(
          'Dificuldade do conteúdo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Baixa')),
            ButtonSegment(value: 1, label: Text('Média')),
            ButtonSegment(value: 2, label: Text('Alta')),
          ],
          selected: {difficulty},
          onSelectionChanged: (values) {
            if (values.isNotEmpty) {
              setState(() => difficulty = values.first);
            }
          },
        ),
      ],
    ),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 9),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _studyWorkspace() => DefaultTabController(
    length: 3,
    child: PlannerCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          TabBar(
            onTap: (value) => setState(() => workspaceTab = value),
            tabs: const [
              Tab(icon: Icon(Icons.description_outlined), text: 'Material'),
              Tab(icon: Icon(Icons.edit_outlined), text: 'Anotações'),
              Tab(icon: Icon(Icons.check_box_outlined), text: 'Questões'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: switch (workspaceTab) {
              0 => _materialsWorkspace(),
              1 => _notesWorkspace(),
              _ => _questionsWorkspace(),
            },
          ),
        ],
      ),
    ),
  );

  Widget _materialsWorkspace() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Materiais desta atividade',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _attachPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Anexar PDF'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _addLessonLink,
            icon: const Icon(Icons.link),
            label: const Text('Link de aula'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (materials.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'Nenhum PDF ou link anexado a esta atividade.',
              style: TextStyle(color: AppTokens.muted),
            ),
          ),
        )
      else
        for (final material in materials)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              material.kind == 'pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.play_circle_outline,
              color: material.kind == 'pdf'
                  ? AppTokens.error
                  : AppTokens.purple,
            ),
            title: Text(material.title),
            subtitle: Text(
              material.kind == 'pdf' ? 'Arquivo PDF' : material.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Marcar como utilizado',
                  child: Checkbox(
                    value: material.isUsed,
                    onChanged: (value) =>
                        _setMaterialUsed(material, value ?? false),
                  ),
                ),
                IconButton(
                  tooltip: 'Abrir',
                  onPressed: () => _openMaterial(material),
                  icon: const Icon(Icons.open_in_new),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') _deleteMaterial(material);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
          ),
    ],
  );

  Widget _notesWorkspace() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Anotações da atividade',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          FilledButton.icon(
            onPressed: _saveNotes,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: notesController,
        minLines: 8,
        maxLines: 16,
        onChanged: (_) => notesDirty = true,
        decoration: const InputDecoration(
          alignLabelWithHint: true,
          labelText: 'Resumo, conceitos, dúvidas e links úteis',
          hintText: 'Escreva suas anotações desta atividade…',
        ),
      ),
    ],
  );

  Widget _questionsWorkspace() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gabarito',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  'Informe sua resposta e marque se acertou ou errou.',
                  style: TextStyle(color: AppTokens.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              controller: questionCountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Número de questões',
                suffixText: 'questões',
                helperText: 'De 1 a 200',
                errorText: _typedQuestionCountValid
                    ? null
                    : 'Digite um número de 1 a 200',
              ),
              onChanged: (text) {
                final value = int.tryParse(text);
                if (value != null && value >= 1 && value <= 200) {
                  _resizeAnswerSheet(value);
                } else {
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      for (var index = 0; index < questionCount; index++) _answerRow(index),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _answerSheetComplete ? _saveAnswerSheet : null,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvar gabarito no histórico'),
        ),
      ),
      if (questionAttempts.isNotEmpty) ...[
        const Divider(height: 34),
        const Text(
          'Histórico de gabaritos',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 6),
        for (final attempt in questionAttempts) _attemptTile(attempt),
      ],
    ],
  );

  Widget _answerRow(int index) => LayoutBuilder(
    builder: (context, constraints) {
      final answerSelector = SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'A', label: Text('A')),
          ButtonSegment(value: 'B', label: Text('B')),
          ButtonSegment(value: 'C', label: Text('C')),
          ButtonSegment(value: 'D', label: Text('D')),
          ButtonSegment(value: 'E', label: Text('E')),
        ],
        selected: questionAnswers[index] == null
            ? const <String>{}
            : {questionAnswers[index]!},
        emptySelectionAllowed: true,
        onSelectionChanged: (values) => setState(
          () => questionAnswers[index] = values.isEmpty ? null : values.first,
        ),
      );
      final resultSelector = SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: true,
            icon: Icon(Icons.check, color: AppTokens.green),
            tooltip: 'Correta',
          ),
          ButtonSegment(
            value: false,
            icon: Icon(Icons.close, color: AppTokens.error),
            tooltip: 'Incorreta',
          ),
        ],
        selected: questionResults[index] == null
            ? const <bool>{}
            : {questionResults[index]!},
        emptySelectionAllowed: true,
        onSelectionChanged: (values) => setState(
          () => questionResults[index] = values.isEmpty ? null : values.first,
        ),
      );
      final number = SizedBox(
        width: 42,
        child: Text(
          '${index + 1}.',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: constraints.maxWidth < 520
            ? Column(
                children: [
                  Row(
                    children: [
                      number,
                      Expanded(child: answerSelector),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: resultSelector,
                  ),
                ],
              )
            : Row(
                children: [
                  number,
                  Expanded(child: answerSelector),
                  const SizedBox(width: 10),
                  resultSelector,
                ],
              ),
      );
    },
  );

  Widget _attemptTile(QuestionAttemptRecord attempt) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      attempt.createdAt,
      isUtc: true,
    ).toLocal();
    final percent = (attempt.correct / attempt.answers.length * 100).round();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${attempt.correct}/${attempt.answers.length} acertos',
      ),
      subtitle: Text('$percent% de aproveitamento'),
      trailing: IconButton(
        tooltip: 'Excluir gabarito',
        onPressed: () => _deleteAnswerSheet(attempt.id),
        icon: const Icon(Icons.delete_outline),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final answer in attempt.answers)
              Chip(
                avatar: Icon(
                  answer.isCorrect ? Icons.check : Icons.close,
                  size: 16,
                  color: answer.isCorrect ? AppTokens.green : AppTokens.error,
                ),
                label: Text('${answer.number}. ${answer.answer}'),
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  bool get _typedQuestionCountValid {
    final value = int.tryParse(questionCountController.text);
    return value != null && value >= 1 && value <= 200;
  }

  bool get _answerSheetComplete =>
      _typedQuestionCountValid &&
      int.parse(questionCountController.text) == questionCount &&
      questionAnswers.every((answer) => answer != null) &&
      questionResults.every((result) => result != null);

  void _resizeAnswerSheet(int count) {
    setState(() {
      questionCount = count;
      questionAnswers = List.generate(
        count,
        (index) =>
            index < questionAnswers.length ? questionAnswers[index] : null,
      );
      questionResults = List.generate(
        count,
        (index) =>
            index < questionResults.length ? questionResults[index] : null,
      );
    });
  }

  Future<void> _attachPdf() async {
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (pickedFiles.isEmpty) return;
    final picked = pickedFiles.single;
    try {
      final root = await getApplicationSupportDirectory();
      final directory = Directory(
        path.join(root.path, 'materials', '${widget.activityId}'),
      );
      await directory.create(recursive: true);
      final safeName = picked.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final destination = path.join(
        directory.path,
        '${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );
      if (picked.path != null) {
        await File(picked.path!).copy(destination);
      } else {
        await picked.xFile.saveTo(destination);
      }
      await ref
          .read(plannerRepositoryProvider)
          .addMaterial(
            widget.activityId,
            kind: 'pdf',
            title: picked.name,
            location: destination,
          );
      await _load();
    } catch (error) {
      _showWorkspaceError(error);
    }
  }

  Future<void> _addLessonLink() async {
    final title = TextEditingController();
    final url = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar link de aula'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Título da aula'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'Link',
                  hintText: 'https://…',
                ),
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
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final uri = Uri.tryParse(url.text.trim());
    if (title.text.trim().isEmpty ||
        uri == null ||
        !{'http', 'https'}.contains(uri.scheme)) {
      _showWorkspaceError('Informe um título e um link http ou https válido.');
      return;
    }
    await ref
        .read(plannerRepositoryProvider)
        .addMaterial(
          widget.activityId,
          kind: 'link',
          title: title.text,
          location: uri.toString(),
        );
    await _load();
  }

  Future<void> _openMaterial(StudyMaterialRecord material) async {
    final uri = material.kind == 'pdf'
        ? Uri.file(material.location)
        : Uri.parse(material.location);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showWorkspaceError('Não foi possível abrir este material.');
    }
  }

  Future<void> _setMaterialUsed(
    StudyMaterialRecord material,
    bool value,
  ) async {
    await ref
        .read(plannerRepositoryProvider)
        .setMaterialUsed(material.id, value);
    await _load();
  }

  Future<void> _deleteMaterial(StudyMaterialRecord material) async {
    await ref.read(plannerRepositoryProvider).deleteMaterial(material.id);
    if (material.kind == 'pdf') {
      final file = File(material.location);
      if (await file.exists()) await file.delete();
    }
    await _load();
  }

  Future<void> _saveNotes() async {
    await ref
        .read(plannerRepositoryProvider)
        .saveActivityNotes(widget.activityId, notesController.text);
    notesDirty = false;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Anotações salvas.')));
    }
  }

  Future<void> _saveAnswerSheet() async {
    final answers = List.generate(
      questionCount,
      (index) => QuestionAnswerDraft(
        number: index + 1,
        answer: questionAnswers[index]!,
        isCorrect: questionResults[index]!,
      ),
    );
    await ref
        .read(plannerRepositoryProvider)
        .saveQuestionAttempt(
          widget.activityId,
          answers,
          studySessionId: sessionId,
        );
    setState(() {
      questionAnswers = List.filled(questionCount, null);
      questionResults = List.filled(questionCount, null);
    });
    await _load();
  }

  Future<void> _deleteAnswerSheet(int id) async {
    await ref.read(plannerRepositoryProvider).deleteQuestionAttempt(id);
    await _load();
  }

  void _showWorkspaceError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }

  Widget _historyPanel() => PlannerCard(
    child: Column(
      children: [
        const SectionTitle('Sessões anteriores', icon: Icons.history),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Nenhuma sessão finalizada para esta atividade.',
              style: TextStyle(color: AppTokens.muted),
            ),
          ),
        for (final record in history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text('${record.date} · ${_format(record.seconds)}'),
            subtitle: Text(
              '${record.questions} questões · ${record.correct} acertos',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'delete') {
                  await ref
                      .read(plannerRepositoryProvider)
                      .deleteSession(record.id);
                  await _load();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ),
      ],
    ),
  );
}

class _PomodoroControl extends StatelessWidget {
  const _PomodoroControl({
    required this.icon,
    required this.tooltip,
    required this.foreground,
    required this.onPressed,
    this.background,
    this.size = 48,
    this.iconSize = 24,
  });
  final IconData icon;
  final String tooltip;
  final Color foreground;
  final Color? background;
  final double size, iconSize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      color: foreground,
      disabledColor: foreground.withValues(alpha: .25),
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        backgroundColor: background ?? foreground.withValues(alpha: .09),
        disabledBackgroundColor: foreground.withValues(alpha: .04),
        shape: const CircleBorder(),
      ),
    ),
  );
}

class _PomodoroRingPainter extends CustomPainter {
  const _PomodoroRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });
  final double progress;
  final Color color, trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .035;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final visibleProgress = progress.clamp(0.001, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * visibleProgress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PomodoroRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
