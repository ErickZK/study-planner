# Validação F1.1-SEED-01 — dados demonstrativos

## Implementação

- `lib/core/database/seeds/demo_data_seed.dart`: dataset v1 declarativo, IDs
  estáveis, inserção recursiva, transação, idempotência e remoção isolada.
- `lib/features/catalog/data/catalog_repository.dart`: inserções com ID
  determinístico e remoção lógica por namespace.
- `lib/features/settings/presentation/settings_page.dart`: confirmação,
  feedback, atualização do provider e controles somente em `kDebugMode`.
- `lib/app/router/app_router.dart`: rota funcional de configurações.
- `test/demo_data_seed_test.dart`: quantidade, idempotência, hierarquia,
  rollback, isolamento e reabertura do banco.

O dataset contém 6 disciplinas. A quantidade de assuntos é calculada a partir
da árvore declarativa em `demoExpectedStats`, evitando listas paralelas na UI.

## Uso

Em build debug, abra **Configurações → Dados de demonstração**. O carregamento
confirma a ação, persiste a árvore no SQLite e invalida o catálogo. A remoção
confirma a ação e aplica exclusão lógica somente aos IDs `demo-v1-`, preservando
disciplinas e assuntos reais.

## Validação executada

Comandos a executar no ambiente Flutter:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```

O código foi formatado e compilado diretamente para kernel Dart durante a
implementação. A validação oficial do Flutter permanece pendente se o bloqueio
de permissões do SDK (`.dart_tool`/arquivo de lock) persistir. Não classificar
testes ou builds como aprovados sem os resultados desses comandos.

## Git

O repositório possui remoto `origin`. A branch proposta é
`feat/f1-1-demo-seed`, com commit `feat(dev): add deterministic demo data seed
for catalog testing`; criação de refs, commit e push devem ser tentados no
PowerShell externo caso o ambiente não permita escrita em `.git`. Não usar
force push.

Estado desta execução: `dart format --output=none --set-exit-if-changed lib test`
e `dart analyze` dos arquivos alterados não reportaram saída de erro. Os
comandos oficiais `flutter analyze`, `flutter test` e os builds foram
bloqueados pelo ambiente do SDK e devem ser repetidos externamente. Git também
foi bloqueado por permissão em `.git/index.lock`; não foi criado commit nem
branch local nesta sessão.
Contagem esperada do dataset: 6 disciplinas e 91 assuntos.
