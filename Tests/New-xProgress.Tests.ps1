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
            $knownParameters = @(
                'ArrayToProcess', 'CalculatedProgressInterval', 'ExplicitProgressInterval',
                'Activity', 'Status', 'CurrentOperation', 'Id', 'xParentIdentity', 'ParentId'
            )
            foreach ($kp in $knownParameters)
            {
                $kp | Should -BeIn $params
            }
        }
    }

    Context 'ExplicitProgressInterval validation' {
        It 'Throws when ExplicitProgressInterval is greater than the array total' {
            { New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 5 -Activity 'Test' } |
                Should -Throw
        }

        It 'Does not throw when ExplicitProgressInterval is less than or equal to the array total' {
            { New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 3 -Activity 'Test' } |
                Should -Not -Throw
        }
    }

    Context 'Auto-assigned ID' {
        # Regression test: the else branch of the ID assignment used a bare `++$script:WriteProgressID`
        # as the last statement of an if/else value-capturing script block. PowerShell's increment
        # operator does not emit its result in that context, so the auto-assigned ID silently came out
        # $null, which Write-Progress later rejected.
        It 'Is never null or empty' {
            $id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
            $instance = Get-xProgress -Identity $id
            $instance.ID | Should -Not -BeNullOrEmpty
        }

        It 'Is an integer' {
            $id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
            $instance = Get-xProgress -Identity $id
            $instance.ID | Should -BeOfType [int]
        }

        It 'Is unique and sequential across consecutive calls' {
            $id1 = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'First'
            $id2 = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Second'
            $instance1 = Get-xProgress -Identity $id1
            $instance2 = Get-xProgress -Identity $id2
            $instance2.ID | Should -Be ($instance1.ID + 1)
        }
    }

    Context 'Explicit -Id parameter' {
        It 'Honors an explicitly provided Id instead of auto-assigning one' {
            $id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test' -Id 9999
            (Get-xProgress -Identity $id).ID | Should -Be 9999
        }
    }

    Context 'Parent linkage via xParentIdentity' {
        # Regression test: because $ParentId is typed [int32], the parent's null ID (from the bug
        # above) was silently coerced to 0 instead of surfacing as an error - so this pins down the
        # same root cause from a different angle.
        It "Sets the child's ParentID to the parent's ID" {
            $parentId = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Parent'
            $childId = New-xProgress -ArrayToProcess @(1, 2) -ExplicitProgressInterval 1 -Activity 'Child' -xParentIdentity $parentId

            $parent = Get-xProgress -Identity $parentId
            $child = Get-xProgress -Identity $childId

            $child.ParentID | Should -Be $parent.ID
        }

        It "Sets the child's xParentIdentity to the parent's GUID" {
            $parentId = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Parent'
            $childId = New-xProgress -ArrayToProcess @(1, 2) -ExplicitProgressInterval 1 -Activity 'Child' -xParentIdentity $parentId

            $child = Get-xProgress -Identity $childId
            $child.xParentIdentity | Should -Be $parentId
        }
    }

    Context 'Manual ParentId parameter' {
        It 'Defaults ParentId to -1 when not specified' {
            $id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
            (Get-xProgress -Identity $id).ParentID | Should -Be -1
        }

        It 'Honors an explicitly provided ParentId' {
            $id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test' -ParentId 42
            (Get-xProgress -Identity $id).ParentID | Should -Be 42
        }
    }

    Context 'CalculatedProgressInterval divisor math' {
        It 'Computes ProgressInterval as Ceiling(Total / <Divisor>) for <CalculatedProgressInterval>' -ForEach @(
            @{CalculatedProgressInterval = '1Percent'; Divisor = 100 }
            @{CalculatedProgressInterval = '10Percent'; Divisor = 10 }
            @{CalculatedProgressInterval = '20Percent'; Divisor = 5 }
            @{CalculatedProgressInterval = '25Percent'; Divisor = 4 }
        ) {
            $total = 37
            $id = New-xProgress -ArrayToProcess (1..$total) -CalculatedProgressInterval $CalculatedProgressInterval -Activity 'Test'
            (Get-xProgress -Identity $id).ProgressInterval | Should -Be ([math]::Ceiling($total / $Divisor))
        }

        It "Computes ProgressInterval as 1 (show every item) when CalculatedProgressInterval is 'Each'" {
            # 'Each' uses the total itself as the divisor: Ceiling(Total / Total) = 1
            $total = 37
            $id = New-xProgress -ArrayToProcess (1..$total) -CalculatedProgressInterval Each -Activity 'Test'
            (Get-xProgress -Identity $id).ProgressInterval | Should -Be 1
        }
    }

    Context 'Returned Identity' {
        It 'Returns a value parseable as a GUID' {
            $id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
            { [guid]::Parse($id) } | Should -Not -Throw
        }
    }
}
