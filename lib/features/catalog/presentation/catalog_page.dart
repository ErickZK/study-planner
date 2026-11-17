import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/planner_ui.dart';
import '../application/catalog_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog.dart';

class _DisciplineDrag {
  const _DisciplineDrag(this.id);
  final String id;
}

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});
  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final expandedDisciplines = <String>{};
  final expandedSubjects = <String>{};
  String query = '';
  bool busy = false;
  String? selectedDisciplineId;

  Future<void> perform(
    Future<dynamic> Function(CatalogRepository) action,
  ) async {
    if (busy || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(catalogActionsProvider).run(action);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is CatalogException
                  ? error.message
                  : 'Não foi possível salvar. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit({
    Discipline? discipline,
    Subject? subject,
    String? disciplineId,
    String? parentId,
  }) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _CatalogEditor(
        title: discipline != null || subject != null
            ? 'Editar conteúdo'
            : disciplineId == null
            ? 'Nova disciplina'
            : 'Novo assunto',
        name: subject?.name ?? discipline?.name ?? '',
        description: subject?.description ?? discipline?.description ?? '',
      ),
    );
    if (result == null || !mounted) return;
    await perform((repository) async {
      if (subject != null) {
        await repository.editSubject(
          subject.id,
          result.$1,
          description: result.$2,
        );
      } else if (discipline != null) {
        await repository.editDiscipline(
          discipline.id,
          result.$1,
          description: result.$2,
        );
      } else if (disciplineId != null) {
        await repository.createSubject(
          disciplineId,
          result.$1,
          parentId: parentId,
          description: result.$2,
        );
      } else {
        await repository.createDiscipline(result.$1, description: result.$2);
      }
    });
  }

  Future<void> remove(
    Catalog catalog,
    Discipline discipline, [
    Subject? subject,
  ]) async {
    final count = subject == null
        ? catalog.subjects.where((s) => s.disciplineId == discipline.id).length
        : catalog.subtree(subject.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${subject?.name ?? discipline.name}?'),
        content: Text(
          'Esta exclusão é global e removerá $count assunto(s) da lista ativa${subject == null ? ' e a disciplina' : ', incluindo o assunto selecionado e seus descendentes'}. '
          'Os registros serão preservados internamente para manter o histórico dos cronogramas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await perform(
        (r) => subject == null
            ? r.deleteDiscipline(discipline.id)
            : r.deleteSubject(subject.id),
      );
    }
  }

  Future<void> move(Catalog catalog, Subject subject) async {
    final destination = await showDialog<String>(
      context: context,
      builder: (context) => _MoveDialog(
        subject: subject,
        parents: catalog.validParents(subject.id),
        catalog: catalog,
      ),
    );
    if (destination != null && mounted) {
      await perform(
        (r) =>
            r.moveSubject(subject.id, destination.isEmpty ? null : destination),
      );
    }
  }

  Widget subjectDrop(
    Catalog catalog,
    Discipline discipline,
    String? parentId, {
    String? beforeId,
    required Widget child,
  }) => DragTarget<String>(
    onWillAcceptWithDetails: (details) {
      if (busy) return false;
      final source = catalog.byId[details.data];
      return source != null &&
          source.disciplineId == discipline.id &&
          (parentId == null ||
              catalog.validParents(source.id).any((s) => s.id == parentId));
    },
    onAcceptWithDetails: (details) => perform(
      (r) => beforeId == null
          ? r.moveSubject(details.data, parentId)
          : r.placeSubjectBefore(details.data, beforeId),
    ),
    builder: (context, candidates, rejected) => ColoredBox(
      color: candidates.isEmpty ? Colors.transparent : AppTokens.hover,
      child: child,
    ),
  );

  Widget subjectRow(
    Catalog catalog,
    Discipline discipline,
    Subject subject,
    int depth,
  ) {
    final siblings = catalog.children(discipline.id, subject.parentId);
    final index = siblings.indexWhere((s) => s.id == subject.id);
    final hasChildren = catalog.children(discipline.id, subject.id).isNotEmpty;
    final row = Row(
      children: [
        AdaptiveDraggable<String>(
          data: subject.id,
          maxSimultaneousDrags: busy ? 0 : 1,
          feedback: Material(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(subject.name),
            ),
          ),
          child: const SizedBox(
            width: 32,
            height: 48,
            child: Tooltip(
              message: 'Manter pressionado para arrastar',
              child: Icon(Icons.drag_indicator, size: 18),
            ),
          ),
        ),
        IconButton(
          tooltip: expandedSubjects.contains(subject.id)
              ? 'Recolher assunto'
              : 'Expandir assunto',
          onPressed: hasChildren
              ? () => setState(() {
                  if (!expandedSubjects.add(subject.id)) {
                    expandedSubjects.remove(subject.id);
                  }
                })
              : null,
          icon: Icon(
            hasChildren
                ? (expandedSubjects.contains(subject.id)
                      ? Icons.expand_more
                      : Icons.chevron_right)
                : Icons.remove,
            size: 20,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (depth > 3)
                Text(
                  'Nível ${depth + 1}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (subject.description != null)
                Text(
                  subject.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >=
            AppTokens.desktopBreakpoint) ...[
          IconButton(
            tooltip: 'Subir ${subject.name}',
            icon: const Icon(Icons.arrow_upward),
            onPressed: busy || index == 0
                ? null
                : () => perform(
                    (r) => r.moveSubject(
                      subject.id,
                      subject.parentId,
                      index: index - 1,
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Descer ${subject.name}',
            icon: const Icon(Icons.arrow_downward),
            onPressed: busy || index == siblings.length - 1
                ? null
                : () => perform(
                    (r) => r.moveSubject(
                      subject.id,
                      subject.parentId,
                      index: index + 1,
                    ),
                  ),
          ),
        ],
        PopupMenuButton<String>(
          enabled: !busy,
          tooltip: 'Ações de ${subject.name}',
          onSelected: (action) {
            switch (action) {
              case 'add':
                setState(() => expandedSubjects.add(subject.id));
                edit(disciplineId: discipline.id, parentId: subject.id);
              case 'edit':
                edit(subject: subject);
              case 'copy':
                perform((r) => r.duplicateSubject(subject.id));
              case 'delete':
                remove(catalog, discipline, subject);
              case 'move':
                move(catalog, subject);
              case 'up':
                perform(
                  (r) => r.moveSubject(
                    subject.id,
                    subject.parentId,
                    index: index - 1,
                  ),
                );
              case 'down':
                perform(
                  (r) => r.moveSubject(
                    subject.id,
                    subject.parentId,
                    index: index + 1,
                  ),
                );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'add', child: Text('Novo subassunto')),
            const PopupMenuItem(value: 'edit', child: Text('Editar assunto')),
            const PopupMenuItem(
              value: 'move',
              child: Text('Mover para outro nível'),
            ),
            PopupMenuItem(
              value: 'up',
              enabled: index > 0,
              child: const Text('↑ Subir'),
            ),
            PopupMenuItem(
              value: 'down',
              enabled: index < siblings.length - 1,
              child: const Text('↓ Descer'),
            ),
            const PopupMenuItem(
              value: 'copy',
              child: Text('Duplicar com descendentes'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Excluir assunto'),
            ),
          ],
        ),
      ],
    );
    // Drop above a row to reorder; drop on it to make it the new parent.
    return Padding(
      padding: EdgeInsets.only(left: (depth > 3 ? 3 : depth) * 12.0),
      child: Column(
        children: [
          subjectDrop(
            catalog,
            discipline,
            subject.parentId,
            beforeId: subject.id,
            child: const SizedBox(
              height: 16,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Divider(height: 1),
              ),
            ),
          ),
          subjectDrop(catalog, discipline, subject.id, child: row),
        ],
      ),
    );
  }

  Widget disciplineCard(Catalog catalog, Discipline discipline) {
    final index = catalog.disciplines.indexOf(discipline);
    return Column(
      children: [
        DragTarget<_DisciplineDrag>(
          onWillAcceptWithDetails: (d) => !busy && d.data.id != discipline.id,
          onAcceptWithDetails: (d) =>
              perform((r) => r.placeDisciplineBefore(d.data.id, discipline.id)),
          builder: (context, candidates, rejected) => SizedBox(
            height: 16,
            child: Divider(
              color: candidates.isEmpty ? AppTokens.border : AppTokens.focus,
            ),
          ),
        ),
        Row(
          children: [
            AdaptiveDraggable<_DisciplineDrag>(
              data: _DisciplineDrag(discipline.id),
              maxSimultaneousDrags: busy ? 0 : 1,
              feedback: Material(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(discipline.name),
                ),
              ),
              child: const SizedBox(
                width: 32,
                height: 48,
                child: Tooltip(
                  message: 'Arrastar disciplina',
                  child: Icon(Icons.drag_indicator, size: 18),
                ),
              ),
            ),
            IconButton(
              tooltip: expandedDisciplines.contains(discipline.id)
                  ? 'Recolher disciplina'
                  : 'Expandir disciplina',
              onPressed: () => setState(() {
                if (!expandedDisciplines.add(discipline.id)) {
                  expandedDisciplines.remove(discipline.id);
                }
              }),
              icon: Icon(
                expandedDisciplines.contains(discipline.id)
                    ? Icons.expand_more
                    : Icons.chevron_right,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discipline.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (discipline.description != null)
                    Text(
                      discipline.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width >=
                AppTokens.desktopBreakpoint) ...[
              IconButton(
                tooltip: 'Subir ${discipline.name}',
                icon: const Icon(Icons.arrow_upward),
                onPressed: busy || index == 0
                    ? null
                    : () => perform(
                        (r) => r.reorderDiscipline(discipline.id, index - 1),
                      ),
              ),
              IconButton(
                tooltip: 'Descer ${discipline.name}',
                icon: const Icon(Icons.arrow_downward),
                onPressed: busy || index == catalog.disciplines.length - 1
                    ? null
                    : () => perform(
                        (r) => r.reorderDiscipline(discipline.id, index + 1),
                      ),
              ),
            ],
            PopupMenuButton<String>(
              enabled: !busy,
              tooltip: 'Ações de ${discipline.name}',
              onSelected: (action) {
                switch (action) {
                  case 'add':
                    setState(() => expandedDisciplines.add(discipline.id));
                    edit(disciplineId: discipline.id);
                  case 'edit':
                    edit(discipline: discipline);
                  case 'copy':
                    perform((r) => r.duplicateDiscipline(discipline.id));
                  case 'delete':
                    remove(catalog, discipline);
                  case 'up':
                    perform(
                      (r) => r.reorderDiscipline(discipline.id, index - 1),
                    );
                  case 'down':
                    perform(
                      (r) => r.reorderDiscipline(discipline.id, index + 1),
                    );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'add', child: Text('Novo assunto')),
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar disciplina'),
                ),
                PopupMenuItem(
                  value: 'up',
                  enabled: index > 0,
                  child: const Text('↑ Subir'),
                ),
                PopupMenuItem(
                  value: 'down',
                  enabled: index < catalog.disciplines.length - 1,
                  child: const Text('↓ Descer'),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Text('Duplicar disciplina'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir disciplina'),
                ),
              ],
            ),
          ],
        ),
        if (expandedDisciplines.contains(discipline.id)) ...[
          subjectDrop(
            catalog,
            discipline,
            null,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Raiz da disciplina · solte aqui para mover à raiz',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          if (catalog.children(discipline.id, null).isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhum assunto nesta disciplina.'),
            ),
          for (final row in catalog.visible(discipline.id, expandedSubjects))
            subjectRow(catalog, discipline, row.$1, row.$2),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PlannerPageFrame(
    icon: Icons.layers_outlined,
    title: 'Disciplinas e assuntos',
    subtitle: 'Organize o conteúdo usado nos editais e planejamentos.',
    actions: [
      FilledButton.icon(
        onPressed: busy ? null : () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nova disciplina'),
      ),
    ],
    child: Column(
      children: [
        if (busy) const LinearProgressIndicator(),
        ref
            .watch(catalogProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => PlannerCard(
                child: Column(
                  children: [
                    const Text('Não foi possível carregar o catálogo.'),
                    TextButton(
                      onPressed: () => ref.invalidate(catalogProvider),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
              data: _catalogWorkspace,
            ),
      ],
    ),
  );

  Widget _catalogWorkspace(Catalog catalog) {
    final filtered = catalog.search(query);
    final selected =
        catalog.disciplines
            .where((discipline) => discipline.id == selectedDisciplineId)
            .firstOrNull ??
        catalog.disciplines.firstOrNull;
    if (selected != null && selectedDisciplineId == null) {
      selectedDisciplineId = selected.id;
      expandedDisciplines.add(selected.id);
    }
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            final list = _disciplineList(catalog, filtered, selected);
            final tree = _selectedTree(catalog, selected);
            final details = _disciplineDetails(catalog, selected);
            if (compact) {
              return Column(
                children: [
                  list,
                  const SizedBox(height: 12),
                  tree,
                  const SizedBox(height: 12),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: list),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: tree),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        PlannerCard(
          child: InkWell(
            onTap: () => context.go('/schedules'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.upload_file_outlined, size: 42),
                  SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importar conteúdo do edital',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Abra um plano de estudos para importar o material TJSP 2026 e revisar o conteúdo antes de usar.',
                          style: TextStyle(color: AppTokens.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _disciplineList(
    Catalog catalog,
    List<Discipline> disciplines,
    Discipline? selected,
  ) => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Disciplinas (${catalog.disciplines.length})',
          icon: Icons.layers_outlined,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Pesquisar disciplinas',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (text) => setState(() => query = text),
        ),
        const SizedBox(height: 10),
        if (disciplines.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhuma disciplina encontrada.'),
          ),
        for (final entry in disciplines.indexed)
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() {
              selectedDisciplineId = entry.$2.id;
              expandedDisciplines.add(entry.$2.id);
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              decoration: BoxDecoration(
                color: selected?.id == entry.$2.id ? AppTokens.greenSoft : null,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.drag_indicator,
                    size: 17,
                    color: AppTokens.muted,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color:
                          disciplinePalette[entry.$1 %
                              disciplinePalette.length],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      entry.$2.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: selected?.id == entry.$2.id
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTokens.hover,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${catalog.subjects.where((subject) => subject.disciplineId == entry.$2.id).length} assuntos',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _selectedTree(Catalog catalog, Discipline? selected) => PlannerCard(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
    child: selected == null
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Crie uma disciplina para começar.'),
          )
        : Column(
            children: [
              disciplineCard(catalog, selected),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          setState(() => expandedDisciplines.add(selected.id));
                          edit(disciplineId: selected.id);
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar assunto'),
                ),
              ),
            ],
          ),
  );

  Widget _disciplineDetails(
    Catalog catalog,
    Discipline? selected,
  ) => PlannerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Detalhes da disciplina', icon: Icons.info_outline),
        const SizedBox(height: 16),
        const Text(
          'Nome da disciplina',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey(selected?.id),
          initialValue: selected?.name ?? '',
          readOnly: true,
        ),
        const SizedBox(height: 16),
        const Text('Descrição', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('description-${selected?.id}'),
          initialValue: selected?.description ?? 'Sem descrição.',
          readOnly: true,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_tree_outlined),
          title: const Text('Assuntos cadastrados'),
          trailing: Text(
            selected == null
                ? '0'
                : '${catalog.subjects.where((subject) => subject.disciplineId == selected.id).length}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: selected == null || busy
              ? null
              : () => edit(discipline: selected),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar disciplina'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    ),
  );
}

class _CatalogEditor extends StatefulWidget {
  const _CatalogEditor({
    required this.title,
    required this.name,
    required this.description,
  });
  final String title;
  final String name;
  final String description;
  @override
  State<_CatalogEditor> createState() => _CatalogEditorState();
}

class _CatalogEditorState extends State<_CatalogEditor> {
  late final name = TextEditingController(text: widget.name);
  late final description = TextEditingController(text: widget.description);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  void save() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, (name.text, description.text));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                maxLength: 120,
                validator: validateCatalogName,
                decoration: const InputDecoration(labelText: 'Nome'),
                onFieldSubmitted: (_) => save(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: save, child: const Text('Salvar')),
    ],
  );
}

class _MoveDialog extends StatefulWidget {
  const _MoveDialog({
    required this.subject,
    required this.parents,
    required this.catalog,
  });
  final Subject subject;
  final List<Subject> parents;
  final Catalog catalog;
  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  late String destination = widget.subject.parentId ?? '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mover assunto'),
    content: SizedBox(
      width: 440,
      child: DropdownButtonFormField<String>(
        initialValue: destination,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Novo pai na mesma disciplina',
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Raiz da disciplina')),
          for (final parent in widget.parents)
            DropdownMenuItem(
              value: parent.id,
              child: Text(
                widget.catalog.path(parent.id),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) => setState(() => destination = value ?? ''),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, destination),
        child: const Text('Mover'),
      ),
    ],
  );
}
