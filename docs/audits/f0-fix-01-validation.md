# Recuperação e validação da F0

Data: 2026-11-12. Resultado: **PENDENTE**.

As restrições do ambiente continuam impedindo resolver dependências, compilar e executar o aplicativo. A formatação passou; análise e testes não chegaram a analisar/executar o código. Não há evidência suficiente para aprovar a F0, nem com ressalvas.

## Atualização da revalidação às 13h12

Esta seção atualiza o estado; as seções seguintes preservam o diagnóstico da primeira tentativa. **A resolução offline de dependências agora passou**, mas a F0 continua **PENDENTE**.

SPEC, README e auditoria original foram relidos integralmente. O estado atual já contém `pubspec.lock` e `.dart_tool/package_config.json`, gerados antes desta tentativa. Não há pasta `validation-logs/external-*` para conferir o resultado relatado da execução externa.

Foi executado, com `FLUTTER_ROOT=C:\Users\Erick\flutter` somente no processo:

```powershell
& 'C:\Users\Erick\flutter\bin\cache\dart-sdk\bin\dart.exe' --suppress-analytics pub get --offline --enforce-lockfile
```

Resultado real: **exit 0**, `Resolving dependencies... Downloading packages... Got dependencies!`. O cache agora contém os pacotes necessários; não houve remoção de dependências, atualização intencional de versões ou retirada do proxy. O lockfile existente resolve Drift 2.35.4, flutter_riverpod 3.5.0, GoRouter 17.5.0 e material_ui 1.11.0. Essa recuperação comprova resolução offline, não compilação do código nem acesso à rede.

| Verificação repetida | Resultado real atual |
| --- | --- |
| `where.exe flutter` / `where.exe dart` | SDK em `C:\Users\Erick\flutter\bin` |
| Dart direto `--version` | 3.14.0 stable |
| Flutter externo `doctor -v` / `--version` por snapshot | Acesso negado ao lockfile externo |
| Doctor pela cópia local | Relatório gerado, seis categorias com problemas; exit 0 nesta tentativa não significa ambiente saudável |
| `flutter pub get` pela cópia | Exit 1 ao iniciar Dart filho |
| Dart pub get offline com lockfile obrigatório | **Exit 0** |
| `dart format --output=none --set-exit-if-changed .` com supressão de analytics | **Exit 0**, 12 arquivos, nenhuma alteração |
| `flutter analyze`, `flutter test`, ambos builds pela cópia local | Exit 1 antes da validação, subprocesso negado |
| `flutter analyze --no-pub`, após resolução offline | Exit 1 ao iniciar `dart language-server` |
| `flutter test --no-pub` | Exit 1 ao iniciar `vswhere.exe` |
| `flutter build windows --no-pub` | Exit 1 ao iniciar `vswhere.exe` |
| `flutter build apk --debug --no-pub` | Exit 1 ao iniciar Gradle; os argumentos já reconhecem `flutter.installedNdkVersions=28.2.13676358` |
| `adb devices -l` / `emulator -list-avds` diretos | Nenhum dispositivo conectado ou AVD listado |
| `git add README.md docs/audits/f0-fix-01-validation.md` | Permissão negada em `.git/index.lock`, sem commit |

Logs novos: `validation-logs/fix01-current-*.txt` e `validation-logs/fix01-offline-*.txt`. Os logs são locais e ignorados. A rede continua com DNS funcional e proxies em `127.0.0.1:9`; o doctor continua reportando conexão recusada. Existem processos Dart/Java concorrentes agora; nenhum foi encerrado, e sua existência não demonstra que detenham o lock. O erro de permissão ao abrir o lock externo foi reproduzido independentemente.

Foi encontrado um **executável preexistente**, `C:\Users\Erick\Planner\build\windows\x64\runner\Release\study_planner.exe`, 55.808 bytes, modificado às 10h55 de 12/11/2026, junto a DLLs e data/app.so. Esse arquivo não foi produzido nem validado nesta tentativa e antecede as últimas correções; não prova build bem-sucedido do código atual. Nenhum APK foi encontrado. Não houve execução comprovada da interface, criação/reabertura de projeto ou validação Android. Os seis testes continuam sem execução nesta sessão.

