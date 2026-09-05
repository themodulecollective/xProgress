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

    Context 'Returning a specific instance' {
        BeforeEach {
            $script:id = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Test'
        }

        It 'Returns the matching instance for a known Identity' {
            $result = Get-xProgress -Identity $script:id
            $result.Identity | Should -Be $script:id
        }

        It 'Accepts Identity from the pipeline' {
            $result = $script:id | Get-xProgress
            $result.Identity | Should -Be $script:id
        }

        It 'Returns nothing for an unknown Identity' {
            $unknown = [guid]::NewGuid()
            Get-xProgress -Identity $unknown | Should -BeNullOrEmpty
        }
    }

    Context 'Returning all tracked instances' {
        BeforeEach {
            $script:id1 = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'First'
            $script:id2 = New-xProgress -ArrayToProcess @(1, 2, 3) -ExplicitProgressInterval 1 -Activity 'Second'
        }

        It 'Returns all tracked instances when called with no arguments' {
            $result = Get-xProgress
            $result.Identity | Should -Contain $script:id1
            $result.Identity | Should -Contain $script:id2
        }
    }
}
