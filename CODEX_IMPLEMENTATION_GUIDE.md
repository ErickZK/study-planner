# Study Planner — Guia de implementação para Codex

## Missão
Construir aplicativo **genérico**, offline-first, para **Windows e Android**, usando **Flutter/Dart**, **SQLite/Drift** e **Riverpod**, com UI minimalista inspirada no Notion (branco/preto/cinzas). Não incluir concursos, disciplinas ou dados de TJSP/INSS pré-cadastrados. Não confundir com AprovaIA: é um produto separado.

## Instrução inicial ao Codex
1. Inspecione o repositório e registre estado, testes, arquitetura e dependências existentes. Não sobrescreva trabalho prévio.
2. Se estiver vazio, inicialize Flutter com alvos Windows e Android. Confirme versões disponíveis e compatibilidade dos pacotes antes de adotá-los.
3. Escreva `docs/architecture.md`, `docs/data-model.md`, `docs/decisions.md`, `docs/qa.md` e `docs/roadmap.md`. Use este guia como especificação principal.
4. Trabalhe por fases pequenas com migrações, testes, análise estática e commits Conventional Commits. Não declare uma fase aprovada sem testes executados; registre bloqueios de SDK/emulador/dispositivo.
5. Não faça perguntas de produto para decisões já especificadas. Em lacunas menores, escolha solução simples e documente em ADR; peça confirmação somente para bloqueio material.

## Requisitos transversais
- 100% offline, sem conta, servidor, nuvem ou sincronização. Bancos independentes por dispositivo.
- Banco SQLite como fonte canônica; Drift com migrations versionadas, constraints, índices, chaves estrangeiras e transações.
- Camadas por feature: presentation / application / domain / data. Riverpod para estado e DI; lógica de negócio fora de widgets.
- Design responsivo desktop/mobile, navegação por teclado, semântica e acessibilidade, estados vazios, loading, erros e confirmações destrutivas.
- Cores neutras, sem roxo nem gradientes. UI com densidade de informações e organização semelhante ao Notion, sem copiar sua identidade visual.
- Dados locais, validação de formulários, nenhuma telemetria ou rede implícita.

## Entidades e relacionamentos (modelo lógico proposto)
- `projects`: id, name, description, status(active/archived), created_at, updated_at.
- `disciplines`: catálogo global; id, name, status.
- `topics`: id, discipline_id, parent_topic_id nullable, name, position, status; hierarquia recursiva ilimitada; impedir ciclos.
- `syllabi`: 1 por projeto; `syllabus_topics` associa tópicos selecionados; `topic_progress` por identidade de tópico (compartilhado entre projetos que usam o mesmo tópico).
- `schedules`: id, project_id, name, daily_minutes_default, start_time_default, break_minutes, status, favorite; cada cronograma tem exatamente um Planner lógico (mesma fonte de atividades), não duas cópias de dados.
- `schedule_day_overrides`: schedule_id, local_date, planned_minutes, start_time.
- `activities`: id, schedule_id, original_date, scheduled_date, position, kind(study/review/simulation/reading/other), status, planned_minutes, duration_policy, recurrence_occurrence_id nullable, original_activity_id nullable.
- `activity_topics`: activity_id, topic_id, position, completed_at nullable; atividades podem ser desvinculadas ou associadas a múltiplos tópicos.
- `recurrence_series` e `recurrence_occurrences`: regra daily/weekly/monthly, identidade estável e exceções; editar somente esta/esta e futuras/toda série.
- `study_sessions`: id, activity_id obrigatório, source(timer/manual), local_study_date, actual_seconds, question_count, correct_count, notes, source_session_id nullable, created_at, updated_at.
- `timer_state`: sessão aberta única, accumulated_seconds, monotonic segment bookkeeping e último checkpoint; persistência transacional.
- `topic_notes`: conteúdo rico simplificado por tópico; copiar independentemente ao clonar tópico.
- `library_folders`: parent_id, name, status(active/trash); `library_files`: id, folder_id, content_hash, storage_key, original_name, mime_type, byte_size, status; `note_file_links`: associações sem duplicar bytes.
- `notifications_settings`, `app_settings` e metadados de schema/backup.
- Datas locais para agenda; timestamps UTC com timezone/offset quando necessário; UUIDs para IDs estáveis e referências de origem.

