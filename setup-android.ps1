param([switch]$BuildDebug)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Install Flutter 3.47 or later and Android SDK.' }
function Run-Flutter { & flutter @args; if ($LASTEXITCODE -ne 0) { throw "Flutter command failed: $args" } }
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
