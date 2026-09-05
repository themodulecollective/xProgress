#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
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
    Import-Module -Name $manifestPath -Force

    # Exclude aliases - an alias is covered by its target function's own test file.
    $CommandsForTest = (Get-Command -Module $moduleName -CommandType Function).Name | ForEach-Object {
        $file = Get-ChildItem -Path $projectRoot -Filter "$_.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
        @{CommandName = $_; TestFilePath = $file.FullName }
    }
}

Describe 'Public commands have Pester tests' -Tag 'Build' {
    It "Should have a Pester test for [<CommandName>]" -ForEach $CommandsForTest {
        $TestFilePath | Should -Not -BeNullOrEmpty
    }
}