## Regras de projetos, disciplinas e editais
- Projeto pode ser criado vazio ou via wizard (nome, disciplinas, edital, primeiro cronograma); arquivar é reversível; exclusão exige confirmação e política consistente de preservação histórica.
- Um edital verticalizado por projeto, compartilhado entre cronogramas desse projeto. Progresso percentual considera somente os tópicos selecionados no edital.
- Disciplinas/tópicos globais reutilizáveis em projetos; progresso de **mesma identidade de tópico** é global e compartilhado. Tópicos removidos de um edital não são apagados globalmente.
- Hierarquia ilimitada; pai só é concluído se todos os descendentes estiverem concluídos; não permitir concluir pai com filhos pendentes.
- Cadastro de disciplinas/tópicos exclusivamente manual (sem importação TXT/CSV/XLSX/PDF/DOCX para criação de edital). Reordenar por drag-and-drop e botões, inclusive entre níveis, prevenindo ciclos.
- Duplicar tópico/subárvore ou disciplina completa. Ao **editar** um tópico compartilhado num projeto, usar copy-on-write para não afetar outros projetos: a cópia herda progresso e notas/anexos, mas evolui independentemente.
- Anotações de um tópico compartilhado são globais entre projetos que apontam para **a mesma identidade**; cópias independentes recebem cópia editável das notas e links para os mesmos arquivos físicos.
- Histórico de sessões ao duplicar tópico: copiar referências/registros de sessões para a cópia, editáveis independentemente, preservando `source_session_id`/proveniência. Relatórios mostram **tempo efetivo único** e **tempo atribuído a assuntos** (pode multiplicar atribuições). Se duração original for corrigida, agregados derivados devem refletir correção, sem sobrescrever a duração individual armazenada na cópia. Formalizar consultas e invariantes em testes.
- Exclusão de sessão original com cópias: oferecer preservar cópias ou excluir também derivadas; confirmação com impacto. Exclusão de sessões é definitiva, sem lixeira; edição de sessão não mantém audit trail.
- Excluir tópico/pai requer confirmação e preservar histórico de estudo mesmo quando os vínculos ativos forem removidos; operações destrutivas de catálogo não podem deixar FKs órfãs.

## Cronograma, Planner e atividades
- Cada cronograma tem calendário e atividades próprios, independentes dos demais cronogramas, mesmo dentro do mesmo projeto; o edital é compartilhado.
- Planner e cronograma são **duas visões dos mesmos dados**: tabela e calendário com mês/semana/dia e timeline do dia. Edição inline, drag-and-drop, autosave e atualização reativa.
- Planejamento exclusivamente manual; usuário escolhe tópicos/datas. Atividades podem ter zero, um ou vários tópicos.
- Divisão igualitária de `daily_minutes` entre assuntos/tópicos programados originalmente para o dia; alterações de disponibilidade diária recalculam durações planejadas das atividades normais. Definir política determinística de arredondamento em segundos/minutos e testar soma exata.
- Início fixo configurável para o dia; atividades sequenciais na ordem manual; pausa fixa entre assuntos, adicionada ao tempo de estudo, sem reduzi-lo. Reordenar recalcula horários. Se estudo iniciar atrasado, perguntar se mantém horários ou desloca os seguintes.
- Atrasos: atividades não concluídas permanecem identificadas como atrasadas e são realocadas para **próximo dia originalmente vazio**, inclusive finais de semana/feriados; lote de atrasadas pode acumular no mesmo dia livre. Preservar data original, duração planejada original, histórico e identidade; não duplicar atividade. Mostrar sobrecarga; não recalcular duração de atividade carregada por atraso. Se continuar pendente, carregar para próximo dia vazio.
- Atividade parcialmente estudada: mover somente os tópicos pendentes; concluídos permanecem no histórico da data original. Preservar vínculo e proveniência da atividade e evitar dupla contagem.
- Recorrência diária/semanal/mensal: ocorrências independentes, não mesclar ocorrência atrasada com a seguinte; editar/excluir somente esta, esta e futuras, ou toda série, com preservação de histórico concluído.
- Revisões criadas **somente manualmente**, sem agendamento espaçado automático.
- Próximo estudo respeita ordem e horário definidos pelo usuário, sem priorização automática de atrasos.
- Conclusão de atividade é **sempre manual**, mesmo que soma de sessões ultrapasse duração planejada. Exibir `estudado/planejado` e `+excedente`.
- Ao concluir sem sessões: perguntar registrar tempo ou concluir com 0 min.
- Ao concluir com tópicos pendentes: perguntar marcar todos como estudados ou concluir mantendo pendentes. Se mantidos pendentes, perguntar deixar apenas no edital ou criar atividade posterior; se criar, permitir data manual ou sugestão de próximo dia vazio (decisão de produto ainda não confirmada; implementar as duas opções como default pragmático) e dividir tempo disponível do novo dia igualmente.
- Marcar tópico como estudado num cronograma atualiza progresso global do tópico, mas **não conclui automaticamente tarefas em outros cronogramas**. A conclusão de cada atividade é independente.
- Permitir desfazer conclusão com recálculo de progresso, sem apagar sessões.

