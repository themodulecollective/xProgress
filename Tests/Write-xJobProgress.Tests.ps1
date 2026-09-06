#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

$CommandName = $MyInvocation.MyCommand.Name.Replace('.Tests.ps1', '')

BeforeAll {
    . "$PSScriptRoot/ModuleUnderTest.ps1"
    Import-Module -Name $manifestPath -Force

    # Polls until the job's own or first child job's Progress collection has at least
    # $Count records, or $TimeoutSeconds elapses. Real background jobs are async, so tests
    # poll instead of relying on a fixed sleep.
    function Wait-TestJobProgress
    {
        param(
            [System.Management.Automation.Job]$Job,
            [int]$Count = 1,
            [int]$TimeoutSeconds = 20
        )
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds)
        {
            $progress = if ($Job.ChildJobs.Count -gt 0) { $Job.ChildJobs[0].Progress } else { $Job.Progress }
            if ($progress.Count -ge $Count)
            {
                return
            }
            Start-Sleep -Milliseconds 100
        }
    }
}

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    BeforeEach {
        Mock -ModuleName xProgress Write-Progress { }
    }

    Context 'Validate parameters' {
        It 'Should have the expected parameters' {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Job')
            foreach ($kp in $knownParameters)
            {
                $kp | Should -BeIn $params
            }
        }
    }

    Context 'Single job, single activity' {
        BeforeEach {
            $script:job = Start-Job -ScriptBlock {
                Write-Progress -Activity 'Work' -PercentComplete 50
                Start-Sleep -Seconds 5
            }
            Wait-TestJobProgress -Job $script:job -Count 1
        }

        AfterEach {
            Remove-Job -Job $script:job -Force -ErrorAction SilentlyContinue
        }

        It 'Mirrors PercentComplete and assigns a non-null Id' {
            Write-xJobProgress -Job $script:job
            Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter {
                $PercentComplete -eq 50 -and $null -ne $Id
            }
        }

        It 'Uses a stable Id across repeated calls while the job is unfinished' {
            $script:capturedIds = @()
            Mock -ModuleName xProgress Write-Progress { $script:capturedIds += $Id }
            Write-xJobProgress -Job $script:job
            Write-xJobProgress -Job $script:job
            $script:capturedIds.Count | Should -Be 2
            ($script:capturedIds | Select-Object -Unique).Count | Should -Be 1
        }
    }

    Context 'Concurrent activities with parent/child nesting' {
        BeforeEach {
            $script:job = Start-Job -ScriptBlock {
                Write-Progress -Id 1 -Activity 'Outer' -PercentComplete 10
                Write-Progress -Id 2 -ParentId 1 -Activity 'Inner' -PercentComplete 20
                Start-Sleep -Seconds 5
            }
            Wait-TestJobProgress -Job $script:job -Count 2
        }

        AfterEach {
            Remove-Job -Job $script:job -Force -ErrorAction SilentlyContinue
        }

        It 'Mirrors both activities with distinct ids and the inner one parented to the outer one' {
            $script:capturedCalls = @()
            Mock -ModuleName xProgress Write-Progress {
                $script:capturedCalls += [pscustomobject]@{ Activity = $Activity; Id = $Id; ParentId = $ParentId }
            }
            Write-xJobProgress -Job $script:job
            $script:capturedCalls.Count | Should -Be 2

            $outer = $script:capturedCalls | Where-Object Activity -EQ 'Outer'
            $inner = $script:capturedCalls | Where-Object Activity -EQ 'Inner'
            $outer | Should -Not -BeNullOrEmpty
            $inner | Should -Not -BeNullOrEmpty
            $inner.Id | Should -Not -Be $outer.Id
            $inner.ParentId | Should -Be $outer.Id
        }
    }

    Context 'Zero-ChildJobs fallback' {
        It 'Uses the job''s own Progress stream when it has no ChildJobs' {
            $job = Start-Job -ScriptBlock { Write-Progress -Activity 'Work' -PercentComplete 75 }
            try
            {
                # Job.Progress can only be set once the job has left the Running state, so let
                # it finish naturally, then simulate a job type with no ChildJobs by moving the
                # child's progress up to the job itself and clearing ChildJobs (both are
                # supported, mutable members of System.Management.Automation.Job).
                Wait-Job -Job $job -Timeout 20 | Out-Null
                $job.Progress = $job.ChildJobs[0].Progress
                $job.ChildJobs.Clear()

                Write-xJobProgress -Job $job
                Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter { $PercentComplete -eq 75 }
            }
            finally
            {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Empty progress' {
        It 'Does not throw and does not call Write-Progress for a job that has not reported yet' {
            $job = Start-Job -ScriptBlock { Start-Sleep -Seconds 5 }
            try
            {
                { Write-xJobProgress -Job $job } | Should -Not -Throw
                Should -Invoke Write-Progress -ModuleName xProgress -Times 0
            }
            finally
            {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Completion cleanup' {
        It 'Completes the mirrored bar once the job finishes and does not re-emit on a later call' {
            $job = Start-Job -ScriptBlock { Write-Progress -Activity 'Almost done' -PercentComplete 99 }
            try
            {
                Wait-Job -Job $job -Timeout 20 | Out-Null
                $job.State | Should -Be 'Completed'

                Write-xJobProgress -Job $job
                Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter { $Completed -eq $true }

                { Write-xJobProgress -Job $job } | Should -Not -Throw
                Should -Invoke Write-Progress -ModuleName xProgress -Times 1 -ParameterFilter { $Completed -eq $true }

                $retired = & (Get-Module xProgress) { $script:JobProgressRetired.ContainsKey($args[0]) } $job.InstanceId.Guid
                $retired | Should -BeTrue
            }
            finally
            {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'ID isolation from xProgress instances' {
        It 'Never assigns a job progress Id that collides with a live xProgress instance Id' {
            $xpId = New-xProgress -ArrayToProcess (1..10) -ExplicitProgressInterval 1 -Activity 'Caller-driven'
            $xpAssignedId = (Get-xProgress -Identity $xpId).ID

            $job = Start-Job -ScriptBlock {
                Write-Progress -Activity 'Work' -PercentComplete 50
                Start-Sleep -Seconds 5
            }
            try
            {
                Wait-TestJobProgress -Job $job -Count 1
                $script:capturedIds = @()
                Mock -ModuleName xProgress Write-Progress { $script:capturedIds += $Id }
                Write-xJobProgress -Job $job
                $script:capturedIds | Should -Not -Contain $xpAssignedId
            }
            finally
            {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