O conflito de localização já corrigido na F0-FIX-02 permanece corrigido. Não houve alteração de produção ou de regras de negócio nesta revalidação; apenas atualização deste relatório e do resumo no README, além da regeneração normal dos arquivos ignorados de resolução. SPEC preservada (SHA-256 `CB0BBFDFF3E2D0FEE37CDAFF4D38AF1C3C68A744EFD101A280A40C3435B1981B`). Nenhum remoto Git configurado.

A tentativa de build pela cópia local reescreveu automaticamente `android/local.properties`; a linha flutter.sdk foi restaurada ao SDK original externo ao terminar, preservando a configuração de desenvolvimento do usuário.

Para completar: permitir criação normal de subprocessos no ambiente executor e escrita nos metadados Git/SDK; depois repetir análise, testes, builds e execução real. Não é necessário mudar regras de negócio ou remover dependências para resolver essas restrições. O script externo `scripts/validate-f0.ps1 -RunWindows` segue disponível e registra resultados quando sua execução efetivamente começa.

## Histórico da primeira tentativa

## Escopo e inspeção

SPEC, README e auditoria anterior foram lidos integralmente antes de alterações. Foram inspecionados pubspec, configuração de análise, fontes Dart, testes, configuração Gradle, manifest Android e runners/CMake Windows. Não havia Git; foi inicializado repositório local na branch `fix/f0-environment-validation`. A SPEC e as funcionalidades existentes foram preservadas. Nenhuma funcionalidade da F1 foi implementada.

## Causas e evidências

### SDK e locks

`where.exe flutter` e `where.exe dart` apontam para `C:\Users\Erick\flutter\bin` (scripts sem extensão e `.bat`). Dart executado diretamente confirmou 3.14.0 stable; os metadados do SDK informam Flutter 3.50.0 stable, revisão `ab2912035e160d9cad6306df307576da6128ebdb`.

A ACL de `bin\cache\lockfile` concede FullControl ao usuário Erick, administradores e SYSTEM. O arquivo tem tamanho zero e atributo Archive; sua existência não comprova lock abandonado. A sessão tem escrita limitada ao workspace, enquanto o SDK fica fora dele. A execução direta do snapshot oficial falha em `Cache.lock`, antes de qualquer análise do projeto:

```text
Flutter failed to open a file at "C:\Users\Erick\flutter\bin\cache\lockfile". The flutter tool cannot access the file or directory.
Please ensure that the SDK and/or project is installed in a location that has read/write permissions for the current user.
```

O `shared.bat` instalado repete `acquire_lock` quando não consegue abrir `flutter.bat.lock`, redirecionando o erro. Isso explica por que `flutter doctor -v` e `flutter --version` via PATH ficam sem saída útil. Não foi demonstrada corrupção do SDK nem concorrência de Dart/Flutter segurando o lock: a primeira inspeção não encontrou tais processos. Havia processos cmd; não foram encerrados indiscriminadamente. A inspeção de suas linhas de comando por CIM foi negada pelo ambiente.

### Tentativa conservadora de recuperação

Foi copiado o SDK para `.tooling/flutter`, dentro do workspace, sem alterar o original, ACLs ou configurações globais. A cópia excluiu caches de downloads, SDK antigo e diretórios de exemplos/desenvolvimento desnecessários; os metadados Git foram copiados depois. Essa cópia é ferramenta temporária ignorada pelo Git, não distribuição validada do SDK.

A cópia local conseguiu criar/abrir o lock, mas revelou bloqueio independente ao iniciar subprocessos. Uma prova mínima em Dart, sem dependências do projeto, tentou `Process.run` com o caminho absoluto do Git:

```text
child error: ProcessException: Acesso negado (at ../../runtime/bin/process_win.cc:758)
  Command: "C:\Program Files\Git\cmd\git.exe" --version
```

O mesmo Git funciona quando chamado diretamente pelo PowerShell. O doctor da cópia local falhou ao iniciar `where flutter`, `ver`, `where adb`, `vswhere.exe` e `adb.exe`. Portanto, mover o SDK resolve somente o acesso ao lock, não a restrição de subprocessos desta sessão. Não é um defeito comprovado do código Flutter da aplicação.

