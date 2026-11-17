# Validação F1.2 — edital verticalizado por projeto

## Implementação

- Schema v3 incremental: `vertical_syllabi`, `syllabus_disciplines`,
  `syllabus_topics` e `topic_progress`.
- `SyllabusRepository`: edital único por projeto, seleção parcial, remoção de
  vínculos sem apagar o catálogo, progresso compartilhado, cálculo por folhas e
  copy-on-write transacional.
- `SyllabusPage`: seleção pesquisável de disciplinas/assuntos, árvore
  expansível, checkboxes, progresso e estado vazio responsivo.
- Dashboard e lista de projetos exibem indicadores reais e acesso ao edital.
- `test/syllabus_repository_test.dart`: criação, seleção, compartilhamento,
  cópia independente e rollback.

## Regras preservadas

O catálogo global continua independente dos projetos. Selecionar ou remover um
assunto altera somente o vínculo do edital. A edição compartilhada gera uma
identidade `copy-*` para o projeto atual e herda o progresso; o tópico original
e os demais projetos permanecem inalterados. Anotações, sessões e anexos ainda
não existem no schema e ficam explicitamente reservados para fases posteriores.

## Validação

Executar no PowerShell externo se o bloqueio do SDK persistir:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```

Nesta sessão, a análise/formatação Dart foi iniciada, mas os subprocessos
oficiais Flutter permanecem sujeitos ao bloqueio de permissões/lock já
registrado nas auditorias anteriores. Não classificar a fase como aprovada sem
os resultados reais desses comandos e testes de execução Windows/Android.

## Git

Branch desejada: `feat/f1-2-verticalized-syllabus`.
Commit sugerido: `feat(syllabus): implement project verticalized syllabus`.
O repositório apresentou erro de permissão ao criar refs e `.git/index.lock`,
portanto commit e publicação devem ser realizados no PowerShell com acesso ao
diretório `.git`. Não usar force push.
