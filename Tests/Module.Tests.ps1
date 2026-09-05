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
}

BeforeAll {
    $script:ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    $script:ModuleName = Split-Path -Path $script:ProjectRoot -Leaf
    $script:ManifestPath = Join-Path -Path $script:ProjectRoot -ChildPath "$script:ModuleName.psd1"
}

Describe 'Module manifest is valid' -Tag 'Build' {
    BeforeAll {
        $script:Manifest = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop
    }

    It 'Has a valid manifest' {
        $script:Manifest | Should -Not -BeNullOrEmpty
    }

    It 'Has the correct module name' {
        $script:Manifest.Name | Should -Be $script:ModuleName
    }

    It 'Has a valid version' {
        $script:Manifest.Version | Should -BeOfType [System.Version]
    }

    It 'Has a description' {
        $script:Manifest.Description | Should -Not -BeNullOrEmpty
    }

    It 'Has a valid GUID' {
        { [System.Guid]::Parse($script:Manifest.Guid) } | Should -Not -Throw
    }

    It 'Has an author' {
        $script:Manifest.Author | Should -Not -BeNullOrEmpty
    }
}

Describe 'Module can be imported and exports commands' -Tag 'Build' {
    BeforeAll {
        Import-Module -Name $script:ManifestPath -Force
    }

    It 'Imports without error' {
        Get-Module -Name $script:ModuleName | Should -Not -BeNullOrEmpty
    }

    It 'Exports public commands' {
        (Get-Command -Module $script:ModuleName).Count | Should -BeGreaterThan 0
    }
}
