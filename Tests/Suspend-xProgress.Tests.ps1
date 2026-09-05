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

    Context 'Suspending a running stopwatch' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
            Start-xProgress -Identity $script:id
        }

        It 'Stops the stopwatch' {
            Suspend-xProgress -Identity $script:id
            (Get-xProgress -Identity $script:id).Stopwatch.IsRunning | Should -BeFalse
        }

        It 'Warns when the stopwatch is not running' {
            Suspend-xProgress -Identity $script:id
            Suspend-xProgress -Identity $script:id -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Unknown identity' {
        It 'Warns instead of throwing for an unknown Identity' {
            Suspend-xProgress -Identity ([guid]::NewGuid()) -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
