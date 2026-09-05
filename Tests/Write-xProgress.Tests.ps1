#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

$CommandName = $MyInvocation.MyCommand.Name.Replace('.Tests.ps1', '')

BeforeAll {
    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath 'xProgress.psd1') -Force
}

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    BeforeEach {
        Mock -ModuleName xProgress Write-Progress { }
    }

    Context 'Validate parameters' {
        It 'Should have the expected parameters' {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Identity', 'DoNotIncrement', 'DoNotStartTimer')
            foreach ($kp in $knownParameters)
            {
                $kp | Should -BeIn $params
            }
        }
    }

    Context 'Unknown identity' {
        It 'Throws when Identity is not found' {
            { Write-xProgress -Identity ([guid]::NewGuid()) } | Should -Throw
        }
    }

    Context 'Counter increment' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Test'
        }

        It 'Increments Counter by default' {
            Write-xProgress -Identity $script:id
            (Get-xProgress -Identity $script:id).Counter | Should -Be 1
        }

        It 'Does not increment Counter when -DoNotIncrement is specified' {
            Write-xProgress -Identity $script:id -DoNotIncrement
            (Get-xProgress -Identity $script:id).Counter | Should -Be 0
        }

        It 'Does not throw and does not call Write-Progress when -DoNotIncrement is used on the first call' {
            # Regression: Counter=0 combined with the display-block guard used to divide by zero.
            { Write-xProgress -Identity $script:id -DoNotIncrement } | Should -Not -Throw
            Should -Invoke Write-Progress -ModuleName xProgress -Times 0
        }
    }

    Context 'Stopwatch auto-start' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Test'
        }

        It 'Starts the stopwatch on the first increment' {
            Write-xProgress -Identity $script:id
            (Get-xProgress -Identity $script:id).Stopwatch.IsRunning | Should -BeTrue
        }

        It 'Does not start the stopwatch on the first increment when -DoNotStartTimer is specified' {
            Write-xProgress -Identity $script:id -DoNotStartTimer
            (Get-xProgress -Identity $script:id).Stopwatch.IsRunning | Should -BeFalse
        }
    }

    Context 'Write-Progress Id (regression)' {
        # Regression test for the bug where the auto-assigned ID silently came out $null.
        It 'Always calls Write-Progress with a non-null Id' {
            $id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Test'
            Write-xProgress -Identity $id
            Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter { $null -ne $Id }
        }
    }

    Context 'Throttling by ProgressInterval' {
        It 'Calls Write-Progress only on Counter -eq 1 or ProgressInterval boundaries' {
            $id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 3 -Activity 'Test'
            1..5 | ForEach-Object { Write-xProgress -Identity $id }
            # Counter 1 (first-call rule) and Counter 3 (3 % 3 -eq 0) should write; 2, 4, 5 should not.
            Should -Invoke Write-Progress -ModuleName xProgress -Times 2
        }
    }

    Context 'PercentComplete cap' {
        It 'Caps PercentComplete at 100 and warns when Counter exceeds Total' {
            $id = New-xProgress -ArrayToProcess (1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
            1..5 | ForEach-Object {
                Write-xProgress -Identity $id -WarningVariable +warnings -WarningAction SilentlyContinue
            }
            Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter { $PercentComplete -eq 100 }
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Status and CurrentOperation text' {
        It 'Uses the Specified Status when one has been set' {
            $id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Test'
            Set-xProgress -Identity $id -Status 'Final phase'
            Write-xProgress -Identity $id
            Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter { $Status -eq 'Final phase' }
        }

        It 'Uses the Specified CurrentOperation when one has been set' {
            $id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Test'
            Set-xProgress -Identity $id -CurrentOperation 'Cleaning up'
            Write-xProgress -Identity $id
            Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter { $CurrentOperation -eq 'Cleaning up' }
        }

        It 'Generates automatic CurrentOperation text mentioning the total when none is specified' {
            $id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Test'
            Write-xProgress -Identity $id
            Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter {
                $CurrentOperation -match 'Processing 1 through \d+ of 10'
            }
        }
    }
}
