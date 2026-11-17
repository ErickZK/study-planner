# Validação do MVP do Study Planner

## Implementado nesta execução

### Cronogramas

- Schema v4 com cronogramas isolados por projeto.
- CRUD de cronogramas, arquivamento e duplicação.
- Duração diária, horário inicial e intervalo configuráveis.
- Providers Riverpod e tela responsiva de cronogramas.

### Planner e atividades

- Atividades persistidas por cronograma e data.
- Criação de atividades livres ou associadas a IDs de assuntos.
- Distribuição simples de minutos pelo número de assuntos vinculados.
- Conclusão manual e exclusão persistente.
- Acesso ao Planner a partir de cada cronograma.

### Sessões

- Estrutura SQLite para sessões.
- Bloqueio de mais de uma sessão aberta.
- Estados running/paused/finished e registro de questões/acertos.
- Métodos de início, pausa e finalização no repositório.

## Arquivos principais

- `lib/core/database/migrations/mvp_schema.dart`
- `lib/core/database/app_database.dart`
- `lib/features/schedules/data/schedule_repository.dart`
- `lib/features/schedules/presentation/schedules_page.dart`
- `lib/features/planner/data/planner_repository.dart`
- `lib/features/planner/presentation/planner_page.dart`
- `test/schedule_repository_test.dart`

## Pendências do MVP

- Calendário mensal/semanal e visualização diária avançada.
- Timer visual com ciclo monotônico completo e recuperação de lifecycle.
- Edição detalhada de atividades e sessões manuais pela interface.
- Estatísticas agregadas no dashboard.
- Reagendamento, recorrências e distribuição com intervalos detalhados.
- Testes oficiais Flutter, builds Windows/Android e execução em dispositivos.

## Atualização MVP-FINAL

- Entrega A: tela `StudySessionPage`, estados de sessão, histórico, questões,
  acertos, observações, sessão manual no repositório, validação de data futura,
  bloqueio de sessão concorrente e recuperação de sessões running como pausadas.
- O contador usa `Stopwatch` monotônico durante a execução e persiste o valor
  somente em pausas/finalização; ao reabrir, sessões abertas são normalizadas
  para pausadas, sem contar o período em que o aplicativo ficou fechado.
- O repositório agora oferece edição/exclusão de sessões, edição/reordenação de
  atividades, métricas por período e validação de sessões manuais.
- Entrega B: criação, conclusão e navegação para atividades permanecem
  funcionais; edição detalhada, confirmação destrutiva e reagendamento ainda
  estão pendentes.
- Entrega C: dashboard agora consulta horas efetivas, questões, acertos,
  pendências e conclusões diretamente do SQLite. Séries por dia/semana/mês e
  progresso por disciplina ainda precisam ser expandidos.
- Entrega D: Planner diário persistente está disponível; calendários mensal,
  semanal e reordenação por horários ainda não foram concluídos.

A migração foi avançada para schema v5 com `local_study_date` em
`study_sessions`, preservando bancos v4.

## Validação

Os comandos abaixo devem ser executados no PowerShell externo quando o bloqueio
do SDK Flutter persistir:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```

Não foram declarados testes ou builds como aprovados sem saída verificável.

## Git

A branch `feat/study-planner-mvp` não pôde ser criada neste ambiente por
permissão em `.git/refs`. Execute externamente:

```powershell
git switch -c feat/study-planner-mvp
git add .
git commit -m "feat(core): integrate catalog and verticalized syllabus"
git push -u origin feat/study-planner-mvp
```
O Planner recebeu modos Dia/Semana/Mês/Tabela, edição e exclusão confirmada
de atividades, reordenação básica, navegação de datas e reagendamento
transacional de atrasadas. O schema foi avançado para v6 com `original_date`.
MVP-FIX-02: os modos de Planner e o reagendamento foram implementados no
repositório e na interface. `dart format` e `flutter test --no-pub` foram
tentados nesta sessão; o executor Flutter não retornou saída verificável, então
testes e builds permanecem pendentes de execução externa.
