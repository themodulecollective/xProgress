#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
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
