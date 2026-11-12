# Validação da fundação F0

Data: 2026-11-12. **Estado: pendente de validação. Não aprovada integralmente.**

## Implementação

Adicionados `pubspec.yaml`, análise estática configurada, `lib/main.dart`, composição em `lib/app`, roteador com oito destinos, tema centralizado, banco em `lib/core/database`, projeto mínimo em `features/projects`, dashboard em `features/dashboard`, testes em `test`, runners em `android` e `windows`, README e documentação em `docs`. Os dois documentos de entrada foram preservados. Não havia Git; não há branch nem commit gerado.

Arquitetura feature-first com Riverpod e GoRouter; SQLite/Drift nativo, schema v1 e upgrade que falha sem destruição. Dashboard vazio e projetos reais; módulos futuros identificados explicitamente. Sem métricas fictícias. Dependências e decisões descritas em architecture.md/database.md.

## Execuções reais

| Verificação | Resultado |
| --- | --- |
| Leitura integral SPEC/guia e inventário inicial | Concluída; somente dois documentos existentes |
| SDK | Metadados instalados: Flutter 3.50.0 stable / Dart 3.14.0 |
| flutter --version / doctor | Não concluídos pela via .bat; ferramenta direta revelou restrições de acesso |
| flutter create Windows/Android | Bloqueado; launchers preparados dos templates do SDK, não compilados |
| flutter pub get | Bloqueado no lockfile do SDK |
| Dart pub get direto com FLUTTER_ROOT | Falhou: socket error buscando flutter_riverpod em https://pub.dev |
| dart --suppress-analytics format . | Executado, exit 0; 12 arquivos Dart formatados. Aviso: flutter_lints indisponível sem pub get |
| flutter analyze | Tentado via snapshot oficial, bloqueado antes da análise |
| flutter test | Tentado via snapshot oficial, bloqueado antes dos testes |
| flutter build windows | Tentado via snapshot oficial, bloqueado antes do build |
| flutter build apk --debug | Tentado via snapshot oficial, bloqueado antes do build |

Erro comum: `Flutter failed to open a file at "C:\Users\Erick\flutter\bin\cache\lockfile". The flutter tool cannot access the file or directory.` O ambiente só permite escrita no workspace; o SDK é externo. A detecção inicial do Android Studio também falhou ao executar seu Java. Para isolar a causa, os comandos via snapshot foram tentados com LOCALAPPDATA apontando ao workspace e JAVA_HOME ao JDK 25 instalado, apenas no processo, sem alterar configurações globais. O bloqueio de escrita permaneceu. A execução direta do Dart também reportou escrita negada de arquivo de sessão de analytics; a formatação final usou supressão de analytics no comando.

## Testes implementados, ainda não executados

SQLite: criação/leitura, validação/constraint, reabertura persistente, user_version e rollback transacional. Widgets: bootstrap, dashboard vazio, oito rotas, tamanhos mobile/desktop, drawer, criação de projeto refletida no dashboard e recuperação por retry após erro de inicialização.

## Critérios de aceite

Código preparado para Riverpod, navegação, dashboard, tema e banco local. **Funcionalidade do SQLite, compatibilidade dos pacotes, análise sem problemas, testes passando, inicialização real nas plataformas e builds permanecem não verificados.** Nenhum executável/APK foi produzido. Sem capturas de tela ou aprovação visual. Não há pubspec.lock devido à resolução bloqueada.

## Próximas ações

Disponibilizar SDK com escrita e acesso ao registro de pacotes no ambiente de desenvolvimento. Executar os comandos do README, corrigir eventuais incompatibilidades, versionar lockfile e validar abertura/criação/reabertura em Windows e Android reais. Confirmar atualização preservando o banco e identidade de instalação. Só então encerrar F0 e iniciar F1. Sem remoção de banco ou enfraquecimento de permissões para contornar os bloqueios.
