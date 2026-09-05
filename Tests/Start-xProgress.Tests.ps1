#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

$CommandName = $MyInvocation.MyCommand.Name.Replace('.Tests.ps1', '')

BeforeAll {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    Import-Module -Name $manifestPath -Force
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

    Context 'Starting a stopped stopwatch' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
        }

        It 'Starts the stopwatch' {
            Start-xProgress -Identity $script:id
            (Get-xProgress -Identity $script:id).Stopwatch.IsRunning | Should -BeTrue
        }

        It 'Warns when the stopwatch is already running' {
            Start-xProgress -Identity $script:id
            Start-xProgress -Identity $script:id -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Unknown identity' {
        It 'Warns instead of throwing for an unknown Identity' {
            Start-xProgress -Identity ([guid]::NewGuid()) -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
