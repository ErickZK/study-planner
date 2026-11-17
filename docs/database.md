# Banco local

`AppDatabase` usa Drift `GeneratedDatabase` com SQL explícito, sem geração de código nesta fundação. O schema v1 contém somente `projects`: ID inteiro autoincremental estável neste banco independente, nome não vazio limitado a 120 caracteres e timestamp UTC em milissegundos. O fluxo mínimo permite criar/listar projetos. Não há exclusão, edição ou wizard.

O executor nativo SQLite é aberto em background com `NativeDatabase.createInBackground`. `path_provider.getApplicationSupportDirectory` resolve o diretório por plataforma: suporte da aplicação no Windows, diretório privado persistente no Android. O arquivo é `study_planner.sqlite`; nunca usa cache temporário, assets ou pasta de instalação. Atualizações com a mesma identidade preservam esse arquivo. Desinstalação/limpeza de dados pode removê-lo. O backup do sistema Android foi desabilitado; o backup manual da SPEC pertence à F6.

`schemaVersion = 2`; Drift gerencia `PRAGMA user_version`. A migração v1→v2 cria `disciplines` e `subjects` sem tocar em `projects`. IDs de catálogo são strings UUID-like gerados pelo SQLite, estáveis entre edições e duplicações. `subjects` tem FK composta `(parent_id, discipline_id)`, impedindo pai de outra disciplina; trigger recursiva rejeita ciclos. Índices cobrem ordem e carregamento da árvore. `deleted_at` faz exclusão lógica, preservando identidades para futuras referências históricas. Duplicação, movimento e exclusão usam transações; falhas fazem rollback.

No `onCreate`, as três estruturas são criadas para bancos novos. No `onUpgrade`, o caminho v1→v2 é explícito e não destrutivo; versões desconhecidas falham sem recriar o arquivo. `beforeOpen` habilita chaves estrangeiras. Como o SQL é explícito, `allTables/allSchemaEntities` ficam vazios: o provider é invalidado após a escrita, em vez de depender de streams geradas.

Testes adicionados: criação/consulta, constraint, persistência, migração v1, árvore profunda, ciclo, movimento, reordenação, duplicação, exclusão lógica, rollback e reabertura. Uma verificação SQLite direta executou 15 checks e passou; a suíte Flutter completa permanece dependente do ambiente.

Antes da F1 foram revisados REQ-010–020, 030–045, 050–058 e 070–074. Não foram cristalizados modelos de cronograma, tópicos ou sessões. O próximo schema deverá preservar: edital único por projeto; tópicos globais recursivos com prevenção de ciclos; progresso pela identidade global e copy-on-write independente; atividades por cronograma e Planner sobre os mesmos registros; proveniência de cópias de sessões e agregação sem dupla contagem; arquivos físicos únicos e vínculos separados. A escolha de IDs para essas entidades deve considerar backup e proveniência, sem tratar o ID local de projeto como identificador entre dispositivos.

Referência técnica consultada: [Drift nativo](https://drift.simonbinder.eu/platforms/vm/), que documenta SQLite nativo e execução em isolate; a partir de Drift 2.32 não é necessário `sqlite3_flutter_libs`.

### Seed demonstrativo

O dataset não exige migração. Seus IDs estáveis usam o prefixo `demo-v1-` e são
inseridos em transação pelo repositório; a remoção aplica exclusão lógica apenas
a esse namespace e reativa os mesmos IDs em execuções posteriores.
O schema v3 adiciona `vertical_syllabi`, `syllabus_disciplines`,
`syllabus_topics` e `topic_progress`. A migração v2→v3 é incremental e não
remove projetos, disciplinas, assuntos ou registros demonstrativos. A seleção
é removida apenas do edital atual. Copy-on-write usa IDs `copy-*` na tabela de
vínculos, preservando a identidade global original e seu progresso.
