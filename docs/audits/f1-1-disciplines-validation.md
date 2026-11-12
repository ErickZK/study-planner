# Validação da F1.1 — catálogo global de disciplinas e assuntos

Data: 2026-11-12. Estado: **PENDENTE DE VALIDAÇÃO COMPLETA**.

## Implementação

F1.1 adiciona catálogo global reutilizável, sem dados pré-cadastrados:

- `disciplines`: nome, descrição, posição, timestamps e exclusão lógica.
- `subjects`: disciplina, pai opcional, nome, descrição, posição, timestamps e exclusão lógica.
- IDs string estáveis gerados pelo SQLite; hierarquia ilimitada em termos funcionais.
- FK composta e trigger recursiva impedem pai de outra disciplina, auto-pai e ciclos.
- Repositório para criação, edição, busca, carregamento de árvore, movimento, reordenação, duplicação recursiva e exclusão transacional.
- Tela `/disciplines` com estado vazio, busca, diálogos, expansão/recolhimento, ações contextuais, botões de ordem e drag-and-drop; no mobile as ações ficam acessíveis por menu e toque longo.
- Exclusão pede confirmação e mantém registros inativos para preservar referências futuras. Progresso, edital e copy-on-write entre projetos não foram antecipados.

## Arquivos

Criados: `lib/core/database/migrations/catalog_schema.dart`, `lib/features/catalog/domain/catalog.dart`, `lib/features/catalog/data/catalog_repository.dart`, `lib/features/catalog/application/catalog_providers.dart`, `lib/features/catalog/presentation/catalog_page.dart`, `test/catalog_repository_test.dart` e `test/catalog_widget_test.dart`.

Modificados: `lib/core/database/app_database.dart`, `lib/app/router/app_router.dart`, `test/database_test.dart`, `docs/architecture.md`, `docs/database.md` e `docs/implementation-roadmap.md`.

## Verificações reais

`dart --suppress-analytics format lib test` passou com 19 arquivos. A compilação direta do kernel Dart dos testes passou (`validation-logs/f1-tests.dill`, exit 0), cobrindo referências, tipos e imports. A análise via servidor Dart foi executada diretamente: arquivos da aplicação e testes não apresentaram erros; após a correção de blocos obrigatórios, os lints observados foram eliminados.

Uma smoke test SQLite compilada e executada diretamente passou **15 checks** (`validation-logs/f1-smoke-result.txt`), incluindo criação, edição, busca, árvore de 3 níveis, 2.000 níveis sem recursão da pilha, ciclo, auto-pai, referência cruzada, movimento, ordem, duplicação de assunto/disciplina, independência, exclusão lógica, rollback, migração v1→v2 e reabertura do arquivo.

`dart pub get --offline --enforce-lockfile` passou anteriormente com o lockfile existente. Os comandos oficiais Flutter (`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build windows`, `flutter build apk --debug`) continuam bloqueados nesta sessão: o SDK externo não permite abrir o lockfile e o executor não permite iniciar subprocessos necessários. Não foram declarados testes Flutter ou builds de plataforma como aprovados. Há um `build\app\outputs\flutter-apk\app-debug.apk` de 169.230.898 bytes com timestamp 13:45, mas não há log externo correspondente nesta área de trabalho; sua proveniência e compatibilidade com o código atual não podem ser comprovadas. O executável Windows preexistente não foi atribuído a esta implementação e não serve como evidência de build atual.

Nenhum dispositivo Android ou AVD estava disponível na última inspeção. Execução manual da UI, criação pelo app e reabertura do app continuam pendentes.

## Git e branch

O repositório contém `main` e `origin` (`https://github.com/ErickZK/study-planner.git`). O commit atual é `efadd79 feat: initial study planner project` e já contém a base do catálogo. As correções e testes desta continuação ainda estão no working tree. A branch solicitada `feat/f1-1-disciplines` precisa ser criada e commitada no ambiente com escrita Git autorizada. Nesta sessão, `git switch -c` falhou ao criar `refs/heads/feat/f1-1-disciplines`; `git add`/`commit` continuam bloqueados em metadados Git. Não houve push. Comandos externos:

```powershell
git switch -c feat/f1-1-disciplines
git add lib test docs
git diff --cached --check
git commit -m "feat(catalog): add global disciplines and subjects"
git push -u origin feat/f1-1-disciplines
```

Antes do commit, mantenha caches, bancos, builds, `.tooling`, credenciais e logs ignorados. Não use force push. A integração em `main` só deve ocorrer depois dos comandos oficiais e da execução manual da UI.

## Pendências

Executar `flutter analyze`, `flutter test`, builds Windows/Android e a inspeção manual nos dispositivos disponíveis. Corrigir eventuais incompatibilidades específicas do Flutter no ambiente externo. Validar que o banco v1 existente migra sem perda de projetos. A próxima etapa recomendada é F1.2 (projetos/editais e seleção de tópicos), depois de aprovar esta etapa.
