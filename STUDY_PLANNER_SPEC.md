# Study Planner — Especificação funcional consolidada

**Status:** baseline de requisitos confirmados pelo usuário  
**Data:** 12/11/2026  
**Destinatário:** Codex / implementação Flutter  
**Natureza:** esta SPEC registra escolhas de produto. Recomendações técnicas e lacunas estão separadas para não serem confundidas com decisões do usuário.

## 1. Visão e limites

**REQ-001.** Aplicativo genérico para criar e gerenciar projetos de estudo, editais verticalizados, disciplinas, assuntos, cronogramas, atividades, sessões, anotações, materiais e estatísticas. TJSP/INSS são exemplos, não conteúdo embutido. Não confundir com AprovaIA.

**REQ-002.** Destinos: Windows e Android. Aplicativo offline, com dados locais independentes em cada dispositivo. Sem autenticação, servidor, nuvem ou sincronização automática. Transferência por backup manual.

**REQ-003.** Stack acordada: Flutter/Dart, SQLite/Drift e Riverpod. UI minimalista inspirada no Notion, branco/preto/cinza, sem roxo. Interfaces adaptadas a desktop e celular.

## 2. Projetos, catálogo e edital verticalizado

**REQ-010.** Criar projeto vazio ou por assistente (nome, disciplinas, edital e cronograma inicial); editar, duplicar, arquivar/desarquivar e excluir mediante confirmação.

**REQ-011.** Cada projeto possui um edital verticalizado único, compartilhado por seus cronogramas; cada cronograma mantém atividades e calendário independentes.

**REQ-012.** Disciplinas e assuntos compõem catálogo global reutilizável. Um edital seleciona apenas os tópicos pertinentes; seu percentual de conclusão considera somente a seleção daquele projeto.

**REQ-013.** Hierarquia recursiva sem limite funcional de níveis: disciplina → assunto → subassuntos. Cadastrar tudo **manualmente**. Não importar automaticamente estrutura de TXT, CSV, XLSX, PDF ou DOCX.

**REQ-014.** Reordenar por arrastar-e-soltar **e** botões; permitir mover entre níveis; impedir ciclos. Duplicar assunto/subárvore individual ou disciplina inteira com descendentes.

**REQ-015.** Progresso de um **mesmo tópico global** é compartilhado entre projetos. Marcar tópico estudado em um projeto reflete no outro; isso **não conclui atividades** de outros cronogramas.

**REQ-016.** Um tópico-pai só fica concluído se todos os descendentes estiverem concluídos. Não permitir marcar o pai concluído enquanto existirem filhos pendentes. Permitir desfazer conclusão com recálculo.

**REQ-017.** Remover tópico de um edital não o exclui do catálogo global. Excluir globalmente requer confirmação de impacto. Excluir pai abrange descendentes; preservar histórico de estudos e não deixar referências inválidas.

**REQ-018.** Ao editar um tópico compartilhado **dentro de um projeto**, criar cópia independente para esse projeto (copy-on-write), sem alterar outros projetos. A cópia herda o progresso atual e evolui independentemente.

**REQ-019.** Anotações de uma identidade de tópico global são compartilhadas entre projetos. Ao criar cópia independente, copiar anotações, imagens e vínculos com anexos; textos tornam-se independentes, arquivos físicos permanecem compartilhados.

**REQ-020.** Ao duplicar assunto, copiar também seu histórico de sessões; sessões copiadas podem ser editadas independentemente. Preservar referência à sessão de origem.

## 3. Cronogramas, Planner e atividades

**REQ-030.** Um projeto pode conter vários cronogramas. Cada cronograma possui exatamente um Planner lógico; Planner e cronograma são visões dos **mesmos registros**, nunca bases duplicadas.

**REQ-031.** Planejamento manual: usuário escolhe atividades, disciplinas, tópicos e datas. Atividades podem ter nenhum, um ou vários tópicos vinculados (ex.: simulados sem vínculo).

**REQ-032.** Visualizações: tabela e calendário (mês, semana, dia com timeline). Edição inline, ordenação drag-and-drop, persistência automática e atualização entre visões. Não implementar Kanban como requisito.

**REQ-033.** Configurar duração diária padrão e exceções por dia. Distribuir **igualmente** o tempo de estudo disponível entre assuntos/atividades programados para aquele dia; mudanças na disponibilidade recalculam durações normais. Para nova atividade criada a partir de assuntos pendentes, recalcular divisão igualitária do novo dia.

