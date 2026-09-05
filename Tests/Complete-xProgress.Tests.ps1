#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

$CommandName = $MyInvocation.MyCommand.Name.Replace('.Tests.ps1', '')

BeforeAll {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    Import-Module -Name $manifestPath -Force
}

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    BeforeEach {
        Mock -ModuleName xProgress Write-Progress { }
    }

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

    Context 'Completing a known instance' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
        }

        It 'Removes the instance from tracking' {
            Complete-xProgress -Identity $script:id
            Get-xProgress -Identity $script:id | Should -BeNullOrEmpty
        }

        It 'Calls Write-Progress with -Completed, 100 percent, and 0 seconds remaining' {
            Complete-xProgress -Identity $script:id
            Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter {
                $Completed -eq $true -and $PercentComplete -eq 100 -and $SecondsRemaining -eq 0 -and $null -ne $Id
            }
        }

        It 'Stops the stopwatch' {
            Write-xProgress -Identity $script:id
            # Capture the reference before completing - Complete-xProgress removes the instance from
            # tracking, so it won't be retrievable via Get-xProgress afterward, but the Stopwatch object
            # itself (a .NET reference type) is still valid through this already-held reference.
            $instance = Get-xProgress -Identity $script:id
            $instance.Stopwatch.IsRunning | Should -BeTrue
            Complete-xProgress -Identity $script:id
            $instance.Stopwatch.IsRunning | Should -BeFalse
        }
    }

    Context 'Unknown identity' {
        It 'Warns instead of throwing for an unknown Identity' {
            Complete-xProgress -Identity ([guid]::NewGuid()) -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
