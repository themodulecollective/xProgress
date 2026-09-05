#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

$CommandName = $MyInvocation.MyCommand.Name.Replace('.Tests.ps1', '')

BeforeAll {
    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath 'xProgress.psd1') -Force
}

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context 'Validate parameters' {
        It 'Should have the expected parameters' {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Identity')
            foreach ($kp in $knownParameters)
            {
                $kp | Should -BeIn $params
            }
        }
    }

    Context 'Resuming a suspended stopwatch' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
            Start-xProgress -Identity $script:id
            Suspend-xProgress -Identity $script:id
        }

        It 'Restarts the stopwatch' {
            Resume-xProgress -Identity $script:id
            (Get-xProgress -Identity $script:id).Stopwatch.IsRunning | Should -BeTrue
        }

        It 'Warns when the stopwatch is already running' {
            Resume-xProgress -Identity $script:id
            Resume-xProgress -Identity $script:id -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Unknown identity' {
        It 'Warns instead of throwing for an unknown Identity' {
            Resume-xProgress -Identity ([guid]::NewGuid()) -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
