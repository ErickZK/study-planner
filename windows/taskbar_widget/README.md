# Widget próprio da barra de tarefas

O `TJSP.Planner.TaskbarWidget` é um processo WPF leve distribuído junto com o executável Flutter. Ele lê o mesmo SQLite do Planner, cria uma janela filha da barra de tarefas do Windows e abre um painel compacto com a meta diária, tarefas concluídas e próximo estudo.

O build do Flutter publica automaticamente o helper como aplicação autocontida em `taskbar_widget/` ao lado de `study_planner.exe`. O Planner o inicia em segundo plano e uma instância já aberta recebe o comando para mostrar ou ocultar o painel.

```powershell
flutter build windows --release
dart run msix:create --build-windows false --install-certificate false
```

O MSIX inclui os dois executáveis e registra `study_planner.exe --background` na inicialização do usuário. Nesse modo, o Flutter inicia somente o helper e encerra antes de criar a janela principal. O pacote local usa um certificado de teste; uma submissão à Microsoft Store recebe a assinatura da Store.

O widget exige Windows 11. A integração usa as janelas `Shell_TrayWnd` e `TrayNotifyWnd`, portanto deve ser validada após atualizações relevantes do Explorer e em configurações com vários monitores, DPI diferente e barra oculta.
