import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:study_planner/app/theme/app_theme.dart';

import '../../../core/database/seeds/demo_data_seed.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../projects/application/project_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  Future<void> _loadDemoData() async {
    if (!await _confirm('Carregar dados de demonstração?')) return;
    setState(() => _busy = true);
    try {
      final database = await ref.read(databaseProvider.future);
      final stats = await DemoDataSeed(database).load();
      ref.invalidate(catalogProvider);
      if (mounted) {
        _message(
          '${stats.disciplines} disciplinas e ${stats.subjects} assuntos disponíveis.',
        );
      }
    } catch (error) {
      if (mounted) _message('Não foi possível carregar os dados: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeDemoData() async {
    if (!await _confirm('Remover somente os dados de demonstração?')) return;
    setState(() => _busy = true);
    try {
      final database = await ref.read(databaseProvider.future);
      final stats = await DemoDataSeed(database).remove();
      ref.invalidate(catalogProvider);
      if (mounted) {
        _message(
          '${stats.disciplines} disciplinas e ${stats.subjects} assuntos removidos.',
        );
      }
    } catch (error) {
      if (mounted) _message('Não foi possível remover os dados: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppTokens.large),
        children: [
          Text('Configurações', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppTokens.large),
          if (kDebugMode) ...[
            const Text('Dados de demonstração'),
            const SizedBox(height: AppTokens.small),
            const Text(
              'Carga determinística local para validar o catálogo. Ela usa o banco real e pode ser removida sem afetar dados do usuário.',
            ),
            const SizedBox(height: AppTokens.medium),
            Wrap(
              spacing: AppTokens.small,
              runSpacing: AppTokens.small,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _loadDemoData,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Carregar dados de demonstração'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _removeDemoData,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover dados de demonstração'),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: AppTokens.medium),
              const LinearProgressIndicator(),
            ],
          ] else
            const Text('Dados de demonstração estão disponíveis somente em builds de desenvolvimento.'),
        ],
      );
}
