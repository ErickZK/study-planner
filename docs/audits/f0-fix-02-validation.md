# Correção da localização e validação dos builds

Data: 2026-11-12. Estado final da F0: **PENDENTE**.

## Causas e correções

### Localização Windows

Após a migração existente para `material_ui` 1.11.0, `lib/app/app.dart` importava tanto esse pacote quanto `flutter_localizations` sem prefixo. Ambos exportam `GlobalMaterialLocalizations`, deixando ambígua a referência aos delegates.

Foi removido somente o import redundante de `flutter_localizations` em `app.dart`. `GlobalMaterialLocalizations.delegates` agora resolve para a API de `material_ui`, correspondente ao `MaterialApp` e aos widgets já utilizados. Inspeção do pacote instalado confirmou que a lista inclui os delegates Cupertino, Material e Widgets. Locale e supportedLocales permanecem `Locale('pt', 'BR')`. Não houve substituição global de imports, atualização de dependências ou alteração no pubspec/lockfile.

A busca em `lib` e `test` não encontrou outro arquivo importando simultaneamente as duas bibliotecas. Os imports `material_ui` existentes foram preservados. Em `test/app_test.dart`, os testes responsivos existentes agora verificam também o locale efetivo e `MaterialLocalizations.of(context).cancelButtonLabel == 'Cancelar'`. São os mesmos seis testes (três de widgets e três de banco), sem remoção de cobertura.

### Android NDK

`android/app/build.gradle.kts` usa `ndkVersion = flutter.ndkVersion`. O SDK instalado define `28.2.13676358` em `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`. É a versão padrão exigida pela configuração atual, portanto não foi reduzida ou substituída.

Na inspeção desta sessão, a versão **já estava presente** no Android SDK indicado por `android/local.properties`:

```text
C:\Users\Erick\AppData\Local\Android\Sdk\ndk\28.2.13676358
source.properties: Pkg.Revision = 28.2.13676358
package.xml: localPackage path="ndk;28.2.13676358"
package.xml: NDK (Side by side) 28.2.13676358
toolchains\llvm\prebuilt\windows-x86_64\bin\clang.exe: presente
```

O erro anterior fornecido pelo usuário indica falha de aquisição/descoberta dessa versão naquele build. O estado atual difere: diretório, metadados e compilador estão presentes. Não foi possível reproduzir o erro original até a etapa NDK, nem comprovar a integridade completa da instalação. Não seria correto afirmar que o NDK continua ausente ou que já foi validado por build.

Foram tentadas consulta e instalação idempotente pelo gerenciador oficial, ambas com exit 1:

```powershell
& 'C:\Users\Erick\AppData\Local\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat' --sdk_root=C:\Users\Erick\AppData\Local\Android\Sdk --list_installed
& 'C:\Users\Erick\AppData\Local\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat' --sdk_root=C:\Users\Erick\AppData\Local\Android\Sdk 'ndk;28.2.13676358'
```

O wrapper instalado informa que sdkmanager delega ao novo Android CLI. A falha efetiva foi:

```text
Error: Failed to open "C:\\Users\\Erick\\.android/cli/bundles\\lock"
Caused by:
    Acesso negado. (os error 5)
```

Nenhum arquivo do SDK, versão Gradle, banco ou licença foi removido/modificado para contornar a falha.

## Validação executada

O SDK externo continua fora da área gravável da sessão. Foi usada também a cópia local de diagnóstico existente, sem recriar o projeto. As tentativas Flutter usaram o snapshot oficial via `dart.exe`, com `--no-version-check --suppress-analytics` para evitar consulta de atualização e escrita de sessão de analytics externas; essas opções não suprimem análise, testes ou erros de build.

| Verificação | Resultado real |
| --- | --- |
| `flutter pub get` | Exit 1: subprocesso Dart negado antes da resolução |
| `dart --suppress-analytics format .` | Exit 0; 12 arquivos, um formatado (`test/app_test.dart`) |
| Conferência de formatação com `--output=none --set-exit-if-changed .` | Exit 0; 12 arquivos, zero mudanças |
| `flutter analyze` | Exit 1 antes da análise, subprocesso negado |
| `dart --suppress-analytics analyze` direto | Exit 1: acesso negado ao iniciar `dartaotruntime.exe`/analysis_server |
| `flutter test` | Exit 1 antes de executar os testes |
| `flutter build windows` | Exit 1 antes de compilar |
| `flutter build apk --debug` | Exit 1 antes de compilar |

Logs das tentativas Flutter estão localmente em `validation-logs/fix02-pub-get.txt`, `fix02-analyze.txt`, `fix02-test.txt`, `fix02-build-windows.txt` e `fix02-build-apk---debug.txt`. O erro comum é `CreateFile failed 5 (Acesso negado)` ao iniciar subprocessos. A análise direta confirmou a mesma restrição em `Process.start`, independente do conflito de imports corrigido.