O doctor foi repetido com `--no-version-check --suppress-analytics`, para evitar consulta de atualização do próprio SDK e escrita de arquivo de sessão fora do workspace, sem suprimir diagnósticos, lints ou testes. LOCALAPPDATA, JAVA_HOME e PUB_CACHE foram definidos apenas nos processos de diagnóstico. Sem essas opções, uma falha secundária ao escrever `AppData\Roaming\.dart-tool\dart-flutter-telemetry-session.json` encobre o erro original. Nenhum mecanismo de lock ou controle de segurança foi desabilitado.

### Rede, DNS, proxy e certificados

DNS respondeu A `34.36.0.14` e AAAA `2600:1901:0:382a::` para pub.dev. Não há evidência de falha de resolução de nomes.

HTTP_PROXY, HTTPS_PROXY, ALL_PROXY e proxies Git desta sessão apontam para `127.0.0.1:9`; NO_PROXY inclui apenas localhost/loopback. As tentativas HTTP de Dart e Python foram recusadas. A prova Dart reportou SocketException/errno 1225 em endereço loopback. O doctor confirmou recusa de conexão para pub.dev, storage.googleapis.com, maven.google.com e github.com.

O PowerShell/Schannel também falhou com:

```text
System.Net.WebException: A conexão subjacente estava fechada: Erro inesperado em um recebimento.
System.ComponentModel.Win32Exception: Credenciais não disponíveis no pacote de segurança
```

Não houve handshake bem-sucedido que permita atribuir o problema a um certificado de pub.dev. Não foram instalados certificados, ignorada validação TLS, removidos proxies ou alterada a política de rede restrita. A resolução direta com Dart, FLUTTER_ROOT na cópia e PUB_CACHE local terminou com a mensagem completa do resolvedor:

```text
Got socket error trying to find package path_provider at https://pub.dev.
```

O nome do pacote varia conforme a primeira consulta. Nenhum conflito de versões foi demonstrado; não foi possível validar compatibilidade nem gerar pubspec.lock. O cache externo existente não contém Drift, Riverpod ou GoRouter, portanto não há conjunto offline suficiente para executar a aplicação.

## Comandos e resultados reais

Os comandos Flutter foram tentados pelo PATH e/ou pelo snapshot oficial da cópia local. A chamada direta usa `dart.exe .tooling/flutter/bin/cache/flutter_tools.snapshot --no-version-check --suppress-analytics <comando>`; não equivale a aprovação das verificações.

| Comando/verificação | Resultado |
| --- | --- |
| `where.exe flutter`, `where.exe dart` | Caminhos identificados no SDK externo |
| `flutter doctor -v` pelo PATH | Sem saída útil, abertura do lock bloqueada |
| doctor via snapshot local | Exit 1; seis categorias com problemas, incluindo subprocessos e rede |
| `flutter --version` | Tentado; bloqueado por lock/subprocesso ou escrita de sessão; versão Flutter obtida somente dos metadados |
| `dart --version` | Binário direto: Dart 3.14.0 stable Windows x64 |
| `flutter pub get` | Exit 1; Flutter não consegue iniciar o Dart filho |
| `dart --suppress-analytics pub get` direto | Exit 1; socket error em pub.dev |
| `dart --suppress-analytics format --output=none --set-exit-if-changed .` | **Exit 0, 12 arquivos, zero mudanças**; aviso de flutter_lints ainda não resolvido |
| `flutter analyze` | Exit 1 antes da análise, ao tentar resolver pacotes via subprocesso |
| `flutter test` | Exit 1 antes dos testes, mesmo bloqueio |
| `flutter build windows` | Exit 1 antes da compilação, mesmo bloqueio |
| `flutter build apk --debug` | Exit 1 antes da compilação, mesmo bloqueio |
| `adb.exe devices -l` diretamente | Exit 0; lista vazia |
| `emulator.exe -list-avds` diretamente | Exit 0; sem saída/AVD listado |
| JDK direto | Java 25 LTS executou `-version` |
| `git check-ignore` | Confirmou exclusão de SDK local, cache, .env, banco, build e chave Android |

