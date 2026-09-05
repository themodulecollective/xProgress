#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    $rulesPath = Join-Path -Path $projectRoot -ChildPath 'ScriptAnalyzerSettings.psd1'
    if (-not (Test-Path -LiteralPath $rulesPath)) { $rulesPath = $null }

    $moduleSources = @()
    $moduleSources += Get-ChildItem -Path $projectRoot -Filter '*.psm1' -Depth 0
    foreach ($folder in @('Functions', 'Public', 'Private'))
    {
        $folderPath = Join-Path -Path $projectRoot -ChildPath $folder
        if (Test-Path -Path $folderPath -PathType Container)
        {
            $moduleSources += Get-ChildItem -Path $folderPath -Filter '*.ps1' -Recurse
        }
    }

    $ScriptsForAnalysis = $moduleSources |
        ForEach-Object { @{ScriptName = $_.Name; FullName = $_.FullName; RulesPath = $rulesPath } }
}

Describe 'All scripts pass PSScriptAnalyzer rules' -Tag 'Build' {
    Context '<ScriptName>' -ForEach $ScriptsForAnalysis {
        BeforeAll {
            $invokeParams = @{Path = $FullName }
            if ($null -ne $RulesPath) { $invokeParams['Settings'] = $RulesPath }
            $script:AnalyzerResults = Invoke-ScriptAnalyzer @invokeParams
        }
        It 'Should not fail any rules' {
            $script:AnalyzerResults | Should -BeNullOrEmpty
        }
    }
}
