# Arquitetura da fundação

F0 implementada em código, **pendente de validação**. Não há execução ou build aprovado neste ambiente.

O repositório original continha somente `STUDY_PLANNER_SPEC.md` e `CODEX_IMPLEMENTATION_GUIDE.md`, lidos integralmente antes das mudanças. Não existiam Git, dependências ou implementação anterior. A SPEC prevalece sobre o guia: não se presumem decisões sobre datas de pendências, metas ou exclusões históricas.

`lib/app` compõe MaterialApp, GoRouter e tokens. `core/database` abre o arquivo e controla schema/migrações. `features/projects` separa persistência, providers e apresentação. `features/dashboard` apresenta dados reais do repositório. Não foram criadas pastas vazias para fases futuras.

F1.1 adiciona `features/catalog` em três camadas: domínio imutável (`Catalog`, `Discipline`, `Subject` e traversal iterativo), repositório transacional e apresentação Riverpod. O catálogo é global e independente de projetos. A rota `/disciplines` usa a mesma shell responsiva da aplicação; a tela não inventa conteúdo e começa vazia.

Riverpod faz injeção e carregamento assíncrono. A abertura testa uma consulta antes de liberar a interface; erros oferecem retry explícito, sem apagar dados. O banco usa isolate nativo em produção e executor injetável nos testes. Widgets cuidam de formulário, loading e feedback; validação de nome e SQL ficam no repositório. Escritas futuras envolvendo múltiplas entidades devem usar `database.transaction`.

GoRouter mantém oito rotas sob shell compartilhado. A partir de 840 pixels há sidebar; abaixo disso há drawer, SafeArea e conteúdo rolável. Projetos e dashboard têm fluxo mínimo real; demais rotas dizem explicitamente que ainda não foram implementadas. A ação criar leva ao formulário de projeto vazio, sem criar edital ou cronograma prematuramente.

Dependências: Flutter/Material 3 e localizações oficiais; Riverpod para DI/estado; GoRouter para navegação declarativa; Drift para SQLite e migrações; path/path_provider para armazenamento persistente. Não há serviços remotos, analytics, autenticação, sincronização ou backup implementado. O acesso à rede é necessário para preparar ferramentas/pacotes, não para o aplicativo em execução.

Os launchers Windows/Android foram preparados a partir dos templates do SDK instalado (Flutter 3.50.0 stable, Dart 3.14.0). Android usa Gradle 9.5.0, AGP 9.3.1 e Kotlin 2.4.20, valores do próprio SDK. A compatibilidade ainda precisa de build. Mantenha applicationId e identidade do runner em atualizações para preservar o diretório de dados.

Consulte [validação](audits/f0-foundation-validation.md) e [execução](../README.md). Não há lockfile de pacotes: o resolvedor ficou bloqueado. A compatibilidade final das versões declaradas não foi verificada.

### Seed demonstrativo de desenvolvimento

`DemoDataSeed` usa o repositório real em uma transação, com IDs reservados no
namespace `demo-v1-` e exclusão lógica isolada. Os controles são exibidos apenas
em builds debug.
F1.2 adiciona o módulo `features/syllabus`. Cada projeto recebe um único edital
em `vertical_syllabi`; os vínculos de disciplinas e assuntos são locais ao
edital e apontam para identidades globais do catálogo. `SyllabusRepository`
mantém seleção, progresso e copy-on-write em transações. O progresso fica em
`topic_progress`, portanto a mesma identidade global reflete o estado em todos
os projetos; cópias recebem identidade própria e herdam o estado inicial.