Mensagem do `flutter pub get` na cópia local:

```text
Flutter failed to run "C:\Users\Erick\Planner\.tooling\flutter\bin\cache\dart-sdk\bin\dart pub --suppress-analytics get --example --directory .". The flutter tool cannot access the file or directory.
Please ensure that the SDK and/or project is installed in a location that has read/write permissions for the current user.
```

Logs integrais das últimas tentativas estão localmente em `validation-logs/doctor.txt`, `pub-get.txt`, `analyze.txt`, `test.txt`, `build-windows.txt` e `build-apk---debug.txt`. São arquivos de diagnóstico ignorados, não artefatos de build.

## Android, Windows e execução

O Android SDK externo contém cmdline-tools/latest, platform-tools, plataformas, build-tools, emulador, system-images e um arquivo android-sdk-license. Isso não comprova que todas as licenças/componentes exigidos estão válidos; o doctor não conseguiu verificá-los. Não foram aceitas licenças em nome do usuário nem modificados SDK/JDK.

O doctor não conseguiu consultar o Visual Studio por subprocesso, portanto a presença de todos os componentes C++/CMake não foi comprovada. Não se deve afirmar que faltam apenas com base nessa falha.

**Nenhum APK ou executável foi produzido. Não existem caminhos de artefatos a informar.** Sem build executável, não foi possível abrir o app Windows, navegar, criar projeto, fechar/reabrir ou comprovar persistência pelo app instalado. Sem dispositivo conectado/AVD listado, não houve execução Android. Os testes SQLite/Drift, rollback, schema, Riverpod, rotas e responsividade existentes permanecem não executados.

## Alterações e Git

- `.gitignore`: exclui SDK/cache local, ambientes, SQLite e auxiliares, backups, chaves e configurações de assinatura, além de artefatos Flutter já ignorados.
- `README.md`: referencia este diagnóstico atualizado.
- Este relatório: registra causas, tentativas, resultados e critérios pendentes.
- `.git`: repositório local criado em `fix/f0-environment-validation`, sem remoto. A tentativa de registrar o estado foi bloqueada; nenhum commit foi produzido.
- `.tooling` e `validation-logs`: apenas ferramentas/provas locais ignoradas.

O Git inicialmente recusou a propriedade do diretório (administradores versus usuário da sessão). Os comandos usam `git -c safe.directory=C:/Users/Erick/Planner ...`, confiando somente neste workspace explicitamente autorizado, sem alterar safe.directory global. Foi usada a identidade Git já configurada. Nenhum arquivo de ambiente, banco, chave, SDK copiado ou build deve entrar no commit.

Após a inicialização, `git add` recebeu `fatal: Unable to create 'C:/Users/Erick/Planner/.git/index.lock': Permission denied`. A sessão permite somente leitura de `.git`; por isso não foi possível preparar o índice nem gerar o commit Conventional Commits. Não foram alteradas permissões nem usado outro diretório Git para contornar a restrição. Quando houver escrita autorizada nos metadados, registrar os arquivos do projeto com a mensagem `chore(f0): record foundation and environment validation blockers`. Conferências de diff em índice vazio não validam o conteúdo de um commit.

Não foram feitas mudanças especulativas no código de produção ou nas dependências sem conseguir executar análise e testes. Não houve remoção de cache, exclusão de lock, alteração da SPEC ou redesenho da interface.

## Estado final e retomada

**F0 PENDENTE.** Correção parcial do problema de localização do SDK demonstrada; restrições de subprocessos e rede permanecem bloqueantes. Não há testes aprovados, análise limpa, builds ou inicialização real comprovados.

Para retomar, executar no ambiente de desenvolvimento com SDK gravável, criação normal de subprocessos e acesso autorizado a pub.dev/storage/Maven. Essa sessão não pode ampliar suas próprias permissões ou retirar o proxy de bloqueio. Então: doctor, pub get, formatação, analyze, test, ambos builds, execução Windows com reabertura/persistência e execução Android em dispositivo/emulador. Versionar pubspec.lock somente após resolução real. A F1 continua fora do escopo.