**REQ-034.** Definir horário de início diário, com alteração para datas específicas. Atividades sequenciais conforme ordenação manual; intervalo fixo configurável entre assuntos, **acrescentado** ao tempo líquido de estudo. Reordenar recalcula horários.

**REQ-035.** Ao começar atrasado, perguntar se mantém os horários planejados ou desloca os seguintes. Não alterar horários silenciosamente.

**REQ-036.** Atividades não concluídas são marcadas atrasadas e realocadas ao próximo dia **sem atividades**, inclusive fim de semana/feriado. Lotes de pendências podem se acumular no mesmo próximo dia originalmente vazio. Preservar data original, identidade, duração planejada e histórico; indicar sobrecarga, sem diminuir duração de atividades carregadas. Persistindo atraso, repetir no próximo dia vazio.

**REQ-037.** Em atividade parcialmente estudada, ao reagendar, transferir apenas tópicos pendentes; tópicos concluídos permanecem no histórico da data original.

**REQ-038.** Recorrência diária, semanal e mensal. Cada ocorrência é independente; atraso de uma ocorrência não apaga/mescla a próxima. Editar/excluir: somente esta, esta e futuras ou série inteira, com proteção do histórico.

**REQ-039.** Revisões são **manuais**; não criar revisões espaçadas automáticas.

**REQ-040.** Próxima atividade e widget seguem ordem e horários definidos pelo usuário, sem prioridade automática por atraso.

**REQ-041.** **Conclusão de atividade sempre manual.** Alcançar ou ultrapassar tempo previsto nunca conclui atividade. Exibir tempo estudado / planejado e excedente destacado (ex.: 2h30 / 2h; +30min).

**REQ-042.** Ao concluir atividade sem sessão, perguntar se registra tempo estudado ou conclui com zero tempo.

**REQ-043.** Ao concluir com tópicos pendentes, perguntar se marca todos como estudados ou conclui mantendo pendentes. Nunca marcar assuntos automaticamente sem escolha explícita.

**REQ-044.** Se mantiver tópicos pendentes, perguntar se ficam apenas no edital ou se deseja criar outra atividade para eles. Não criar automaticamente. A duração da nova atividade é calculada pela divisão igualitária do novo dia.

**REQ-045.** Atividades concluídas e progresso global de tópicos são estados distintos. Concluir uma atividade não conclui automaticamente outras atividades que contenham o mesmo tópico.

## 4. Sessões e tempo de estudo

**REQ-050.** Sessões por cronômetro **ou** cadastro manual. Toda sessão manual deve estar vinculada a uma atividade existente; nenhuma sessão manual independente.

**REQ-051.** Uma atividade pode ter múltiplas sessões, manuais ou cronometradas; acumular tempo sem teto, mesmo acima do previsto.

**REQ-052.** Cadastro manual: data local atual ou passada, duração, vínculo com atividade, questões/acertos e observações; não exigir horários de início/fim. Bloquear data futura. Permitir cadastrar em atividade já concluída sem reabri-la.

**REQ-053.** No fim da sessão, informar manualmente questões totais e acertos; erros = total − acertos; validar 0 ≤ acertos ≤ total.

**REQ-054.** Sessões finalizadas podem ser editadas integralmente (duração, disciplina/assuntos, questões, acertos e observações). Salvar substituindo valores antigos; **sem histórico de edição**. Recalcular estatísticas.

**REQ-055.** Exclusão de sessão é definitiva após confirmação, **sem lixeira**. Se a sessão original tiver cópias, oferecer preservar cópias ou excluir também derivadas, mostrando impacto.

**REQ-056.** Relatórios devem exibir separadamente: (a) horas **efetivamente estudadas**, sem dupla contagem de sessões copiadas; (b) horas **atribuídas aos assuntos**, incluindo atribuições/cópias.

**REQ-057.** Se a duração da sessão original for corrigida, atualizar métricas derivadas, inclusive horas atribuídas às cópias, **sem alterar o valor armazenado no registro individual da cópia**. Ex.: original 60→45min, cópia continua mostrando 60min no registro, mas agregados original+cópia passam 120→90min. Preservar proveniência para esse cálculo.

**REQ-058.** Sessão que atravessa meia-noite: contabilizar **toda** duração na data local de início, sem dividir por dia.

## 5. Cronômetro e ciclo de vida

