import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/planner_ui.dart';
import '../../planner/application/performance_providers.dart';
import '../../planner/data/planner_repository.dart';

class CyclePage extends StatefulWidget {
  const CyclePage({super.key});
  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> {
  double weeklyHours = 12.5;
  bool keepOrder = true;
  bool autoDuration = true;
  bool restart = false;

  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.sync,
    title: 'Ciclo de estudos',
    subtitle: 'Estude por prioridade, sem depender de dias fixos.',
    child: LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 900;
        final summary = GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: compact ? 1 : 3,
          childAspectRatio: compact ? 4.3 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 10,
          children: const [
            MetricCard(
              icon: Icons.layers_outlined,
              label: 'Ciclo atual',
              value: '4/8 matérias',
            ),
            MetricCard(
              icon: Icons.schedule,
              label: 'Carga do ciclo',
              value: '12h30',
            ),
            MetricCard(
              icon: Icons.calendar_today_outlined,
              label: 'Previsão de término',
              value: '18 nov.',
            ),
          ],
        );
        final current = PlannerCard(
          child: Column(
            children: [
              const SectionTitle('Ciclo atual'),
              const SizedBox(height: 18),
              SizedBox(
                height: 345,
                child: CustomPaint(
                  painter: _CyclePainter(),
                  child: Center(
                    child: Container(
                      width: 126,
                      height: 126,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTokens.green, width: 12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Ciclo atual', style: TextStyle(fontSize: 11)),
                          Text(
                            '4/8',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('matérias', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        final queue = PlannerCard(
          child: Column(
            children: [
              const SectionTitle(
                'Fila do ciclo',
                icon: Icons.format_list_bulleted,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < 8; i++) _cycleRow(context, i),
            ],
          ),
        );
        final adjust = PlannerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Ajustar ciclo', icon: Icons.tune),
              const SizedBox(height: 16),
              const Text(
                'Peso por prioridade',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final x in [
                ('Alta', .5, AppTokens.redSoft),
                ('Média', .3, AppTokens.yellowSoft),
                ('Baixa', .2, AppTokens.greenSoft),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 62,
                        child: DisciplineChip(
                          x.$1,
                          index: x.$1 == 'Alta'
                              ? 1
                              : x.$1 == 'Média'
                              ? 2
                              : 3,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: MiniProgress(value: x.$2)),
                      const SizedBox(width: 8),
                      Text('${(x.$2 * 100).round()}%'),
                    ],
                  ),
                ),
              const Divider(height: 30),
              Text(
                'Horas semanais do ciclo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: weeklyHours,
                      min: 4,
                      max: 30,
                      onChanged: (v) => setState(() => weeklyHours = v),
                    ),
                  ),
                  Text(
                    '${weeklyHours.floor()}h${((weeklyHours % 1) * 60).round().toString().padLeft(2, '0')}',
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Manter a ordem do ciclo'),
                value: keepOrder,
                onChanged: (v) => setState(() => keepOrder = v!),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Ajustar automaticamente as durações'),
                value: autoDuration,
                onChanged: (v) => setState(() => autoDuration = v!),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Reiniciar ao concluir todas as matérias'),
                value: restart,
                onChanged: (v) => setState(() => restart = v!),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      showPlannerNotice(context, 'Ajustes do ciclo salvos'),
                  icon: const Icon(Icons.check),
                  label: const Text('Salvar ajustes'),
                ),
              ),
            ],
          ),
        );
        return Column(
          children: [
            summary,
            const SizedBox(height: 14),
            if (compact) ...[
              current,
              const SizedBox(height: 12),
              queue,
              const SizedBox(height: 12),
              adjust,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: current),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: queue),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: adjust),
                ],
              ),
            const SizedBox(height: 14),
            _cycleHistory(),
          ],
        );
      },
    ),
  );

  Widget _cycleRow(BuildContext context, int i) {
    final done = i < 3;
    final current = i == 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: current ? const Color(0xFFF8F8FF) : null,
        border: Border.all(color: current ? AppTokens.ink : AppTokens.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator, size: 18, color: AppTokens.muted),
          SizedBox(
            width: 28,
            child: Text('${i + 1}', textAlign: TextAlign.center),
          ),
          Expanded(child: DisciplineChip(demoDisciplines[i], index: i)),
          const SizedBox(width: 8),
          Text(
            ['2h00', '1h30', '2h00', '2h30', '1h30', '1h30', '1h00', '1h30'][i],
          ),
          const SizedBox(width: 10),
          Icon(
            done
                ? Icons.check_circle
                : current
                ? Icons.play_circle_outline
                : Icons.circle_outlined,
            size: 17,
            color: done ? AppTokens.green : AppTokens.muted,
          ),
        ],
      ),
    );
  }

  Widget _cycleHistory() => PlannerCard(
    child: Column(
      children: [
        const SectionTitle('Últimos ciclos', icon: Icons.bar_chart),
        const SizedBox(height: 12),
        for (var i = 3; i > 0; i--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  const Icon(Icons.outlined_flag, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Ciclo $i',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Expanded(flex: 3, child: MiniProgress(value: .75)),
                  const SizedBox(width: 8),
                  Text(i == 2 ? '75%' : '100%'),
                  if (constraints.maxWidth > 430) ...[
                    const SizedBox(width: 12),
                    const Chip(label: Text('Concluído')),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _CyclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 145.0;
    final paint = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..color = const Color(0xFFB8BBC2)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      final nextA = -math.pi / 2 + ((i + 1) % 8) * math.pi / 4;
      final q = center + Offset(math.cos(nextA), math.sin(nextA)) * radius;
      canvas.drawLine(p, q, line);
      paint.color = disciplinePalette[i].withValues(alpha: .58);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 82, height: 48),
          const Radius.circular(13),
        ),
        paint,
      );
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        text: TextSpan(
          text: '${i + 1}\n${demoDisciplines[i].split(' ').first}',
          style: const TextStyle(
            color: AppTokens.ink,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      )..layout(maxWidth: 78);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  var filter = 0;
  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.layers_outlined,
    title: 'Revisões',
    subtitle: 'Reforce o conteúdo no momento certo.',
    child: LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 920;
        return Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: compact ? 2 : 4,
              childAspectRatio: compact ? 2.8 : 3.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              children: const [
                MetricCard(
                  icon: Icons.today_outlined,
                  label: 'Hoje',
                  value: '3',
                ),
                MetricCard(
                  icon: Icons.schedule,
                  label: 'Atrasadas',
                  value: '2',
                ),
                MetricCard(
                  icon: Icons.calendar_today_outlined,
                  label: 'Esta semana',
                  value: '11',
                ),
                MetricCard(
                  icon: Icons.track_changes,
                  label: 'Taxa de retenção',
                  value: '78%',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('Todas'),
                    icon: Icon(Icons.layers_outlined),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Programadas'),
                    icon: Icon(Icons.calendar_today_outlined),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text('Subjetivas'),
                    icon: Icon(Icons.edit_outlined),
                  ),
                ],
                selected: {filter},
                onSelectionChanged: (v) => setState(() => filter = v.first),
              ),
            ),
            const SizedBox(height: 14),
            if (compact) ...[
              _reviewList(),
              const SizedBox(height: 12),
              _reviewCalendar(),
              const SizedBox(height: 12),
              _subjective(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _reviewList()),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _reviewCalendar()),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _subjective()),
                ],
              ),
          ],
        );
      },
    ),
  );

  Widget _reviewList() => PlannerCard(
    child: Column(
      children: [
        for (final group in [
          ('Hoje', 3),
          ('Amanhã', 2),
          ('Próximos 7 dias', 6),
        ]) ...[
          SectionTitle(
            group.$1,
            icon: Icons.calendar_today_outlined,
            trailing: CircleAvatar(
              radius: 13,
              backgroundColor: AppTokens.hover,
              child: Text('${group.$2}', style: const TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < math.min(group.$2, 3); i++)
            _reviewRow(i + (group.$1 == 'Hoje' ? 0 : 3)),
          const Divider(height: 22),
        ],
      ],
    ),
  );

  Widget _reviewRow(int i) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final topic = [
          'Prisão e medidas cautelares',
          'Direitos e garantias fundamentais',
          'Pontuação',
          'Atos administrativos',
          'Porcentagem',
          'Pacote Office',
        ][i % 6];
        final info = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text(
                'Plano TJSP 2026',
                style: TextStyle(fontSize: 11, color: AppTokens.muted),
              ),
            ],
          ),
        );
        final action = FilledButton(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          ),
          onPressed: () => showPlannerNotice(context, 'Revisão iniciada'),
          child: const Text('Iniciar'),
        );
        if (narrow) {
          return Column(
            children: [
              Row(
                children: [
                  Checkbox(value: false, onChanged: (_) {}),
                  info,
                  Chip(label: Text(['D+1', 'D+7', 'D+30'][i % 3])),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: DisciplineChip(
                      demoDisciplines[i % demoDisciplines.length],
                      index: i,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  action,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Checkbox(value: false, onChanged: (_) {}),
            SizedBox(
              width: 112,
              child: DisciplineChip(
                demoDisciplines[i % demoDisciplines.length],
                index: i,
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            info,
            Chip(label: Text(['D+1', 'D+7', 'D+30'][i % 3])),
            const SizedBox(width: 7),
            action,
          ],
        );
      },
    ),
  );

  Widget _reviewCalendar() => PlannerCard(
    child: Column(
      children: [
        const SectionTitle(
          'Carga de revisões',
          icon: Icons.calendar_month_outlined,
        ),
        const SizedBox(height: 14),
        const Text(
          'novembro de 2026',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 35,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemBuilder: (_, i) => Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i > 6
                  ? Color.lerp(
                      Colors.white,
                      AppTokens.purple,
                      ((i % 5) + 1) / 12,
                    )
                  : AppTokens.hover,
              borderRadius: BorderRadius.circular(6),
              border: i == 18
                  ? Border.all(color: AppTokens.ink, width: 2)
                  : null,
            ),
            child: Text(
              '${(i + 26) % 30 + 1}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Mais escuro = mais revisões',
          style: TextStyle(fontSize: 11, color: AppTokens.muted),
        ),
      ],
    ),
  );

  Widget _subjective() => PlannerCard(
    child: Column(
      children: [
        const SectionTitle('Revisão subjetiva', icon: Icons.edit_outlined),
        const SizedBox(height: 5),
        const Text(
          'Tópicos marcados como mais difíceis.',
          style: TextStyle(color: AppTokens.muted),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Checkbox(value: false, onChanged: (_) {}),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DisciplineChip(
                        demoDisciplines[(i + 1) % 6],
                        index: i + 1,
                        compact: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'Crimes contra a Administração Pública',
                          'Nulidades processuais',
                          'Controle de constitucionalidade',
                          'Responsabilidade civil do Estado',
                          'Recursos',
                        ][i],
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Text(
                  i < 2
                      ? 'Alta'
                      : i < 4
                      ? 'Média'
                      : 'Baixa',
                  style: TextStyle(
                    color: i < 2 ? AppTokens.error : AppTokens.muted,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showPlannerNotice(
              context,
              'Selecione os tópicos e escolha a data',
            ),
            icon: const Icon(Icons.add),
            label: const Text('Agendar revisão'),
          ),
        ),
      ],
    ),
  );
}

class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key});
  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  bool timed = true;
  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.check_box_outlined,
    title: 'Questões',
    subtitle: 'Registre simulados e descubra onde melhorar.',
    child: LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 950;
        return Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: compact ? 2 : 4,
              childAspectRatio: compact ? 2.7 : 3.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              children: const [
                MetricCard(
                  icon: Icons.layers_outlined,
                  label: 'Resolvidas no mês',
                  value: '420',
                ),
                MetricCard(
                  icon: Icons.check,
                  label: 'Acertos',
                  value: '74%',
                  tint: AppTokens.greenSoft,
                ),
                MetricCard(
                  icon: Icons.close,
                  label: 'Erros',
                  value: '109',
                  tint: AppTokens.redSoft,
                ),
                MetricCard(
                  icon: Icons.schedule,
                  label: 'Tempo médio',
                  value: '1m42s',
                  tint: AppTokens.blueSoft,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (compact) ...[
              _newBattery(),
              const SizedBox(height: 12),
              _performance(),
              const SizedBox(height: 12),
              _errors(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: _newBattery()),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: _performance()),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _errors()),
                ],
              ),
            const SizedBox(height: 14),
            _batteryHistory(),
          ],
        );
      },
    ),
  );

  Widget _newBattery() => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Nova bateria de questões', icon: Icons.add),
        const SizedBox(height: 12),
        const Text('Disciplina', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        DropdownButtonFormField(
          isExpanded: true,
          initialValue: 'Proc. Penal',
          items: const [
            DropdownMenuItem(value: 'Proc. Penal', child: Text('Proc. Penal')),
            DropdownMenuItem(value: 'Dir. Penal', child: Text('Direito Penal')),
          ],
          onChanged: (_) {},
        ),
        const SizedBox(height: 10),
        const Text('Assuntos', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        const Wrap(
          spacing: 5,
          children: [
            Chip(label: Text('Lei 11.340/2006')),
            Chip(label: Text('Prisões')),
            Chip(label: Text('Medidas Cautelares')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField(
                isExpanded: true,
                initialValue: 30,
                decoration: const InputDecoration(labelText: 'Quantidade'),
                items: const [
                  DropdownMenuItem(value: 20, child: Text('20 questões')),
                  DropdownMenuItem(value: 30, child: Text('30 questões')),
                  DropdownMenuItem(value: 40, child: Text('40 questões')),
                ],
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField(
                isExpanded: true,
                initialValue: 'VUNESP',
                decoration: const InputDecoration(labelText: 'Banca'),
                items: const [
                  DropdownMenuItem(value: 'VUNESP', child: Text('VUNESP')),
                  DropdownMenuItem(value: 'FGV', child: Text('FGV')),
                ],
                onChanged: (_) {},
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cronometrar tempo'),
          value: timed,
          onChanged: (v) => setState(() => timed = v),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showPlannerNotice(context, 'Bateria iniciada'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar bateria'),
          ),
        ),
      ],
    ),
  );

  Widget _performance() => PlannerCard(
    child: Column(
      children: [
        const SectionTitle('Desempenho por disciplina', icon: Icons.bar_chart),
        const SizedBox(height: 12),
        for (var i = 0; i < demoDisciplines.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    demoDisciplines[i],
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MiniProgress(
                    value: [
                      .86,
                      .78,
                      .82,
                      .70,
                      .76,
                      .68,
                      .85,
                      .62,
                      .80,
                      .77,
                      .73,
                      .88,
                    ][i],
                    color: disciplinePalette[i],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${([.86, .78, .82, .70, .76, .68, .85, .62, .80, .77, .73, .88][i] * 100).round()}%',
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _errors() => PlannerCard(
    child: Column(
      children: [
        const SectionTitle('Caderno de erros', icon: Icons.menu_book_outlined),
        const SizedBox(height: 5),
        const Text(
          'Assuntos mais recorrentes nos seus erros:',
          style: TextStyle(color: AppTokens.muted),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: disciplinePalette[i + 4],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      'Proc. Penal — Prisões',
                      'Matemática — Porcentagem',
                      'Dir. Administrativo — Atos Administrativos',
                      'Dir. Constitucional — Direitos e Garantias',
                      'Raciocínio Lógico — Proposições',
                    ][i],
                  ),
                ),
                Chip(label: Text('${18 - i * 2} erros')),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                showPlannerNotice(context, 'Caderno de erros aberto'),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Revisar erros'),
          ),
        ),
      ],
    ),
  );

  Widget _batteryHistory() => PlannerCard(
    child: Column(
      children: [
        const SectionTitle('Histórico de baterias', icon: Icons.history),
        const SizedBox(height: 10),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 700;
                final button = OutlinedButton.icon(
                  onPressed: () =>
                      showPlannerNotice(context, 'Erros da bateria abertos'),
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: Text(narrow ? 'Erros' : 'Revisar erros'),
                );
                if (narrow) {
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${13 - i}/11/2026  ${10 + i}:30'),
                            const SizedBox(height: 5),
                            DisciplineChip(
                              demoDisciplines[(i + 5) % 10],
                              index: i + 5,
                              compact: true,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${20 + i * 5} questões · ${23 + i}/${30 + i * 2} (${77 + i * 2}%)',
                              style: const TextStyle(
                                color: AppTokens.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      button,
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text('${13 - i}/11/2026  ${10 + i}:30'),
                    ),
                    Expanded(
                      child: DisciplineChip(
                        demoDisciplines[(i + 5) % 10],
                        index: i + 5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 65, child: Text('${20 + i * 5}')),
                    SizedBox(
                      width: 120,
                      child: Text('${23 + i}/${30 + i * 2} (${77 + i * 2}%)'),
                    ),
                    const SizedBox(width: 10),
                    button,
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );
}

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});
  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  String period = 'Últimos 30 dias';

  ({DateTime from, DateTime to}) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      'Últimos 7 dias' => (
        from: today.subtract(const Duration(days: 6)),
        to: today,
      ),
      'Este ano' => (from: DateTime(today.year), to: today),
      _ => (from: today.subtract(const Duration(days: 29)), to: today),
    };
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsProvider(range));
    return PlannerPageFrame(
      icon: Icons.bar_chart,
      title: 'Estatísticas',
      subtitle: 'Entenda seu ritmo e ajuste o planejamento.',
      actions: [
        SizedBox(
          width: 190,
          child: DropdownButtonFormField(
            isExpanded: true,
            initialValue: period,
            items: const [
              DropdownMenuItem(
                value: 'Últimos 7 dias',
                child: Text('Últimos 7 dias'),
              ),
              DropdownMenuItem(
                value: 'Últimos 30 dias',
                child: Text('Últimos 30 dias'),
              ),
              DropdownMenuItem(value: 'Este ano', child: Text('Este ano')),
            ],
            onChanged: (value) => setState(() => period = value!),
          ),
        ),
      ],
      child: analytics.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => _AnalyticsError(
          onRetry: () => ref.invalidate(analyticsProvider(range)),
        ),
        data: (data) => _StatisticsContent(data: data, period: period),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({required this.data, required this.period});
  final PlannerAnalytics data;
  final String period;

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = seconds % 3600 ~/ 60;
    return hours > 0
        ? '${hours}h${minutes.toString().padLeft(2, '0')}'
        : '${minutes}min';
  }

  List<_ChartBucket> get buckets {
    final target = period == 'Últimos 7 dias'
        ? 7
        : period == 'Este ano'
        ? 12
        : 6;
    final size = math.max(1, (data.daily.length / target).ceil());
    final result = <_ChartBucket>[];
    for (var start = 0; start < data.daily.length; start += size) {
      final slice = data.daily.sublist(
        start,
        math.min(start + size, data.daily.length),
      );
      final date = slice.first.date;
      result.add(
        _ChartBucket(
          label: period == 'Este ano'
              ? const [
                  'jan',
                  'fev',
                  'mar',
                  'abr',
                  'mai',
                  'jun',
                  'jul',
                  'ago',
                  'set',
                  'out',
                  'nov',
                  'dez',
                ][date.month - 1]
              : '${date.day}/${date.month}',
          seconds: slice.fold(0, (sum, item) => sum + item.seconds),
          questions: slice.fold(0, (sum, item) => sum + item.questions),
          correct: slice.fold(0, (sum, item) => sum + item.correct),
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      final cards = GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: compact ? 2 : 5,
        childAspectRatio: compact ? 2.7 : 2.25,
        crossAxisSpacing: 12,
        mainAxisSpacing: 10,
        children: [
          MetricCard(
            icon: Icons.schedule,
            label: 'Tempo estudado',
            value: _duration(data.seconds),
            tint: AppTokens.lavender,
          ),
          MetricCard(
            icon: Icons.calendar_today_outlined,
            label: 'Dias estudados',
            value: '${data.studyDays}',
            tint: AppTokens.greenSoft,
          ),
          MetricCard(
            icon: Icons.layers_outlined,
            label: 'Questões',
            value: '${data.questions}',
            tint: AppTokens.blueSoft,
          ),
          MetricCard(
            icon: Icons.track_changes,
            label: 'Acertos',
            value: data.questions == 0
                ? '—'
                : '${(data.accuracy * 100).round()}%',
            tint: AppTokens.yellowSoft,
          ),
          MetricCard(
            icon: Icons.local_fire_department_outlined,
            label: 'Sequência',
            value: '${data.streak} dias',
            tint: AppTokens.redSoft,
          ),
        ],
      );
      final focus = _ChartCard(
        title: 'Tempo de foco',
        icon: Icons.bar_chart,
        empty: data.seconds == 0,
        child: CustomPaint(painter: _FocusBarPainter(buckets)),
      );
      final accuracy = _ChartCard(
        title: 'Evolução de acertos',
        icon: Icons.show_chart,
        empty: data.questions == 0,
        child: CustomPaint(painter: _AccuracyLinePainter(buckets)),
      );
      final tasks = _TaskCompletionCard(data: data);
      final disciplines = _DisciplineChart(data: data, duration: _duration);
      return Column(
        children: [
          cards,
          const SizedBox(height: 14),
          if (compact) ...[
            focus,
            const SizedBox(height: 12),
            accuracy,
          ] else
            Row(
              children: [
                Expanded(child: focus),
                const SizedBox(width: 12),
                Expanded(child: accuracy),
              ],
            ),
          const SizedBox(height: 12),
          if (compact) ...[
            tasks,
            const SizedBox(height: 12),
            disciplines,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: tasks),
                const SizedBox(width: 12),
                Expanded(flex: 6, child: disciplines),
              ],
            ),
        ],
      );
    },
  );
}

class _ChartBucket {
  const _ChartBucket({
    required this.label,
    required this.seconds,
    required this.questions,
    required this.correct,
  });
  final String label;
  final int seconds, questions, correct;
  double get accuracy => questions == 0 ? 0 : correct / questions;
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.icon,
    required this.empty,
    required this.child,
  });
  final String title;
  final IconData icon;
  final bool empty;
  final Widget child;
  @override
  Widget build(BuildContext context) => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title, icon: icon),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          child: empty ? const _EmptyChart() : SizedBox.expand(child: child),
        ),
      ],
    ),
  );
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insights_outlined, color: AppTokens.muted, size: 34),
        SizedBox(height: 8),
        Text(
          'Os dados aparecerão após uma sessão concluída.',
          style: TextStyle(color: AppTokens.muted),
        ),
      ],
    ),
  );
}

