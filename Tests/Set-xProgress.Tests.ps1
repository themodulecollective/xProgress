#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

$CommandName = $MyInvocation.MyCommand.Name.Replace('.Tests.ps1', '')

BeforeAll {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    Import-Module -Name $manifestPath -Force
    Mock -ModuleName xProgress Write-Progress { }
}

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context 'Validate parameters' {
        It 'Should have the expected parameters' {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @(
                'Identity', 'Activity', 'Status', 'CurrentOperation', 'AutomaticStatus',
                'AutomaticCurrentOperation', 'DecrementCounter', 'CalculatedProgressInterval',
                'ExplicitProgressInterval'
            )
            foreach ($kp in $knownParameters)
            {
                $kp | Should -BeIn $params
            }
        }
    }

    Context 'Activity, Status, and CurrentOperation' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Original'
        }

        It 'Sets Activity' {
            Set-xProgress -Identity $script:id -Activity 'Updated'
            (Get-xProgress -Identity $script:id).Activity | Should -Be 'Updated'
        }

        It 'Sets Status and marks StatusType as Specified' {
            Set-xProgress -Identity $script:id -Status 'Final phase'
            $instance = Get-xProgress -Identity $script:id
            $instance.Status | Should -Be 'Final phase'
            $instance.StatusType | Should -Be 'Specified'
        }

        It 'AutomaticStatus resets StatusType back to Automatic' {
            Set-xProgress -Identity $script:id -Status 'Final phase'
            Set-xProgress -Identity $script:id -AutomaticStatus
            (Get-xProgress -Identity $script:id).StatusType | Should -Be 'Automatic'
        }

        It 'Sets CurrentOperation and marks CurrentOperationType as Specified' {
            Set-xProgress -Identity $script:id -CurrentOperation 'Cleaning up'
            $instance = Get-xProgress -Identity $script:id
            $instance.CurrentOperation | Should -Be 'Cleaning up'
            $instance.CurrentOperationType | Should -Be 'Specified'
        }

        It 'AutomaticCurrentOperation resets CurrentOperationType back to Automatic' {
            Set-xProgress -Identity $script:id -CurrentOperation 'Cleaning up'
            Set-xProgress -Identity $script:id -AutomaticCurrentOperation
            (Get-xProgress -Identity $script:id).CurrentOperationType | Should -Be 'Automatic'
        }
    }

    Context 'DecrementCounter' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
            Write-xProgress -Identity $script:id
        }

        It 'Decrements the counter when Counter is greater than 0' {
            (Get-xProgress -Identity $script:id).Counter | Should -Be 1
            Set-xProgress -Identity $script:id -DecrementCounter
            (Get-xProgress -Identity $script:id).Counter | Should -Be 0
        }

        It 'Warns and does not go negative when Counter is already 0' {
            Set-xProgress -Identity $script:id -DecrementCounter
            Set-xProgress -Identity $script:id -DecrementCounter -WarningVariable warnings -WarningAction SilentlyContinue
            (Get-xProgress -Identity $script:id).Counter | Should -Be 0
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CalculatedProgressInterval' {
        It 'Recomputes ProgressInterval for the new interval' {
            $id = New-xProgress -ArrayToProcess (1..40) -CalculatedProgressInterval 1Percent -Activity 'Test'
            Set-xProgress -Identity $id -CalculatedProgressInterval 10Percent
            (Get-xProgress -Identity $id).ProgressInterval | Should -Be ([math]::Ceiling(40 / 10))
        }
    }

    Context 'ExplicitProgressInterval' {
        It 'Changes ProgressInterval when the value is less than or equal to Total' {
            $id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Test'
            Set-xProgress -Identity $id -ExplicitProgressInterval 5
            (Get-xProgress -Identity $id).ProgressInterval | Should -Be 5
        }

        It 'Warns and leaves ProgressInterval unchanged when the value is greater than Total' {
            $id = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Test'
            Set-xProgress -Identity $id -ExplicitProgressInterval 20 -WarningVariable warnings -WarningAction SilentlyContinue
            (Get-xProgress -Identity $id).ProgressInterval | Should -Be 1
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