**REQ-060.** Cronômetro iniciar/pausar/retomar/finalizar. Pausa manual no uso normal, sem detecção de inatividade; tempo pausado não conta.

**REQ-061.** Ao alcançar duração planejada, alertar e oferecer continuar ou finalizar; não parar automaticamente.

**REQ-062.** Ao encerrar antes do planejado, registrar tempo efetivo e perguntar se conclui a atividade ou reagenda o saldo, respeitando a conclusão manual e os assuntos pendentes.

**REQ-063.** Apenas **uma sessão de cronômetro aberta** por vez, inclusive se pausada. Bloquear início de outra até finalizar a atual.

**REQ-064.** Usar relógio monotônico para duração de trechos ativos; interface atualizada a cada segundo; checkpoints persistidos. Não usar contagem de ticks da UI como fonte de verdade.

**REQ-065.** Ao **encerrar/fechar efetivamente** o aplicativo, pausar e preservar sessão. Ao reabrir, apresentar sessão pausada com ações **Continuar** e **Finalizar**; não retomar automaticamente.

**REQ-066.** Ao alternar aplicativos ou minimizar sem fechar, cronômetro continua. No Android, também continua com tela apagada/bloqueada, respeitadas limitações do sistema.

**REQ-067.** Após desligamento/reinicialização, recuperar último tempo persistido e sessão pausada; não contar período desligado; oferecer Continuar/Finalizar.

**REQ-068.** Android: notificação persistente com tempo/assunto e controles pausar/continuar quando desbloqueado. Na tela bloqueada, exibir somente informações; controles exigem desbloqueio. Utilizar serviço em primeiro plano conforme exigências do Android.

## 6. Notas e biblioteca

**REQ-070.** Anotações por assunto, globais para a mesma identidade de tópico, com editor simples de títulos, listas, checklists, links, imagens e anexos PDF/outros documentos. Observações específicas de sessão permanecem na sessão.

**REQ-071.** Biblioteca local compartilhada, com pastas/subpastas e busca; cada arquivo físico armazenado uma única vez, podendo ser referenciado por vários assuntos/anotações.

**REQ-072.** Remover anexo de um assunto **apenas desfaz vínculo**, mantendo arquivo na biblioteca e outros vínculos.

**REQ-073.** Excluir pasta significa excluir seu conteúdo recursivamente e seus vínculos ativos, mediante confirmação do impacto; porém a exclusão inicialmente envia arquivos/pastas à **lixeira**, com possibilidade de restauração. Exclusão definitiva só por ação manual; sem prazo automático de limpeza.

**REQ-074.** Restaurar itens da lixeira deve recuperar pastas/arquivos e, quando aplicável, vínculos originais. A lixeira ocupa espaço local e **não entra em backups**.

## 7. Backup e dados locais

**REQ-080.** **Somente backups manuais**. Não implementar backup automático, agendamento, retenção automática ou lembretes de backup. Decisões antigas sobre frequência e pasta de backups automáticos foram revogadas.

**REQ-081.** Exportar arquivo único `.studybackup` com banco, configurações, projetos, cronogramas, notas e arquivos **ativos**, sem lixeira. Sem senha/criptografia por senha; validar integridade.

**REQ-082.** Restauração manual por **substituição completa**, não mesclagem. Validar arquivo, solicitar confirmação, criar cópia preventiva do estado atual, restaurar e verificar integridade; recuperar estado anterior em caso de falha.

**REQ-083.** Cada dispositivo mantém seu próprio banco. Transferência Windows ↔ Android por exportação/importação manual do backup.

## 8. Dashboard, widgets e notificações

**REQ-090.** Home com projetos e acesso ao cronograma favorito como abertura padrão. Mostrar próximo estudo e resumos de progresso.

**REQ-091.** Estatísticas: tempo por dia/semana/mês/disciplina, questões/acertos/erros/taxa, progresso do edital, conclusão de cronogramas, planejado versus realizado, evolução e produtividade; usar somente registros reais.

**REQ-092.** Widget compacto Android e solução de widget/janela compacta no Windows: exibir **somente próxima atividade pendente** do cronograma ativo, duração/horário e ações iniciar, pausar/retomar e concluir. Conclusão deve respeitar confirmações de tópicos.

**REQ-093.** Notificações de início de estudo, tempo atingido, atrasos, revisões manuais e alterações de cronograma, configuráveis individualmente e com antecedência. Não incluir notificações de backup.

