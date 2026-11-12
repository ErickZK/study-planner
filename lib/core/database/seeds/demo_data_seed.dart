import 'package:study_planner/core/database/app_database.dart';
import 'package:study_planner/features/catalog/data/catalog_repository.dart';

const demoDatasetVersion = 'v1';
const demoIdPrefix = 'demo-$demoDatasetVersion-';

class DemoSeedStats {
  const DemoSeedStats({
    required this.disciplines,
    required this.subjects,
    this.version = demoDatasetVersion,
  });

  final int disciplines;
  final int subjects;
  final String version;
}

class DemoSubjectDefinition {
  const DemoSubjectDefinition(this.name, [this.children = const []]);

  final String name;
  final List<DemoSubjectDefinition> children;
}

class DemoDisciplineDefinition {
  const DemoDisciplineDefinition(this.name, this.subjects);

  final String name;
  final List<DemoSubjectDefinition> subjects;
}

const demoDisciplines = <DemoDisciplineDefinition>[
  DemoDisciplineDefinition('Língua Portuguesa', [
    DemoSubjectDefinition('Interpretação de textos', [
      DemoSubjectDefinition('Compreensão textual'),
      DemoSubjectDefinition('Inferência de informações'),
      DemoSubjectDefinition('Tipologia textual'),
      DemoSubjectDefinition('Coesão e coerência'),
    ]),
    DemoSubjectDefinition('Gramática', [
      DemoSubjectDefinition('Classes de palavras', [
        DemoSubjectDefinition('Substantivos'),
        DemoSubjectDefinition('Adjetivos'),
        DemoSubjectDefinition('Verbos'),
        DemoSubjectDefinition('Pronomes'),
      ]),
      DemoSubjectDefinition('Sintaxe', [
        DemoSubjectDefinition('Termos da oração'),
        DemoSubjectDefinition('Concordância', [
          DemoSubjectDefinition('Concordância verbal', [
            DemoSubjectDefinition('Casos especiais de concordância'),
          ]),
          DemoSubjectDefinition('Concordância nominal'),
        ]),
        DemoSubjectDefinition('Regência verbal e nominal'),
        DemoSubjectDefinition('Crase'),
      ]),
    ]),
    DemoSubjectDefinition('Ortografia'),
    DemoSubjectDefinition('Pontuação'),
    DemoSubjectDefinition('Redação oficial'),
  ]),
  DemoDisciplineDefinition('Direito Constitucional', [
    DemoSubjectDefinition('Princípios fundamentais', [
      DemoSubjectDefinition('Fundamentos da República'),
      DemoSubjectDefinition('Objetivos fundamentais'),
    ]),
    DemoSubjectDefinition('Direitos e garantias fundamentais', [
      DemoSubjectDefinition('Direitos individuais e coletivos'),
      DemoSubjectDefinition('Direitos sociais'),
      DemoSubjectDefinition('Nacionalidade'),
      DemoSubjectDefinition('Direitos políticos'),
    ]),
    DemoSubjectDefinition('Organização do Estado', [
      DemoSubjectDefinition('União'),
      DemoSubjectDefinition('Estados'),
      DemoSubjectDefinition('Municípios'),
    ]),
    DemoSubjectDefinition('Administração pública', [
      DemoSubjectDefinition('Princípios constitucionais'),
      DemoSubjectDefinition('Servidores públicos'),
    ]),
    DemoSubjectDefinition('Poder Legislativo'),
    DemoSubjectDefinition('Poder Executivo'),
    DemoSubjectDefinition('Poder Judiciário'),
  ]),
  DemoDisciplineDefinition('Direito Administrativo', [
    DemoSubjectDefinition('Princípios da administração pública'),
    DemoSubjectDefinition('Atos administrativos', [
      DemoSubjectDefinition('Conceito e requisitos'),
      DemoSubjectDefinition('Atributos'),
      DemoSubjectDefinition('Classificação'),
      DemoSubjectDefinition('Anulação e revogação'),
    ]),
    DemoSubjectDefinition('Poderes administrativos', [
      DemoSubjectDefinition('Poder hierárquico'),
      DemoSubjectDefinition('Poder disciplinar'),
      DemoSubjectDefinition('Poder regulamentar'),
      DemoSubjectDefinition('Poder de polícia'),
    ]),
    DemoSubjectDefinition('Agentes públicos'),
    DemoSubjectDefinition('Responsabilidade civil do Estado'),
    DemoSubjectDefinition('Licitações e contratos'),
    DemoSubjectDefinition('Improbidade administrativa'),
  ]),
  DemoDisciplineDefinition('Raciocínio Lógico', [
    DemoSubjectDefinition('Lógica proposicional', [
      DemoSubjectDefinition('Proposições'),
      DemoSubjectDefinition('Conectivos lógicos'),
      DemoSubjectDefinition('Tabelas-verdade'),
      DemoSubjectDefinition('Equivalências lógicas'),
    ]),
    DemoSubjectDefinition('Teoria dos conjuntos'),
    DemoSubjectDefinition('Porcentagem'),
    DemoSubjectDefinition('Análise combinatória'),
    DemoSubjectDefinition('Probabilidade'),
    DemoSubjectDefinition('Sequências lógicas'),
  ]),
  DemoDisciplineDefinition('Informática', [
    DemoSubjectDefinition('Sistemas operacionais', [
      DemoSubjectDefinition('Windows'),
      DemoSubjectDefinition('Gerenciamento de arquivos'),
    ]),
    DemoSubjectDefinition('Microsoft Word'),
    DemoSubjectDefinition('Microsoft Excel', [
      DemoSubjectDefinition('Fórmulas'),
      DemoSubjectDefinition('Funções'),
      DemoSubjectDefinition('Gráficos'),
    ]),
    DemoSubjectDefinition('Redes de computadores'),
    DemoSubjectDefinition('Internet e navegadores'),
    DemoSubjectDefinition('Segurança da informação', [
      DemoSubjectDefinition('Malware'),
      DemoSubjectDefinition('Phishing'),
      DemoSubjectDefinition('Criptografia'),
      DemoSubjectDefinition('Backup'),
    ]),
  ]),
  DemoDisciplineDefinition('Matemática', [
    DemoSubjectDefinition('Operações fundamentais'),
    DemoSubjectDefinition('Frações'),
    DemoSubjectDefinition('Razão e proporção'),
    DemoSubjectDefinition('Regra de três'),
    DemoSubjectDefinition('Porcentagem'),
    DemoSubjectDefinition('Equações', [
      DemoSubjectDefinition('Primeiro grau'),
      DemoSubjectDefinition('Segundo grau'),
    ]),
    DemoSubjectDefinition('Matemática financeira', [
      DemoSubjectDefinition('Juros simples'),
      DemoSubjectDefinition('Juros compostos'),
    ]),
  ]),
];

