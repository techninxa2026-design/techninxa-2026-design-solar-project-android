param([switch]$BuildDebug, [switch]$ConfigureJdkOnly, [string]$JdkDir)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Install Flutter 3.35.7 and Android SDK.' }
function Run-Flutter { & flutter @args; if ($LASTEXITCODE -ne 0) { throw "Flutter command failed: $args" } }

# The Gradle 8.12 / AGP 8.9.1 combination is tested with JDK 17 in CI.
# Flutter may otherwise prefer Android Studio's newer bundled JBR (e.g. Java 25).
function Test-Jdk17([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (!(Test-Path -LiteralPath (Join-Path $Path 'bin\java.exe') -PathType Leaf) -or
        !(Test-Path -LiteralPath (Join-Path $Path 'bin\javac.exe') -PathType Leaf) -or
        !(Test-Path -LiteralPath (Join-Path $Path 'release') -PathType Leaf)) { return $false }
    return ((Get-Content -LiteralPath (Join-Path $Path 'release') -Raw) -match '(?m)^JAVA_VERSION="17(?:[.\-+]|")')
}
if ($JdkDir) {
    if (!(Test-Jdk17 $JdkDir)) { throw 'The supplied -JdkDir must point to a JDK 17 installation root (containing bin\java.exe, bin\javac.exe and release).' }
    $selectedJdk = (Resolve-Path -LiteralPath $JdkDir).Path
} else {
    $candidates = @($env:JAVA_HOME, $env:JDK_HOME)
    $java = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($java -and $java.Source) { $candidates += Split-Path (Split-Path $java.Source -Parent) -Parent }
    $roots = @(
        (Join-Path $env:ProgramFiles 'Microsoft'),
        (Join-Path $env:ProgramFiles 'Eclipse Adoptium'),
        (Join-Path $env:ProgramFiles 'Java'),
        (Join-Path $env:ProgramFiles 'Amazon Corretto'),
        (Join-Path $env:ProgramFiles 'Android\Android Studio')
    )
    if ($env:LOCALAPPDATA) {
        $roots += Join-Path $env:LOCALAPPDATA 'Programs\Eclipse Adoptium'
        $roots += Join-Path $env:LOCALAPPDATA 'Programs\Microsoft'
    }
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root -PathType Container) {
            $candidates += @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending | ForEach-Object FullName)
        }
    }
    $selectedJdk = $candidates | Where-Object { Test-Jdk17 $_ } | Select-Object -First 1
    if (!$selectedJdk) { throw 'JDK 17 was not found. Install it: winget install --id Microsoft.OpenJDK.17 --exact . Then rerun setup, or supply -JdkDir with the actual JDK 17 directory.' }
    $selectedJdk = (Resolve-Path -LiteralPath $selectedJdk).Path
}
$env:JAVA_HOME = $selectedJdk
$env:Path = (Join-Path $selectedJdk 'bin') + ';' + $env:Path
# This is a persistent Flutter user-level setting, not a hardcoded repository path.
Run-Flutter config "--jdk-dir=$selectedJdk"
Write-Host "IDCOLDA: Flutter configured to use JDK 17 at $selectedJdk" -ForegroundColor Green
if ($ConfigureJdkOnly) { return }

if (!(Test-Path 'android/gradlew.bat') -or !(Test-Path 'android/gradle/wrapper/gradle-wrapper.jar')) {
    $scaffold = Join-Path $env:TEMP ("idcolda-wrapper-" + [Guid]::NewGuid().ToString('N'))
    try {
        Run-Flutter create --platforms=android --org com.techninxa --project-name idcolda_ms $scaffold
        Copy-Item (Join-Path $scaffold 'android/gradlew') 'android/gradlew'
        Copy-Item (Join-Path $scaffold 'android/gradlew.bat') 'android/gradlew.bat'
        Copy-Item (Join-Path $scaffold 'android/gradle/wrapper/gradle-wrapper.jar') 'android/gradle/wrapper/gradle-wrapper.jar'
    } finally { if (Test-Path $scaffold) { Remove-Item $scaffold -Recurse -Force } }
}
Run-Flutter pub get
& dart format lib test
if ($LASTEXITCODE -ne 0) { throw 'Dart formatting failed.' }
Run-Flutter analyze --no-fatal-infos --no-fatal-warnings
Run-Flutter test
if ($BuildDebug) { Run-Flutter build apk --debug; Write-Host 'APK: build/app/outputs/flutter-apk/app-debug.apk' }
