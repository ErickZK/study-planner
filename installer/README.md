# Meu Rumo - Windows Installer

Este diretório contém os arquivos necessários para gerar o instalador profissional do Meu Rumo para Windows.

## Requisitos

Para gerar o instalador, você precisa ter instalado no seu sistema:

1.  **Flutter SDK** (v3.10 ou superior)
2.  **.NET SDK 10.0** (ou superior)
3.  **Inno Setup 6 ou 7**
    *   O script procura por `ISCC.exe` em `C:\Program Files\Inno Setup 7\` ou `C:\Program Files (x86)\Inno Setup 6\`.

## Como Gerar o Instalador

A geração é totalmente automatizada através do script de build localizado na raiz do projeto.

1.  Abra o PowerShell no diretório raiz do projeto (`C:\Users\Erick\Planner`).
2.  Execute o script:
    ```powershell
    .\scripts\build-release.ps1
    ```

O script realizará as seguintes etapas:
- Extração da versão atual do `pubspec.yaml`.
- Limpeza de builds anteriores.
- `flutter pub get` e `flutter analyze`.
- Compilação do Flutter em modo Release para Windows x64.
- Publicação do Widget Pomodoro (.NET) em modo Release (self-contained).
- Geração do instalador usando o Inno Setup.
- Cálculo do hash SHA-256 do arquivo gerado.

## Onde encontrar o instalador

Após a execução bem-sucedida, o instalador estará disponível na pasta:
`dist/MeuRumo-Setup-X.Y.Z.exe`

## Detalhes da Instalação

- **Diretório Padrão:** `%LOCALAPPDATA%\Programs\Meu Rumo`
- **Privilégios:** Instalação por usuário, não requer privilégios de administrador.
- **Menu Iniciar:** Cria uma entrada "Meu Rumo".
- **Área de Trabalho:** Opção para criar atalho.
- **Desinstalação:** Disponível em "Adicionar ou Remover Programas".

## Preservação de Dados

O Study Planner armazena seus dados (SQLite e configurações) em:
`%LOCALAPPDATA%\study_planner\` (ou similar, dependendo do sistema).

**Importante:**
- O instalador e o desinstalador **não** removem ou sobrescrevem os dados do usuário durante atualizações ou remoção do programa. Isso garante que seu progresso de estudos seja preservado.

## Widget Pomodoro

O Widget Pomodoro é empacotado como uma aplicação .NET self-contained dentro da subpasta `taskbar_widget` do diretório de instalação. Ele é iniciado automaticamente pela aplicação principal quando necessário.