int _countSubjects(Iterable<DemoSubjectDefinition> definitions) =>
    definitions.fold(0, (total, item) => total + 1 + _countSubjects(item.children));

final demoExpectedStats = DemoSeedStats(
  disciplines: demoDisciplines.length,
  subjects: demoDisciplines.fold(
    0,
    (total, discipline) => total + _countSubjects(discipline.subjects),
  ),
);

class DemoDataSeed {
  DemoDataSeed(this.database);

  final AppDatabase database;

  Future<DemoSeedStats> load({int? failAfter}) => database.transaction(() async {
        final repository = CatalogRepository(database);
        _insertedCounter = 0;
        for (var disciplineIndex = 0;
            disciplineIndex < demoDisciplines.length;
            disciplineIndex++) {
          final discipline = demoDisciplines[disciplineIndex];
          await repository.insertDisciplineWithId(
            _disciplineId(disciplineIndex),
            discipline.name,
            position: disciplineIndex,
          );
          _insertedCounter++;
          _throwIfRequested(failAfter);
          for (var subjectIndex = 0;
              subjectIndex < discipline.subjects.length;
              subjectIndex++) {
            await _insertSubjectTree(
              repository,
              disciplineIndex,
              discipline.subjects[subjectIndex],
              null,
              [subjectIndex],
              failAfter,
            );
          }
        }
        return demoExpectedStats;
      });

  Future<DemoSeedStats> remove() async {
    final repository = CatalogRepository(database);
    final result = await repository.removeDemoRecords(demoIdPrefix);
    return DemoSeedStats(
      disciplines: result.disciplines,
      subjects: result.subjects,
    );
  }

  Future<int> _insertSubjectTree(
    CatalogRepository repository,
    int disciplineIndex,
    DemoSubjectDefinition definition,
    String? parentId,
    List<int> path,
    int? failAfter,
  ) async {
    final id = _subjectId(disciplineIndex, path);
    await repository.insertSubjectWithId(
      id,
      _disciplineId(disciplineIndex),
      parentId,
      definition.name,
      position: path.last,
    );
    _insertedCounter++;
    _throwIfRequested(failAfter);
    var inserted = 1;
    for (var childIndex = 0; childIndex < definition.children.length; childIndex++) {
      inserted += await _insertSubjectTree(
        repository,
        disciplineIndex,
        definition.children[childIndex],
        id,
        [...path, childIndex],
        failAfter,
      );
    }
    return inserted;
  }

  int _insertedCounter = 0;

  void _throwIfRequested(int? failAfter) {
    if (failAfter != null && _insertedCounter >= failAfter) {
      throw StateError('Falha solicitada durante o seed demonstrativo.');
    }
  }

  String _disciplineId(int index) => '$demoIdPrefix' 'discipline-${index + 1}';

  String _subjectId(int disciplineIndex, List<int> path) =>
      '$demoIdPrefix' 'subject-${disciplineIndex + 1}-${path.map((item) => item + 1).join('-')}';
}
