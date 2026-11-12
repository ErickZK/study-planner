# Banco local

`AppDatabase` usa Drift `GeneratedDatabase` com SQL explícito, sem geração de código nesta fundação. O schema v1 contém somente `projects`: ID inteiro autoincremental estável neste banco independente, nome não vazio limitado a 120 caracteres e timestamp UTC em milissegundos. O fluxo mínimo permite criar/listar projetos. Não há exclusão, edição ou wizard.

O executor nativo SQLite é aberto em background com `NativeDatabase.createInBackground`. `path_provider.getApplicationSupportDirectory` resolve o diretório por plataforma: suporte da aplicação no Windows, diretório privado persistente no Android. O arquivo é `study_planner.sqlite`; nunca usa cache temporário, assets ou pasta de instalação. Atualizações com a mesma identidade preservam esse arquivo. Desinstalação/limpeza de dados pode removê-lo. O backup do sistema Android foi desabilitado; o backup manual da SPEC pertence à F6.

`schemaVersion = 1`; Drift gerencia `PRAGMA user_version`. `onCreate` cria a tabela; `beforeOpen` habilita chaves estrangeiras. Não existem FKs nesta versão mínima. `onUpgrade` falha explicitamente enquanto não houver migração conhecida, sem drop/recriação. Cada alteração deve incrementar a versão, adicionar caminhos de upgrade transacionais e testes de fixtures anteriores, preservando dados. Nunca substituir o arquivo para resolver erro de migração. Como o SQL é explícito, `allTables/allSchemaEntities` ficam vazios: não usar `createAll` nem inferir notificações reativas de tabelas; o provider é invalidado após a escrita.

Testes adicionados: criação/consulta, constraint, validação, persistência em arquivo após reabertura, versão e rollback. Ainda não executados por bloqueio de ambiente.

Antes da F1 foram revisados REQ-010–020, 030–045, 050–058 e 070–074. Não foram cristalizados modelos de cronograma, tópicos ou sessões. O próximo schema deverá preservar: edital único por projeto; tópicos globais recursivos com prevenção de ciclos; progresso pela identidade global e copy-on-write independente; atividades por cronograma e Planner sobre os mesmos registros; proveniência de cópias de sessões e agregação sem dupla contagem; arquivos físicos únicos e vínculos separados. A escolha de IDs para essas entidades deve considerar backup e proveniência, sem tratar o ID local de projeto como identificador entre dispositivos.

Referência técnica consultada: [Drift nativo](https://drift.simonbinder.eu/platforms/vm/), que documenta SQLite nativo e execução em isolate; a partir de Drift 2.32 não é necessário `sqlite3_flutter_libs`.