O usuário informou que seis testes passaram anteriormente; **não foi possível confirmar nesta sessão que continuam passando após a correção**. Não houve build produzido, APK/executável validado ou execução de interface. Como o build Windows não passou nesta sessão, não foi possível executar o fluxo dashboard → criar projeto → fechar → reabrir → confirmar persistência. Compilação e funcionamento da UI continuam sendo verificações distintas.

## Arquivos modificados nesta correção

- `lib/app/app.dart`: remove o import conflitante.
- `test/app_test.dart`: verifica a localização pt-BR nos testes responsivos existentes; formatação aplicada.
- `docs/audits/f0-fix-02-validation.md`: este relatório.

Não foram alterados SPEC, regras de negócio, interface, dependências ou configuração Android. O hash SHA-256 da SPEC permanece `CB0BBFDFF3E2D0FEE37CDAFF4D38AF1C3C68A744EFD101A280A40C3435B1981B`.

## Validação externa no PowerShell

Em um PowerShell normal com escrita autorizada no SDK e rede funcional:

```powershell
Set-Location 'C:\Users\Erick\Planner'
$studyAndroidSdk = 'C:\Users\Erick\AppData\Local\Android\Sdk'
$studySdkManager = Join-Path $studyAndroidSdk 'cmdline-tools\latest\bin\sdkmanager.bat'
& $studySdkManager "--sdk_root=$studyAndroidSdk" --list_installed
& $studySdkManager "--sdk_root=$studyAndroidSdk" 'ndk;28.2.13676358'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao confirmar/instalar o NDK.' }

flutter doctor -v
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Falha no pub get.' }
dart format .
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Falha na análise.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes.' }
flutter build windows
if ($LASTEXITCODE -ne 0) { throw 'Falha no build Windows.' }
flutter build apk --debug
if ($LASTEXITCODE -ne 0) { throw 'Falha no build Android.' }
flutter run -d windows
```

Se o gerenciador pedir licenças, revisar e aceitar interativamente as necessárias; não apagar instalações existentes. Após o app abrir, conferir o estado vazio quando aplicável, navegar, criar um projeto identificável, encerrar normalmente, executar novamente e conferir o mesmo projeto. Não apagar o banco para forçar estado vazio. O caminho convencional esperado do APK é `build\app\outputs\flutter-apk\app-debug.apk`, e do Windows `build\windows\x64\runner\Release\study_planner.exe`; são **caminhos esperados, não artefatos produzidos nesta sessão**.

## Git e pendências

Foi tentado `git add lib/app/app.dart test/app_test.dart`, mas o Git retornou `Unable to create 'C:/Users/Erick/Planner/.git/index.lock': Permission denied`. Nenhum commit foi produzido. Não foram alteradas permissões. O repositório ainda apresenta a implementação como arquivos não rastreados; antes de commitar externamente, revisar o conjunto completo e registrar a base para evitar um commit incompleto. Mensagem solicitada para esta correção: `fix(flutter): resolve localization conflict and Android build setup`.

A correção localizada foi aplicada de fato. A F0 permanece **PENDENTE** até executar análise, seis testes, ambos builds e verificações de execução necessárias em ambiente autorizado. Nenhuma funcionalidade da F1 foi adicionada.

## Revalidação após repetição da solicitação

A nova inspeção confirmou que o import conflitante já foi removido e que `pt-BR` permanece configurado. Nenhuma alteração adicional de produção foi necessária. A versão NDK 28.2.13676358 continua registrada em source.properties. A tentativa de instalação oficial foi repetida e novamente bloqueada no lock externo de `.android`.

Foram repetidos os cinco comandos Flutter pela mesma via de snapshot: `pub get`, `analyze`, `test`, `build windows` e `build apk --debug`. Todos retornaram exit 1 ao iniciar o subprocesso Dart, antes das respectivas verificações. `dart --suppress-analytics format .` retornou exit 0, com 12 arquivos e zero mudanças. Os novos logs estão em `validation-logs/fix02-repeat-*.txt`. A tentativa de preparar o commit também foi repetida e segue bloqueada em `.git/index.lock`. Não foram produzidos builds nem executados testes ou UI. A classificação permanece **PENDENTE**; os comandos externos acima continuam aplicáveis.

## Retomada externa automatizada

Após nova autorização do usuário, os acessos foram testados novamente: proxies continuam em loopback/porta 9, escrita no índice Git continua negada e até `flutter test --no-pub` falhou ao iniciar `vswhere.exe`. A autorização na conversa não mudou as restrições técnicas da sessão.

Foi adicionado `scripts/validate-f0.ps1`, que verifica a presença do NDK esperado, solicita instalação oficial apenas se ausente, executa resolução, formatação, análise, testes e ambos builds, registrando logs e resultados em JSON. Interrompe na primeira falha e não apaga dados nem modifica permissões ou proxies. O script recebeu somente validação sintática nesta sessão; sua execução completa permanece pendente no PowerShell externo:

```powershell
Set-Location 'C:\Users\Erick\Planner'
.\scripts\validate-f0.ps1 -RunWindows
```

A execução da interface e persistência continuam exigindo conferência manual; sucesso do script não aprova sozinho esses critérios.