## 9. Fluxos de aceitação (Given / When / Then)

**AC-01 — Compartilhamento:** dado um tópico global usado por dois projetos, quando marcado estudado em um, então ambos editais refletem progresso, mas atividades do outro não são concluídas.

**AC-02 — Edição independente:** dado tópico compartilhado, quando editado em um projeto, então cria identidade independente com progresso/notas/anexos/histórico copiados, sem mudar outro projeto.

**AC-03 — Tempo real x atribuído:** dada sessão de 60min duplicada, então total efetivo é 60min e atribuído 120min. Após corrigir origem para 45min, total efetivo é 45min e atribuído 90min, sem reescrever registro individual da cópia.

**AC-04 — Conclusão:** dado tempo planejado já alcançado, então atividade continua pendente até confirmação manual.

**AC-05 — Pendências:** dado atividade com assuntos pendentes, ao concluir, oferecer marcar todos ou preservar pendências; se preservadas, oferecer deixar no edital ou criar nova atividade, sem criação automática.

**AC-06 — Sessão manual:** data futura é rejeitada; atividade é obrigatória; sessão pode ser adicionada a atividade concluída sem reabertura.

**AC-07 — Reagendamento:** atividades atrasadas migram para próximo dia vazio sem duplicação e mantendo duração original; ocorrências recorrentes futuras continuam independentes.

**AC-08 — Timer:** alternar apps/apagar tela mantém contagem; fechar ou reiniciar recupera sessão pausada; nunca retoma automaticamente; não conta tempo desligado.

**AC-09 — Biblioteca:** remover anexo de assunto não apaga arquivo; excluir pasta envia conteúdo à lixeira e permite restaurar; backup ignora lixeira.

**AC-10 — Backup:** arquivo válido restaura por substituição; pacote corrompido não altera dados existentes; falha durante restauração permite recuperar estado anterior.

## 10. Decisões que NÃO devem ser presumidas como respondidas

- **Data da nova atividade para tópicos pendentes:** a última pergunta oferecia escolher manualmente, próximo dia livre ou ambos, mas o usuário interrompeu o questionário **sem responder**. A especificação exige oferecer criação posterior e divisão igualitária do tempo, mas não determina o seletor exato de data. Implementação conservadora: escolha manual de data; documentar como decisão técnica provisória, não como resposta do usuário.
- **Comportamento exato ao excluir definitivamente um projeto com sessões históricas:** confirmar política técnica de integridade antes de executar exclusões; não apagar silenciosamente histórico de outros projetos.
- **Detalhes de notificações e widget Windows:** validar viabilidade nas plataformas reais, sem prometer equivalência nativa.
- **Arredondamento de minutos, resolução de conflitos de agenda, formato interno do `.studybackup`:** decisões de engenharia a documentar e testar; não foram escolhas explícitas do usuário.

## 11. Critérios de engenharia recomendados (não são respostas do usuário)

- Usar SQLite/Drift com migrations versionadas, constraints, transações e chaves estáveis.
- Separar UI, regras de negócio e persistência; utilizar Riverpod para estado/DI.
- Manter `origin_session_id` e identidade de eventos para deduplicação dos tempos; definir invariantes de correção/edição de cópias com testes determinísticos.
- Persistir timer periodicamente, sabendo que relógio monotônico não atravessa reboot.
- Implementar operações de arquivos com staging, verificação de hash e recuperação de falhas para manter banco e filesystem coerentes.
- Implementar `.studybackup` como pacote versionado com manifesto, checksums e validação de caminhos, escrito de forma atômica.
- Validar acessibilidade (teclado, foco, semântica, toque), layouts Windows/Android e testes reais de ciclo de vida Android.
- Implementar por fases: fundação → projetos/catálogo → planner → sessões/timer → notas/biblioteca → estatísticas → backup → widgets/notificações → QA/release.
- Para cada fase: `flutter analyze`, `flutter test`, testes de integração pertinentes, migrações e relatório de resultados reais. Commits Conventional Commits.

## 12. Precedência

1. Esta SPEC reflete a **última escolha explícita** do usuário quando houve correção: conclusão **manual** (não automática), backup **somente manual** (sem lembretes).
2. Regras confirmadas têm precedência sobre recomendações técnicas.
3. Não transformar recomendações do assistente em requisitos confirmados.
4. Quando uma decisão estiver em aberto, adotar comportamento conservador, documentar e evitar bloquear a implementação por perguntas repetidas.