## Sessões, questões e cronômetro
- Cronômetro start/pause/resume/finish; pausa manual durante uso normal, sem detector de inatividade; pausa não soma tempo.
- Ao atingir duração planejada, alertar e oferecer continuar ou finalizar, nunca encerrar automaticamente.
- Ao encerrar antes do tempo, mostrar tempo real e oferecer concluir ou reagendar saldo; respeitar as regras de conclusão e tópicos pendentes.
- Uma única sessão de cronômetro aberta por vez, inclusive se pausada. Várias sessões **finalizadas** podem pertencer à mesma atividade e somam tempo sem teto.
- Sessões manuais permitidas **somente vinculadas a atividade existente**, inclusive concluída; data local atual ou passada, duração obrigatória, sem exigir horários de início/fim. Sessão adicionada a atividade concluída não reabre a atividade.
- Questões/acertos inseridos no fim da sessão, manualmente; validar `0 <= acertos <= total`; erros = total - acertos. Permitir corrigir livremente sessões finalizadas (tempo, disciplina/assuntos por vínculo, questões, acertos, observações), sem histórico de versões, recalculando relatórios.
- Sessão que atravessa meia-noite: atribuir todo tempo à **data local de início**.
- Tempo preciso: usar relógio monotônico durante segmentos ativos, UI atualizada a cada segundo, checkpoints persistidos; não somar ticks visuais. Monotonic não atravessa reboot.
- Ao **fechar** app: pausar e persistir; ao **alternar** app ou apagar/bloquear tela Android: continuar contando, sujeito às restrições do sistema. Ao reabrir após fechamento/reboot, recuperar pausada com botões Continuar/Finalizar; não contar tempo com dispositivo desligado.
- Android: serviço em primeiro plano quando necessário para contagem em segundo plano; notificação persistente com tempo e pause/resume quando desbloqueado; na tela de bloqueio mostrar informação sem controles (implementar respeitando limitações de visibilidade/ações do Android e versões da API). Solicitar permissões necessárias de modo contextual.

## Anotações e biblioteca
- Editor simples: títulos, listas, checklists, links, imagens e anexos (PDF e outros), não editor completo de blocos Notion.
- Biblioteca com pastas/subpastas, busca por nome/tipo; conteúdo físico armazenado uma única vez por hash e referenciado por notas/tópicos.
- Remover anexo de um assunto **somente desvincula**, sem apagar arquivo da biblioteca.
- Excluir pasta envia pasta, subpastas e arquivos à **lixeira**, removendo-os das vistas ativas; confirmar impacto em todos os assuntos vinculados. Restaurar pasta/arquivos e vínculos, quando aplicável; exclusão definitiva manual. Nada de prazo automático de limpeza.
- Garantir integridade referencial e atomicidade de alterações entre DB e filesystem (staging/journal/compensação para falhas).

## Backup manual
- **Não implementar backup automático, agendamento ou lembretes**.
- Exportar um único `.studybackup`, contendo SQLite consistente, configurações e arquivos ativos; **não incluir lixeira**. Sem senha ou criptografia; exibir aviso de privacidade.
- Formato interno versionado com manifest, checksums por arquivo, contagens, versão de schema e compatibilidade; escrita atômica e validação de paths para impedir path traversal.
- Restauração é **substituição total**, não mesclagem. Validar pacote, criar cópia preventiva dos dados atuais, pedir confirmação, restaurar em staging, verificar integridade e fazer troca atômica/rollback seguro. Testar backup Windows → Android e vice-versa.

## Dashboard, estatísticas, widgets, notificações
- Dashboard de projetos, cronogramas, próximo estudo, progresso, metas e resumos; permitir cronograma favorito como abertura padrão.
- Estatísticas por dia/semana/mês/disciplina, horas planejadas/reais, questões/acertos/erros/taxa, cobertura do edital, evolução e produtividade. Mostrar explicitamente diferença entre tempo efetivo deduplicado e tempo atribuído aos assuntos.
- Widget Android de tela inicial: próxima atividade pendente do cronograma ativo, início/pausa/retomada e concluir (abrir fluxo de confirmação quando necessário); atualizar após mudanças no DB.
- Widget desktop Windows: investigar e implementar solução viável de janela compacta/overlay/widget próprio, documentando que não há equivalência nativa garantida ao widget Android; não alegar suporte sem prova em Windows real.
- Notificações configuráveis individualmente para início de estudo, tempo atingido, atrasos, revisões manuais e alterações de cronograma, com antecedência configurável; nunca criar lembretes de backup.

