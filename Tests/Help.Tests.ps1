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
    $projectRoot = Split-Path -Path $PSScriptRoot -Parent
    $moduleName = Split-Path -Path $projectRoot -Leaf
    $manifestPath = Join-Path -Path $projectRoot -ChildPath "$moduleName.psd1"
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
