import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

const disciplinePalette = <Color>[
  Color(0xFFAED8FF),
  Color(0xFFFFAEB9),
  Color(0xFFFFDA84),
  Color(0xFF9DE1A7),
  Color(0xFFB9A7FF),
  Color(0xFFC9B6FF),
  Color(0xFFFFB8C2),
  Color(0xFFF4A9DE),
  Color(0xFFAED6FF),
  Color(0xFFA4E2F2),
  Color(0xFFFFC982),
  Color(0xFFA8E7B0),
];

const interfaceSoftPalette = <Color>[
  AppTokens.blueSoft,
  AppTokens.lavender,
  AppTokens.greenSoft,
  AppTokens.yellowSoft,
  AppTokens.redSoft,
  AppTokens.cyanSoft,
];

({String emoji, Color background, Color foreground}) _pageVisual(String title) {
  final value = title.toLowerCase();
  if (value.contains('estat')) {
    return (
      emoji: '📊',
      background: AppTokens.lavender,
      foreground: AppTokens.purple,
    );
  }
  if (value.contains('calend') ||
      value.contains('cronograma') ||
      value.contains('plano')) {
    return (
      emoji: '🗓️',
      background: AppTokens.blueSoft,
      foreground: AppTokens.blue,
    );
  }
  if (value.contains('edital') || value.contains('biblioteca')) {
    return (
      emoji: '📚',
      background: AppTokens.yellowSoft,
      foreground: AppTokens.orange,
    );
  }
  if (value.contains('disciplina') || value.contains('ciclo')) {
    return (
      emoji: '🧠',
      background: AppTokens.cyanSoft,
      foreground: AppTokens.teal,
    );
  }
  if (value.contains('sessão') || value.contains('foco')) {
    return (
      emoji: '⏱️',
      background: AppTokens.redSoft,
      foreground: AppTokens.coral,
    );
  }
  if (value.contains('projeto')) {
    return (
      emoji: '🎯',
      background: AppTokens.greenSoft,
      foreground: AppTokens.green,
    );
  }
  if (value.contains('config')) {
    return (
      emoji: '⚙️',
      background: AppTokens.hover,
      foreground: AppTokens.muted,
    );
  }
  if (value.contains('quest')) {
    return (
      emoji: '✅',
      background: AppTokens.greenSoft,
      foreground: AppTokens.green,
    );
  }
  return (
    emoji: '✨',
    background: AppTokens.lavender,
    foreground: AppTokens.purple,
  );
}

Color _semanticForeground(Color background) => switch (background) {
  AppTokens.greenSoft => AppTokens.green,
  AppTokens.blueSoft => AppTokens.blue,
  AppTokens.yellowSoft => AppTokens.orange,
  AppTokens.redSoft => AppTokens.coral,
  AppTokens.cyanSoft => AppTokens.teal,
  AppTokens.lavender => AppTokens.purple,
  _ => AppTokens.ink,
};

const demoDisciplines = <String>[
  'Língua Portuguesa',
  'Direito Penal',
  'Dir. Constitucional',
  'Dir. Administrativo',
  'Proc. Civil',
  'Proc. Penal',
  'Legislação Interna',
  'Matemática',
  'Informática',
  'Raciocínio Lógico',
  'Atualidades',
  'Estatuto da PCD',
];

class PlannerPageFrame extends StatelessWidget {
  const PlannerPageFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final visual = _pageVisual(title);
      return ListView(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 28,
          22,
          compact ? 16 : 28,
          36,
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTokens.pageMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: compact ? 43 : 50,
                      height: compact ? 43 : 50,
                      decoration: BoxDecoration(
                        color: visual.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        size: compact ? 24 : 27,
                        color: visual.foreground,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                visual.emoji,
                                style: TextStyle(fontSize: compact ? 20 : 23),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppTokens.muted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...actions,
                  ],
                ),
                if (compact && actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
                const SizedBox(height: 22),
                child,
              ],
            ),
          ),
        ],
      );
    },
  );
}

class PlannerCard extends StatelessWidget {
  const PlannerCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Colors.white,
    elevation: 0.6,
    shadowColor: const Color(0x18000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radius),
      side: const BorderSide(color: AppTokens.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {this.icon, this.trailing, super.key});
  final String label;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tint =
        interfaceSoftPalette[label.codeUnits.fold<int>(0, (a, b) => a + b) %
            interfaceSoftPalette.length];
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: _semanticForeground(tint)),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.progress,
    this.tint,
    this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final double? progress;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PlannerCard(
    padding: EdgeInsets.zero,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 74;
        return InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tight ? 8 : 15),
            child: Row(
              children: [
                Container(
                  width: tight ? 32 : 42,
                  height: tight ? 32 : 42,
                  decoration: BoxDecoration(
                    color: tint ?? AppTokens.hover,
                    borderRadius: BorderRadius.circular(tight ? 9 : 12),
                  ),
                  child: Icon(
                    icon,
                    size: tight ? 18 : 22,
                    color: _semanticForeground(tint ?? AppTokens.hover),
                  ),
                ),
                SizedBox(width: tight ? 8 : 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTokens.muted,
                          fontSize: tight ? 10.5 : 13,
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: tight ? 17 : 23,
                        ),
                      ),
                      if (!tight && detail != null)
                        Text(
                          detail!,
                          style: const TextStyle(
                            color: AppTokens.muted,
                            fontSize: 12,
                          ),
                        ),
                      if (!tight && progress != null) ...[
                        const SizedBox(height: 7),
                        MiniProgress(value: progress!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class DisciplineChip extends StatelessWidget {
  const DisciplineChip(
    this.label, {
    this.index = 0,
    this.compact = false,
    super.key,
  });
  final String label;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 8 : 10,
      vertical: compact ? 4 : 5,
    ),
    decoration: BoxDecoration(
      color: disciplinePalette[index % disciplinePalette.length].withValues(
        alpha: .62,
      ),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 11 : 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class MiniProgress extends StatelessWidget {
  const MiniProgress({
    required this.value,
    this.color = AppTokens.ink,
    this.height = 7,
    super.key,
  });
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      minHeight: height,
      value: value.clamp(0, 1),
      color: color,
      backgroundColor: const Color(0xFFE9EAED),
    ),
  );
}

void showPlannerNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

class AdaptiveDraggable<T extends Object> extends StatelessWidget {
  const AdaptiveDraggable({
    required this.data,
    required this.feedback,
    required this.child,
    this.childWhenDragging,
    this.maxSimultaneousDrags,
    super.key,
  });

  final T data;
  final Widget feedback;
  final Widget child;
  final Widget? childWhenDragging;
  final int? maxSimultaneousDrags;

  bool get _usesMouse => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    if (_usesMouse) {
      return Draggable<T>(
        data: data,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        maxSimultaneousDrags: maxSimultaneousDrags,
        child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
      );
    }
    return LongPressDraggable<T>(
      data: data,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      maxSimultaneousDrags: maxSimultaneousDrags,
      child: child,
    );
  }
}