## UX e telas
1. Home/dashboard geral de projetos.
2. Criar/editar/arquivar/excluir projeto e wizard inicial.
3. Catálogo global de disciplinas e assuntos com árvore recursiva.
4. Edital verticalizado por projeto, seleção de tópicos, progresso e notas.
5. Gestão de cronogramas por projeto.
6. Planner tabela (edição inline) e calendário mês/semana/dia.
7. Detalhe de atividade, tópicos vinculados, sessões, recorrência e reagendamento.
8. Cronômetro, alertas de término e recuperação de sessão.
9. Registro/edição manual de sessão.
10. Estatísticas e filtros.
11. Editor de notas e biblioteca de arquivos/pastas/lixeira.
12. Configurações, notificações, backup/exportação/restauração.
13. Widget Android e solução Windows compacta.

## Plano de execução por fases
- **F0 — Fundação:** SDK, app shell, tema, navegação responsiva, Drift, Riverpod, migrations, testes e CI local.
- **F1 — Catálogo e projetos:** CRUD, hierarquia recursiva, edição copy-on-write, seleção por edital, progresso global e testes de integridade.
- **F2 — Cronogramas e Planner:** múltiplos cronogramas, tabela/calendário, distribuição de tempo, ordenação, recorrência, atrasos e reagendamentos.
- **F3 — Sessões e timer:** sessões manuais, timer preciso, lifecycle Android/Windows, questões, correções, múltiplas sessões por atividade.
- **F4 — Notas e arquivos:** editor, anexos deduplicados, pastas, lixeira, restauração e integridade filesystem/DB.
- **F5 — Estatísticas:** agregações deduplicadas, histórico copiado, gráficos e filtros.
- **F6 — Backup:** `.studybackup`, manifest, exportação, validação, restore com rollback e compatibilidade cruzada.
- **F7 — Widgets/notificações:** Android foreground service, lockscreen, widget; Windows widget/overlay; configurações de alertas.
- **F8 — QA e release:** testes unitários/widget/integração, acessibilidade, performance, backup cruzado, build Windows e APK/AAB Android, docs de instalação e troubleshooting.

## Critérios mínimos de aceite e testes obrigatórios
- Criar dois projetos com o mesmo tópico global: marcar progresso em um reflete no outro, mas não conclui atividade no outro cronograma.
- Editar tópico compartilhado em um projeto cria cópia independente; progresso/notas/histórico copiados conforme regras; outros projetos inalterados.
- Duplicar sessão não dobra horas efetivas; horas atribuídas podem crescer; editar origem recalcula agregados sem sobrescrever registro da cópia.
- Concluir atividade exige ação humana; tempo atingido não conclui; concluir com pendências exibe opções.
- Várias sessões acumulam tempo, inclusive acima do planejado; mostrar excedente.
- Sessão manual exige atividade, aceita datas passadas, bloqueia futuras e não reabre atividade concluída.
- Reagendamento em lote encontra próximo dia originalmente vazio, preserva durações e não duplica ocorrências recorrentes.
- Alterar horário/ordem recalcula timeline e pausas sem diminuir minutos líquidos de estudo.
- Android: alternar app/bloquear tela mantém timer; fechar/reboot recupera pausado; não contar tempo de dispositivo desligado; notificação de bloqueio sem ações.
- Excluir vínculo de anexo não apaga arquivo; excluir pasta vai à lixeira e restauração reconstitui referências; excluir definitivamente limpa dados e bytes quando não referenciados.
- Backup exclui lixeira, passa checksum, restaura entre Windows/Android, faz rollback após pacote corrompido ou falha simulada; não há backups automáticos nem lembretes.
- `flutter analyze`, `flutter test`, testes de integração e builds em plataformas disponíveis. Relatar resultados reais, cobertura e limitações.

## Entrega de cada fase
Relatório conciso: funcionalidades, arquivos, migrations, comandos/testes executados e resultados, riscos, screenshots quando houver UI, decisões técnicas, pendências e commit `feat(...)`, `fix(...)`, `test(...)` ou `docs(...)`. Não avançar silenciosamente sobre testes falhos.

## Prioridades de resolução de ambiguidades
1. Última escolha explícita do usuário prevalece sobre decisões anteriores (ex.: **conclusão manual**, **sem backups automáticos**).
2. Separar **conclusão da atividade**, **conclusão do tópico** e **tempo estudado**; são conceitos distintos.
3. Não contar sessão duplicada duas vezes como tempo efetivo; manter proveniência.
4. Para reagendamento de tópico pendente, oferecer escolha de data manual ou próximo dia livre por padrão, sem criar agendamento sem consentimento.
5. Para ações destrutivas, exibir impacto, usar transação e testar recuperação.
