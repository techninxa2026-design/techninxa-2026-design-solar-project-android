# Run on the trusted development PC with GitHub CLI already authenticated.
# Reuse the original release key. Do not generate a replacement for existing users.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$Keystore,
 [Parameter(Mandatory=$true)][string]$KeyAlias,
 [string]$Repository='techninxa2026-design/techninxa-2026-design-solar-project-android'
)
$ErrorActionPreference='Stop'
if(!(Get-Command gh -ErrorAction SilentlyContinue)){throw 'Install GitHub CLI and run gh auth login.'}
if(!(Test-Path -LiteralPath $Keystore -PathType Leaf)){throw 'Keystore file not found.'}
& gh auth status
if($LASTEXITCODE -ne 0){throw 'GitHub CLI is not authenticated.'}
function Set-Secret([string]$Name,[string]$Value){
 $Value | gh secret set $Name --repo $Repository
 if($LASTEXITCODE -ne 0){throw "Failed to set $Name"}
}
function Read-Password([string]$Prompt){
 $secure=Read-Host $Prompt -AsSecureString
 $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
 try{return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)}
 finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$secure.Dispose()}
}
$store=Read-Password 'Keystore password'
$key=Read-Password 'Key password'
try{
 if([string]::IsNullOrWhiteSpace($store) -or [string]::IsNullOrWhiteSpace($key)){throw 'Passwords cannot be empty.'}
 $bytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Keystore).Path)
 try{
  $encoded=[Convert]::ToBase64String($bytes)
  if($encoded.Length -gt 48000){throw 'Keystore exceeds the Actions secret size limit.'}
  Set-Secret IDCOLDA_KEYSTORE_BASE64 $encoded
  Set-Secret IDCOLDA_STORE_PASSWORD $store
  Set-Secret IDCOLDA_KEY_ALIAS $KeyAlias
  Set-Secret IDCOLDA_KEY_PASSWORD $key
 }finally{[Array]::Clear($bytes,0,$bytes.Length);$encoded=$null}
 Write-Host 'Signing secrets configured. Configure VPS verification and automatic publishing next.'
}finally{$store=$null;$key=$null}
