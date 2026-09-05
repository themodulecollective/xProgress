#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    Import-Module -Name $manifestPath -Force

    # Exclude aliases - Get-Help on an alias just returns the target function's help, which
    # will not mention the alias's own name, so alias commands cannot pass these assertions.
    $HelpByCommand = @{}
    foreach ($function in (Get-Command -Module $moduleName -CommandType Function))
    {
        $HelpByCommand[$function.Name] = Get-Help -Name $function.Name -ErrorAction SilentlyContinue
    }

    $CommandsForHelp = $HelpByCommand.Keys | ForEach-Object { @{Name = $_ } }

    $ExamplesForHelp = $HelpByCommand.Keys | ForEach-Object {
        @{Name = $_; Examples = $HelpByCommand[$_].Examples }
    }

    $ParametersForHelp = foreach ($cmdName in $HelpByCommand.Keys)
    {
        $node = $HelpByCommand[$cmdName]
        foreach ($parameter in $node.Parameters.Parameter)
        {
            if ($parameter.Name -notmatch 'WhatIf|Confirm')
            {
                @{
                    CommandName   = $cmdName
                    ParameterName = $parameter.Name
                    Description   = $parameter.Description.Text
                }
            }
        }
    }
}

BeforeAll {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    Import-Module -Name $manifestPath -Force
}

Describe 'Public commands have comment-based or external help' -Tag 'Build' {
    It "Should have a Description or Synopsis for [<Name>]" -ForEach $CommandsForHelp {
        $node = Get-Help -Name $Name -ErrorAction SilentlyContinue
        ($node.Description | Out-String) + ($node.Synopsis | Out-String) | Should -Not -BeNullOrEmpty
    }

    It "Should have an Example for [<Name>]" -ForEach $ExamplesForHelp {
        $Examples | Should -Not -BeNullOrEmpty
        $Examples.example.code | Out-String | Should -Match $Name
    }

    It "Parameter [<ParameterName>] of [<CommandName>] should have a description" -ForEach $ParametersForHelp {
        $Description | Should -Not -BeNullOrEmpty
    }
}
