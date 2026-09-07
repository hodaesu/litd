param(
    [ValidateSet('quick','changed','full')]
    [string]$Mode = 'quick',
    [string]$BaseRef = 'origin/main',
    [switch]$SkipGodot,
    [switch]$SkipPython,
    [switch]$RequireGodot,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $Root

$python = $null
foreach ($candidate in @('py', 'python', 'python3')) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $python = $candidate
        break
    }
}
if (-not $python) {
    throw 'Python 3 est requis pour lancer le pipeline Veilleurs.'
}

$argsList = @('tools/godot/veilleurs_pipeline.py', '--mode', $Mode, '--base-ref', $BaseRef)
if ($SkipGodot) { $argsList += '--skip-godot' }
if ($SkipPython) { $argsList += '--skip-python' }
if ($RequireGodot) { $argsList += '--require-godot' }
if ($DryRun) { $argsList += '--dry-run' }

if ($python -eq 'py') {
    & $python -3 @argsList
} else {
    & $python @argsList
}
exit $LASTEXITCODE
