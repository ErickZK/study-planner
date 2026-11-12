# Roteiro de implementação

- F0: código de fundação preparado; resolver dependências, analisar, executar testes e builds antes de aprovar.
- F1.1: catálogo global de disciplinas e assuntos implementado com árvore recursiva, CRUD, busca, movimento, ordenação, duplicação, exclusão lógica e migração v2. Editais, progresso compartilhado e copy-on-write entre projetos permanecem para a integração posterior.
- F1.2: projetos completos e editais, seleção de tópicos e regras de identidade/cópia.
- F2: cronogramas e Planner sobre atividades comuns, divisão igualitária, recorrência e reagendamento.
- F3: sessões, proveniência, tempo efetivo/atribuído e timer com ciclo de vida real.
- F4: notas, arquivos deduplicados, vínculos e lixeira.
- F5: estatísticas reais e agregados derivados.
- F6: backup manual validado, substituição e rollback.
- F7: widgets/notificações conforme viabilidade de cada plataforma.
- F8: QA, acessibilidade e release.

Não iniciar F1 até fechar os bloqueios documentados da F0. O único avanço funcional mínimo foi criação/listagem de projetos por nome para verificar persistência; não equivale ao CRUD completo da F1.

O catálogo F1.1 também possui um dataset demonstrativo determinístico disponível
somente em builds debug para validação local da árvore.
F1.2 implementa edital verticalizado por projeto, seleção parcial de assuntos,
progresso global compartilhado, cálculo por folhas selecionadas e copy-on-write.
