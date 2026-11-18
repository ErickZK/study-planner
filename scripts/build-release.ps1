# Build Release Script for Meu Rumo Windows

$ErrorActionPreference = "Stop"

# 1. Configuration
$FlutterCmd = "flutter"
if (-not (Get-Command $FlutterCmd -ErrorAction SilentlyContinue)) {
    $LocalFlutter = Join-Path $PSScriptRoot "..\.tooling\flutter\bin\flutter.bat"
    if (Test-Path $LocalFlutter) {
        $FlutterCmd = (Resolve-Path $LocalFlutter).Path
    } else {
        Write-Error "Flutter CLI not found on PATH or in .tooling\flutter\bin\flutter.bat."
    }
}

$InnoSetupPath = "C:\Program Files\Inno Setup 7\ISCC.exe"
if (-not (Test-Path $InnoSetupPath)) {
    # Try Inno Setup 6 as fallback
    $InnoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
}

if (-not (Test-Path $InnoSetupPath)) {
    Write-Error "Inno Setup (ISCC.exe) not found. Please install Inno Setup 6 or 7."
}

# 2. Extract Version from pubspec.yaml
Write-Host "Extracting version from pubspec.yaml..." -ForegroundColor Cyan
$PubspecContent = Get-Content "pubspec.yaml" -Raw
if ($PubspecContent -match 'version:\s*([^\s+]+)') {
    $Version = $Matches[1]
    Write-Host "Detected Version: $Version" -ForegroundColor Green
} else {
    Write-Error "Could not find version in pubspec.yaml"
}

# 3. Preparation
Write-Host "Cleaning up previous builds..." -ForegroundColor Cyan
if (Test-Path "build\windows") { Remove-Item -Recurse -Force "build\windows" }
if (Test-Path "dist") { Remove-Item -Recurse -Force "dist" }
New-Item -ItemType Directory -Path "dist" -Force | Out-Null

# 4. Flutter Build
Write-Host "Running flutter pub get..." -ForegroundColor Cyan
& $FlutterCmd pub get
if ($LASTEXITCODE -ne 0) { Write-Error "flutter pub get failed with exit code $LASTEXITCODE" }

Write-Host "Running flutter analyze..." -ForegroundColor Cyan
& $FlutterCmd analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { Write-Error "flutter analyze failed with exit code $LASTEXITCODE" }

Write-Host "Building Flutter Windows Release..." -ForegroundColor Cyan
& $FlutterCmd build windows --release
if ($LASTEXITCODE -ne 0) { Write-Error "flutter build windows failed with exit code $LASTEXITCODE" }

# 5. Bundle Visual C++ x64 CRT DLLs app-local (no VC++ Redistributable needed on target PCs)
Write-Host "Bundling Visual C++ x64 Runtime DLLs..." -ForegroundColor Cyan
$ReleaseDir = "build\windows\x64\runner\Release"
$VcCrtDir = Get-ChildItem -Path @(
    "C:\Program Files\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT",
    "C:\Program Files (x86)\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT"
) -Directory -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1

if ($VcCrtDir) {
    Write-Host "Found VC++ CRT Redist: $($VcCrtDir.FullName)" -ForegroundColor Green
    Copy-Item -Path (Join-Path $VcCrtDir.FullName "*.dll") -Destination $ReleaseDir -Force
} else {
    Write-Warning "Could not locate Visual Studio VC++ CRT redistributable folder; target PCs may need VC++ Redistributable x64."
}

# 6. .NET Widget Build (clean single-file self-contained, zero .NET install required on target PCs)
Write-Host "Building self-contained .NET Taskbar Widget..." -ForegroundColor Cyan
$WidgetProj = "windows\taskbar_widget\TJSP.Planner.TaskbarWidget.csproj"
$WidgetOut = "$ReleaseDir\taskbar_widget"
if (Test-Path $WidgetOut) { Remove-Item -Recurse -Force $WidgetOut }

dotnet publish $WidgetProj `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:IncludeAllContentForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=none `
    -p:DebugSymbols=false `
    -o $WidgetOut
if ($LASTEXITCODE -ne 0) { Write-Error "dotnet publish failed with exit code $LASTEXITCODE" }

# 7. Verify binaries and app-local runtime DLLs
$FlutterExe = "$ReleaseDir\study_planner.exe"
$WidgetExe = "$WidgetOut\TJSP.Planner.TaskbarWidget.exe"

if (-not (Test-Path $FlutterExe)) { Write-Error "Flutter executable not found!" }
if (-not (Test-Path $WidgetExe)) { Write-Error "Widget executable not found!" }
foreach ($crtDll in @("vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll")) {
    if (-not (Test-Path (Join-Path $ReleaseDir $crtDll))) {
        Write-Error "Required runtime DLL missing from release bundle: $crtDll"
    }
}

# 7. Generate Installer
Write-Host "Generating Installer with Inno Setup..." -ForegroundColor Cyan
$IssFile = "installer\study-planner.iss"

# Update version in .iss file (temporary or using definitions)
& $InnoSetupPath /DMyAppVersion=$Version $IssFile
if ($LASTEXITCODE -ne 0) { Write-Error "Inno Setup failed with exit code $LASTEXITCODE" }

# 8. Finalize
$SetupFile = "installer\Output\MeuRumo-Setup-$Version.exe"
if (Test-Path $SetupFile) {
    $DestFile = "dist\MeuRumo-Setup-$Version.exe"
    Move-Item $SetupFile $DestFile -Force
    
    $Hash = Get-FileHash $DestFile -Algorithm SHA256
    $Size = (Get-Item $DestFile).Length / 1MB
    
    Write-Host "`nBuild Successful!" -ForegroundColor Green
    Write-Host "-------------------------------------------"
    Write-Host "Installer: $DestFile"
    Write-Host "Version:   $Version"
    Write-Host "Size:      $($Size.ToString('F2')) MB"
    Write-Host "SHA-256:   $($Hash.Hash)"
    Write-Host "-------------------------------------------"
} else {
    Write-Error "Failed to generate installer."
}
