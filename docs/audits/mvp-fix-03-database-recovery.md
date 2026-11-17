# MVP-FIX-03 — recuperação da inicialização SQLite

## Causa raiz

O banco novo na versão 6 cria `study_sessions.local_study_date` e
`activities.original_date` dentro de `_createMvp()`. Em uma atualização direta
de v1/v2/v3 para v6, a mesma execução de `onUpgrade` continuava para os blocos
v5/v6 e executava `ALTER TABLE ... ADD COLUMN` novamente. SQLite então falhava
com coluna duplicada antes de `AppDatabase.initialize()` concluir, e o
`databaseProvider` exibia a tela genérica de recuperação.

## Correção

- `onUpgrade` verifica `PRAGMA table_info` antes de cada adição de coluna.
- A migração permanece incremental e não recria tabelas nem remove dados.
- Bancos v4 e v5 continuam recebendo somente as colunas ausentes.
- `_createMvp()` continua sendo usado para bancos anteriores à v4.
- `openDatabase` registra exceção e stack trace apenas em modo debug usando
  `developer.log`; a mensagem de produção continua genérica.

## Preservação

O caminho de produção continua sendo resolvido por
`getApplicationSupportDirectory()/study_planner.sqlite`. A correção não apaga,
substitui ou move esse arquivo. O teste de migração usa cópia temporária e
verifica `PRAGMA user_version`, projetos preservados e existência única das
colunas adicionadas.

## Testes adicionados/ajustados

- Banco novo continua coberto por `test/database_test.dart`.
- Reabertura do arquivo e rollback permanecem cobertos.
- Fixture v1 → v6 verifica projeto legado, versão final e ausência de colunas
  duplicadas.
- A expectativa de versão do banco foi atualizada para 6.

## Validação

Executados/tentados nesta sessão:

```powershell
dart format lib test
flutter test --no-pub test/database_test.dart
```

O executor Flutter não retornou saída verificável neste ambiente, portanto o
resultado oficial permanece pendente. Repetir externamente:

Durante a validação externa foram encontrados e corrigidos três problemas de
teste não relacionados ao banco: expectativa antiga de `user_version=2`,
assertion assíncrona de sessão concorrente e um ID de profundidade incorreto no
teste do seed. A suíte deve ser repetida após essas correções.

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build windows
flutter run -d windows
```

## Git

Branch atual: `feat/f1-catalog-syllabus`. O commit isolado recomendado é:

```powershell
git switch -c feat/study-planner-mvp
git add lib/core/database/app_database.dart lib/core/database/open_database.dart test/database_test.dart docs/audits/mvp-fix-03-database-recovery.md
git commit -m "fix(database): resolve startup failure and schema migrations"
git push -u origin feat/study-planner-mvp
```

Não houve push ou force push nesta sessão.
Por solicitação explícita, o schema v7 usa reset destrutivo transacional ao
abrir bancos v1–v6: remove as tabelas conhecidas e recria o schema atual no
mesmo arquivo. Isso corrige estados corrompidos, mas apaga dados locais
anteriores. Nenhuma restauração automática é feita.
