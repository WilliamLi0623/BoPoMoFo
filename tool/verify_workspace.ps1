[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $repositoryRoot 'app/bopomofo'
$flutterExe = (Get-Command flutter.bat -ErrorAction SilentlyContinue).Source
$dartExe = (Get-Command dart.bat -ErrorAction SilentlyContinue).Source
$userFlutterRoot = if ($env:FLUTTER_ROOT) {
  Join-Path $env:FLUTTER_ROOT 'bin'
} else {
  Join-Path $env:USERPROFILE 'dev/flutter/bin'
}
if (-not $flutterExe -and (Test-Path (Join-Path $userFlutterRoot 'flutter.bat'))) {
  $flutterExe = Join-Path $userFlutterRoot 'flutter.bat'
}
if (-not $dartExe -and (Test-Path (Join-Path $userFlutterRoot 'dart.bat'))) {
  $dartExe = Join-Path $userFlutterRoot 'dart.bat'
}
$supabaseExe = (Get-Command supabase -ErrorAction SilentlyContinue).Source
$script:results = [System.Collections.Generic.List[object]]::new()
$script:failed = $false
$script:incomplete = $false

function Add-Result([string]$Name, [string]$Status, [string]$Detail) {
  $script:results.Add([pscustomobject]@{ Check = $Name; Status = $Status; Detail = $Detail })
  Write-Host ("[{0}] {1}: {2}" -f $Status, $Name, $Detail)
}

function Invoke-Stage([string]$Name, [string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory) {
  if (-not $Executable -or -not (Test-Path -LiteralPath $Executable)) {
    $script:incomplete = $true
    Add-Result $Name 'UNAVAILABLE' 'required executable not found'
    return
  }
  $display = '"{0}" {1}' -f $Executable, ($Arguments -join ' ')
  Write-Host "`nRUN: $display"
  Push-Location -LiteralPath $WorkingDirectory
  try {
    & $Executable @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
    $exitCode = $LASTEXITCODE
  } catch {
    Write-Host $_
    $exitCode = 1
  } finally {
    Pop-Location
  }
  if ($null -eq $exitCode) { $exitCode = 1 }
  Add-Result $Name $(if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }) "exit code $exitCode; $display"
  if ($exitCode -ne 0) { $script:failed = $true }
}

Write-Host "Workspace verification: $repositoryRoot"
Invoke-Stage 'Workspace dependency resolution' $dartExe @('pub', 'get') $repositoryRoot
if ($flutterExe) {
  Invoke-Stage 'Flutter app dependency resolution' $flutterExe @('pub', 'get') $appRoot
} else {
  $script:incomplete = $true
  Add-Result 'Flutter app dependency resolution' 'UNAVAILABLE' 'Flutter SDK not found'
}

$packageDirectories = @(
  'domain', 'phonology', 'content', 'persistence', 'auth', 'sync',
  'srs', 'learning_engine', 'design_system'
)
foreach ($package in $packageDirectories) {
  $packageRoot = Join-Path $repositoryRoot "packages/$package"
  if (-not (Test-Path (Join-Path $packageRoot 'test'))) {
    Add-Result ('Package tests: ' + $package) 'NOT APPLICABLE' 'package has no test directory'
    continue
  }
  if ($package -in @('persistence', 'auth', 'sync', 'design_system')) {
    Invoke-Stage ('Flutter package tests: ' + $package) $flutterExe @('test', '--reporter', 'compact') $packageRoot
  } else {
    Invoke-Stage ('Dart package tests: ' + $package) $dartExe @('test', '--reporter', 'compact') $packageRoot
  }
}

foreach ($package in @('domain', 'phonology', 'content', 'srs', 'learning_engine')) {
  $packageRoot = Join-Path $repositoryRoot packages/$package
  Invoke-Stage ('Dart package analysis: ' + $package) $dartExe @('analyze') $packageRoot
}
foreach ($package in @('persistence', 'auth', 'sync', 'design_system')) {
  $packageRoot = Join-Path $repositoryRoot packages/$package
  Invoke-Stage ('Flutter package analysis: ' + $package) $flutterExe @('analyze') $packageRoot
}

if ($flutterExe) {
  Invoke-Stage 'Flutter analyze' $flutterExe @('analyze') $appRoot
  Invoke-Stage 'Flutter unit/widget tests' $flutterExe @('test') $appRoot
  Invoke-Stage 'Offline/restart integration test' $flutterExe @('test', '--no-pub', 'integration_test/offline_learning_test.dart') $appRoot
  Invoke-Stage 'Multi-device merge integration test' $flutterExe @('test', '--no-pub', 'integration_test/multi_device_merge_test.dart') $appRoot
} else {
  foreach ($name in @('Flutter analyze', 'Flutter unit/widget tests', 'Offline/restart integration test', 'Multi-device merge integration test')) {
    $script:incomplete = $true
    Add-Result $name 'UNAVAILABLE' 'Flutter SDK not found'
  }
}

$migrationFiles = Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'supabase/migrations') -Filter '*.sql' -ErrorAction SilentlyContinue
$migrationText = ($migrationFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join ([char]10)
$requiredTables = @('profiles', 'devices', 'learning_events', 'skill_snapshots', 'confusion_edges', 'user_settings', 'sync_state')
$policyStatements = [regex]::Matches($migrationText, '(?is)create\s+policy\b.*?;')
$ownerPoliciesComplete = $true
foreach ($table in $requiredTables) {
  $tablePattern = 'on\s+public\.' + [regex]::Escape($table) + '\b'
  $ownerPolicy = $policyStatements | Where-Object {
    $_.Value -match $tablePattern -and $_.Value -match 'auth\.uid\(\)\s*=\s*user_id'
  }
  if (-not $ownerPolicy) { $ownerPoliciesComplete = $false }
}
$deletionFunction = [regex]::Match(
  $migrationText,
  '(?is)create\s+or\s+replace\s+function\s+public\.delete_own_account\(\).*?\$\$;'
).Value
$deletionSecure = $deletionFunction -match 'security\s+definer' -and
  $deletionFunction -match 'auth\.uid\(\)' -and
  $deletionFunction -match 'delete\s+from\s+auth\.users' -and
  $migrationText -match 'revoke all on function public\.delete_own_account\(\) from public, anon' -and
  $migrationText -match 'grant execute on function public\.delete_own_account\(\) to authenticated'
$eventImmutable = $migrationText -match '(?is)grant\s+select\s*,\s*insert\s+on\s+(?:table\s+)?public\.learning_events\s+to\s+authenticated' -and
  $migrationText -match '(?is)revoke\s+all(?:\s+privileges)?\s+on\s+(?:table\s+)?public\.learning_events\s+from\s+public\s*,\s*anon\s*,\s*authenticated' -and
  $migrationText -notmatch '(?is)grant\s+[^;]*(?:update|delete)[^;]*on\s+public\.learning_events'
$sqlChecks = @(
  ($migrationText -match 'event_id\s+text\s+primary key'),
  (($requiredTables | Where-Object { $migrationText -notmatch "create table public\.$_\b" }).Count -eq 0),
  (($requiredTables | Where-Object { $migrationText -notmatch "alter table public\.$_ enable row level security" }).Count -eq 0),
  $ownerPoliciesComplete,
  $deletionSecure,
  $eventImmutable
)
if (($sqlChecks | Where-Object { -not $_ }).Count -eq 0) {
  Add-Result 'SQL static structure' 'STATIC ONLY' 'schema/RLS/deletion patterns found; this is not database execution'
} else {
  Add-Result 'SQL static structure' 'FAIL' 'one or more required schema/RLS patterns are missing'
  $script:failed = $true
}
if ($supabaseExe) {
  Invoke-Stage 'Supabase migrations' $supabaseExe @('db', 'reset') $repositoryRoot
  Invoke-Stage 'Supabase RLS tests' $supabaseExe @('test', 'db') $repositoryRoot
} else {
  $script:incomplete = $true
  Add-Result 'Supabase RLS runtime tests' 'UNAVAILABLE' 'Supabase CLI not found; static SQL checks are not a substitute'
}

if ($flutterExe -and $env:OS -eq 'Windows_NT') {
  if (Test-Path (Join-Path $appRoot 'windows/CMakeLists.txt')) {
    Invoke-Stage 'Windows desktop build' $flutterExe @('build', 'windows', '--debug') $appRoot
  } else {
    $script:incomplete = $true
    Add-Result 'Windows desktop build' 'UNAVAILABLE' 'Windows runner files are absent'
  }
  if ($env:ANDROID_HOME -or $env:ANDROID_SDK_ROOT) {
    Invoke-Stage 'Android debug build' $flutterExe @('build', 'apk', '--debug') $appRoot
  } else {
    $script:incomplete = $true
    Add-Result 'Android debug build' 'UNAVAILABLE' 'Android SDK is not configured'
  }
  foreach ($target in @('Linux', 'macOS', 'iOS')) {
    $script:incomplete = $true
    Add-Result "$target build" 'UNAVAILABLE' 'requires a matching Linux/macOS CI runner and platform toolchain'
  }
} else {
  foreach ($target in @('Android', 'Windows', 'Linux', 'macOS', 'iOS')) {
    $script:incomplete = $true
    Add-Result "$target build" 'UNAVAILABLE' 'native builds require a matching runner/toolchain'
  }
}

Write-Host "`nAcceptance matrix"
$script:results | Format-Table -AutoSize | Out-String | Write-Host
if ($script:failed) {
  Write-Host 'OVERALL: FAIL (one or more executable checks failed)'
  exit 1
}
if ($script:incomplete) {
  Write-Host 'OVERALL: INCOMPLETE (see unavailable checks above)'
  exit 2
}
Write-Host 'OVERALL: PASS'
exit 0
