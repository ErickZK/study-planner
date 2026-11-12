# Study Planner

Aplicativo Flutter offline para Windows e Android. Fundação F0 em código, pendente de validação. A especificação funcional é [STUDY_PLANNER_SPEC.md](STUDY_PLANNER_SPEC.md).

Use Flutter stable 3.50.0/Dart 3.14.0 (SDK instalado usado como referência), Visual Studio com desenvolvimento desktop C++/CMake para Windows e Android SDK/JDK compatível com Gradle 9.5 para Android. As dependências de compilação precisam estar disponíveis; o aplicativo utiliza somente dados locais.

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter run -d windows
flutter devices
flutter run -d <id-android>
flutter build windows
flutter build apk --debug
```

`pub get` deve gerar os registradores nativos e o lockfile. Versione `pubspec.lock` depois de resolver e validar versões. Os testes injetam SQLite em memória/arquivo temporário e não dependem da instalação do app.

Documentação: [arquitetura](docs/architecture.md), [banco](docs/database.md), [design](docs/design-system.md), [roteiro](docs/implementation-roadmap.md) e [auditoria F0](docs/audits/f0-foundation-validation.md).

O diagnóstico atualizado está em [F0-FIX-01](docs/audits/f0-fix-01-validation.md): lock do SDK externo, subprocessos negados e rede recusada pelo proxy do ambiente. A F0 permanece pendente. A cópia temporária de ferramentas em `.tooling` não faz parte do aplicativo nem do repositório versionado.

Na revalidação, a resolução offline com o lockfile existente passou. Análise, testes, builds e execução do código atual continuam pendentes por restrições de subprocessos. Consulte a atualização no início do relatório; os registros antigos descrevem o estado histórico.
