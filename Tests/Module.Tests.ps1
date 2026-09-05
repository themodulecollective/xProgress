#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    Import-Module -Name $manifestPath -Force
}

BeforeAll {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    $script:ProjectRoot = $projectRoot
    $script:ModuleName = $moduleName
    $script:ManifestPath = $manifestPath
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