class _TaskCompletionCard extends StatelessWidget {
  const _TaskCompletionCard({required this.data});
  final PlannerAnalytics data;
  @override
  Widget build(BuildContext context) => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Conclusão do planejamento',
          icon: Icons.donut_large,
        ),
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 164,
            height: 164,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: data.taskCompletion,
                  strokeWidth: 17,
                  color: AppTokens.green,
                  backgroundColor: AppTokens.border,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(data.taskCompletion * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${data.completedTasks} de ${data.plannedTasks}',
                      style: const TextStyle(color: AppTokens.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppTokens.green, label: 'Concluídas'),
            const SizedBox(width: 18),
            const _LegendDot(color: AppTokens.border, label: 'Pendentes'),
          ],
        ),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: AppTokens.muted)),
    ],
  );
}

class _DisciplineChart extends StatelessWidget {
  const _DisciplineChart({required this.data, required this.duration});
  final PlannerAnalytics data;
  final String Function(int) duration;
  @override
  Widget build(BuildContext context) {
    final maxSeconds = data.disciplines.fold(
      0,
      (value, item) => math.max(value, item.seconds),
    );
    return PlannerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Tempo por disciplina',
            icon: Icons.stacked_bar_chart,
          ),
          const SizedBox(height: 15),
          if (data.disciplines.isEmpty)
            const SizedBox(height: 210, child: _EmptyChart())
          else
            for (var i = 0; i < data.disciplines.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 142,
                      child: Text(
                        data.disciplines[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MiniProgress(
                        value: maxSeconds == 0
                            ? 0
                            : data.disciplines[i].seconds / maxSeconds,
                        color: disciplinePalette[i % disciplinePalette.length],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 54,
                      child: Text(
                        duration(data.disciplines[i].seconds),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    if (data.disciplines[i].questions > 0) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${(data.disciplines[i].accuracy * 100).round()}%',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _FocusBarPainter extends CustomPainter {
  const _FocusBarPainter(this.values);
  final List<_ChartBucket> values;
  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 28.0;
    final height = size.height - bottom;
    final maxValue = math.max(
      1,
      values.fold(0, (max, item) => math.max(max, item.seconds)),
    );
    final grid = Paint()
      ..color = AppTokens.border
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(0, height * i / 3),
        Offset(size.width, height * i / 3),
        grid,
      );
    }
    final slot = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final barHeight = height * values[i].seconds / maxValue;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * slot + slot * .2,
          height - barHeight,
          slot * .6,
          barHeight,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = AppTokens.purple.withValues(alpha: .82),
      );
      _paintLabel(
        canvas,
        values[i].label,
        Offset(i * slot + slot / 2, height + 8),
        center: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusBarPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _AccuracyLinePainter extends CustomPainter {
  const _AccuracyLinePainter(this.values);
  final List<_ChartBucket> values;
  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 28.0;
    final height = size.height - bottom;
    final grid = Paint()
      ..color = AppTokens.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(
        Offset(0, height * i / 4),
        Offset(size.width, height * i / 4),
        grid,
      );
    }
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      points.add(Offset(x, height * (1 - values[i].accuracy)));
      _paintLabel(canvas, values[i].label, Offset(x, height + 8), center: true);
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTokens.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = AppTokens.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AccuracyLinePainter oldDelegate) =>
      oldDelegate.values != values;
}

void _paintLabel(
  Canvas canvas,
  String value,
  Offset position, {
  bool center = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: value,
      style: const TextStyle(fontSize: 10, color: AppTokens.muted),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(center ? position.dx - painter.width / 2 : position.dx, position.dy),
  );
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 36, color: AppTokens.muted),
          const SizedBox(height: 10),
          const Text('Não foi possível carregar as estatísticas.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.menu_book_outlined,
    title: 'Biblioteca',
    subtitle: 'Seus materiais ligados às disciplinas e ao calendário.',
    actions: [
      FilledButton.icon(
        onPressed: () => showPlannerNotice(
          context,
          'Selecione um arquivo, link ou anotação',
        ),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar material'),
      ),
    ],
    child: LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 1120;
        return Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar material...',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (!compact)
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Todos')),
                      ButtonSegment(value: 1, label: Text('PDFs')),
                      ButtonSegment(value: 2, label: Text('Vídeos')),
                      ButtonSegment(value: 3, label: Text('Links')),
                    ],
                    selected: const {0},
                    onSelectionChanged: (_) {},
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (compact) ...[
              _materials(),
              const SizedBox(height: 12),
              _materialDetails(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 245, child: _folders()),
                  const SizedBox(width: 12),
                  Expanded(child: _materials()),
                  const SizedBox(width: 12),
                  SizedBox(width: 310, child: _materialDetails()),
                ],
              ),
            const SizedBox(height: 12),
            PlannerCard(
              child: LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 1200
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionTitle(
                            'Armazenamento',
                            icon: Icons.layers_outlined,
                          ),
                          SizedBox(height: 8),
                          Text('3,2 GB de 10 GB utilizados (32%)'),
                          SizedBox(height: 8),
                          MiniProgress(value: .32, color: AppTokens.green),
                        ],
                      )
                    : const Row(
                        children: [
                          Icon(Icons.layers_outlined),
                          SizedBox(width: 10),
                          Text(
                            'Armazenamento',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Spacer(),
                          Text('3,2 GB de 10 GB utilizados (32%)'),
                          SizedBox(width: 16),
                          SizedBox(
                            width: 280,
                            child: MiniProgress(
                              value: .32,
                              color: AppTokens.green,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _folders() => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Disciplinas', icon: Icons.folder_outlined),
        const SizedBox(height: 10),
        for (var i = 0; i < demoDisciplines.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.folder, color: disciplinePalette[i]),
            title: Text(demoDisciplines[i], overflow: TextOverflow.ellipsis),
            trailing: Text('${5 + i * 3}'),
            onTap: () {},
          ),
      ],
    ),
  );
  Widget _materials() => PlannerCard(
    child: Column(
      children: [
        const SectionTitle('Materiais (41)', icon: Icons.format_list_bulleted),
        const SizedBox(height: 10),
        for (var i = 0; i < 10; i++)
          InkWell(
            onTap: () => setState(() => selected = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              decoration: BoxDecoration(
                color: selected == i ? AppTokens.lavender : null,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(
                    i % 3 == 0
                        ? Icons.picture_as_pdf_outlined
                        : i % 3 == 1
                        ? Icons.link
                        : Icons.play_circle_outline,
                    color: i % 3 == 0 ? AppTokens.error : AppTokens.purple,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 3,
                    child: Text(
                      [
                        'Apostila — Atos Administrativos.pdf',
                        'Lei 8.429 comentada',
                        'Aula 02 — Improbidade',
                        'Artigos 37 a 41 da CF.pdf',
                        'Resumo — Atos Administrativos',
                      ][i % 5],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: DisciplineChip(
                      demoDisciplines[(i + 3) % 6],
                      index: i + 3,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      i % 3 == 0 ? '${24 + i * 6} pág.' : '${42 + i}min',
                    ),
                  ),
                  const Icon(Icons.more_vert, size: 17),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  Widget _materialDetails() => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Detalhes do material', icon: Icons.info_outline),
        const SizedBox(height: 14),
        Center(
          child: Container(
            width: 180,
            height: 220,
            decoration: BoxDecoration(
              color: AppTokens.redSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTokens.border),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 38,
                  color: AppTokens.error,
                ),
                SizedBox(height: 12),
                Text(
                  'Apostila\nAtos Administrativos',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Apostila — Atos Administrativos.pdf',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const DisciplineChip('Dir. Administrativo', index: 3),
        const SizedBox(height: 12),
        const Text('Tópicos vinculados'),
        const Wrap(
          spacing: 5,
          children: [
            Chip(label: Text('Atos Administrativos')),
            Chip(label: Text('Elementos')),
            Chip(label: Text('Atributos')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showPlannerNotice(context, 'Material aberto'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir material'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                showPlannerNotice(context, 'Selecione os tópicos do edital'),
            icon: const Icon(Icons.link),
            label: const Text('Vincular ao edital'),
          ),
        ),
      ],
    ),
  );
}
