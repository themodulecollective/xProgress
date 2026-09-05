# Dot-source this from a BeforeDiscovery or BeforeAll block to resolve the module under test.
# Sets $repoRoot, $manifest, $projectRoot, $moduleName, $manifestPath in the caller's scope;
# does not import the module itself - callers do that with $manifestPath.

$repoRoot = Split-Path -Path $PSScriptRoot -Parent

# Check manifest at repo root first (current structure), then one level deep (module-in-subfolder)
$manifest = Get-ChildItem -Path $repoRoot -Filter '*.psd1' -Depth 0 |
    Where-Object Name -ne 'ScriptAnalyzerSettings.psd1' |
    Select-Object -First 1

if (-not $manifest)
{
    $manifest = Get-ChildItem -Path $repoRoot -Filter '*.psd1' -Recurse -Depth 2 |
        Where-Object Name -ne 'ScriptAnalyzerSettings.psd1' |
        Select-Object -First 1
}

$projectRoot = $manifest.DirectoryName
$moduleName = $manifest.BaseName
$manifestPath = $manifest.FullName
