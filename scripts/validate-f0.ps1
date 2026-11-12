[CmdletBinding()]
param(
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [switch]$RunWindows
)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $projectDirectory ('validation-logs\external-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$results = [System.Collections.Generic.List[object]]::new()
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

function Invoke-ValidationStep {
    param([string]$Name, [string]$Executable, [string[]]$CommandArguments)
    Write-Host "`n$Name" -ForegroundColor Cyan
    $stepLog = Join-Path $logDirectory ($Name + '.txt')
    # Windows PowerShell can turn native stderr warnings into terminating errors.
    # Record both streams; the native exit code determines success.
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable @CommandArguments 2>&1 | Tee-Object -FilePath $stepLog | Out-Host
        $stepExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $savedPreference
    }
    $results.Add([pscustomobject]@{
        step = $Name
        command = $Executable
        arguments = $CommandArguments
        exitCode = $stepExitCode
        log = $stepLog
    })
    if ($stepExitCode -ne 0) {
        throw "$Name falhou (exit $stepExitCode). Consulte $stepLog"
    }
}

Push-Location $projectDirectory
try {
    $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
    $dartCommand = (Get-Command dart -ErrorAction Stop).Source
    $sdkManager = Join-Path $AndroidSdk 'cmdline-tools\latest\bin\sdkmanager.bat'
    $ndkProperties = Join-Path $AndroidSdk 'ndk\28.2.13676358\source.properties'
    $ndkCompiler = Join-Path $AndroidSdk 'ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\clang.exe'

    # Preserve the existing installation. Install only if the expected NDK is absent.
    $ndkPresent = (Test-Path -LiteralPath $ndkProperties) -and
        (Test-Path -LiteralPath $ndkCompiler)
    if ($ndkPresent) {
        $ndkPresent = [bool](Select-String -LiteralPath $ndkProperties -Pattern '^Pkg.Revision\s*=\s*28\.2\.13676358\s*$')
    }
    if (-not $ndkPresent) {
        if (-not (Test-Path -LiteralPath $sdkManager)) {
            throw "Gerenciador oficial ausente: $sdkManager"
        }
        Invoke-ValidationStep 'ndk-install' $sdkManager @("--sdk_root=$AndroidSdk", 'ndk;28.2.13676358')
    }

    Invoke-ValidationStep 'flutter-version' $flutterCommand @('--version')
    Invoke-ValidationStep 'pub-get' $flutterCommand @('pub', 'get')
    Invoke-ValidationStep 'format' $dartCommand @('format', '.')
    Invoke-ValidationStep 'analyze' $flutterCommand @('analyze')
    Invoke-ValidationStep 'test' $flutterCommand @('test')
    Invoke-ValidationStep 'build-windows' $flutterCommand @('build', 'windows')
    Invoke-ValidationStep 'build-android' $flutterCommand @('build', 'apk', '--debug')

    Write-Host '`nComandos de validacao concluidos. A interface ainda precisa de verificacao manual.' -ForegroundColor Green
    Write-Host 'No Windows: conferir dashboard, criar projeto, fechar, reabrir e confirmar persistencia.'
    if ($RunWindows) {
        Invoke-ValidationStep 'run-windows' $flutterCommand @('run', '-d', 'windows')
    }
}
finally {
    ConvertTo-Json -InputObject @($results.ToArray()) -Depth 4 |
        Set-Content -LiteralPath (Join-Path $logDirectory 'results.json') -Encoding UTF8
    Write-Host "Logs: $logDirectory"
    Pop-Location
}
