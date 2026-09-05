$script:ProgressTracker = @{}
$script:WriteProgressID = 628


Function New-xProgress
{
    <#
    .SYNOPSIS
        Initializes an instance of xProgress for later display using Write-xProgress
    .DESCRIPTION
        Initializes an instance of xProgress for later display using Write-xProgress.
        Automatically sets up counters, timers, and incremental progress tracking.
        Can show progress only at a selected interval to improve performance (write-progress is expensive).
    .EXAMPLE
        $xParams = @{
            ArrayToProcess             = $MyListOfItems
            CalculatedProgressInterval = '1Percent'
            Activity                   = 'Process MyListOfItems'
        }
        $xProgressID = New-xProgress @xParams

        Sets up xProgress to display progress for a looped operation on $MyListOfItems. When
        Write-xProgress is called will update progress at each one percent increment of
        processing and will use -activity as the activity for Write-Progress.
    .EXAMPLE
        $xParams = @{
            ArrayToProcess           = $MyListOfItems
            ExplicitProgressInterval = 5
            Activity                 = 'Process MyListOfItems'
        }
        $xProgressID = New-xProgress @xParams

        Sets up xProgress to display progress for a looped operation on $MyListOfItems. When
        Write-xProgress is called will update progress once for each 5 items of processing and
        will use -activity as the activity for Write-Progress.
        Will throw an error if MyListOfItems is less than 5 items.
    .EXAMPLE
        $ParentParams = @{
            ArrayToProcess             = @(1, 2, 3)
            CalculatedProgressInterval = 'Each'
            Activity                   = 'Multi-Stage Process'
        }
        $ParentID = New-xProgress @ParentParams

        $ChildParams = @{
            ArrayToProcess             = $MyListOfItems
            CalculatedProgressInterval = '1Percent'
            Activity                   = 'Process MyListOfItems'
            xParentIdentity            = $ParentID
        }
        $ChildID = New-xProgress @ChildParams

        Creates a nested parent/child pair of progress bars. The child bar is automatically
        indented beneath the parent in the PowerShell progress display. xProgress manages the
        Write-Progress ID relationship automatically.
    #>


    [cmdletbinding(DefaultParameterSetName = 'CI-MPC')]
    [OutputType([string])]
    param(
        [parameter(Mandatory, HelpMessage = 'The array of items this progress instance will track')]
        [psobject[]]$ArrayToProcess #The array of items to be processed
        ,
        [parameter(ParameterSetName = 'CI-MPC')]
        [parameter(ParameterSetName = 'CI-xPC')]
        [alias('CalculatedInterval','CPI')]
        [ValidateSet('1Percent','10Percent','20Percent','25Percent','Each')]
        # Select a progress interval. Default is 1 Percent (1Percent).
        [string]$CalculatedProgressInterval = '1Percent'
        ,
        [parameter(ParameterSetName = 'EI-MPC')]
        [parameter(ParameterSetName = 'EI-xPC')]
        [alias('ExplicitInterval','EPI')]
        # Specify an explicit item count at which to show progress.
        [int32]$ExplicitProgressInterval
        ,
        [parameter(Mandatory, HelpMessage = 'The main title to display for this progress bar')]
        # Displayed in the progress bar Activity field (passed through to Write-Progress -Activity).
        # This is the main title of the progress bar.
        [string]$Activity
        ,
        [parameter()]
        # Displayed in the progress bar Status field (passed through to Write-Progress -Status).
        # This is displayed below the Activity but above the progress bar. Overrides the
        # automatically generated xProgress status, which is NULL unless Parent/Child xProgress
        # instances are configured.
        [string]$Status
        ,
        # Displayed in the progress bar Status field (passed through to Write-Progress -Status).
        # This is displayed below the Activity but above the progress bar.
        # Overrides the automatically generated xProgress CurrentOperation.
        # Automatically generated Current Operation shows "Processing [CurrentFirstItemCount]
        # through [CurrentBatchCount] of [TotalItemsCount]"
        [parameter()]
        [string]$CurrentOperation
        ,
        [parameter()]
        # Manually set the Id for Write-Progress, if desired. Otherwise xProgress will
        # automatically set the ID to an incrementing value.
        [int32]$Id
        ,
        [parameter(Mandatory,ParameterSetName = 'CI-xPC',
            HelpMessage = 'The Identity of the parent xProgress instance this new instance nests under')]
        [parameter(Mandatory,ParameterSetName = 'EI-xPC',
            HelpMessage = 'The Identity of the parent xProgress instance this new instance nests under')]
        [alias('xPPID')]
        # Set another xProgress Instance as the parent of this new xProgress instance for
        # progress bar nesting
        [guid]$xParentIdentity
        ,
        [parameter(ParameterSetName = 'CI-MPC')]
        [parameter(ParameterSetName = 'EI-MPC')]
        # Manually set the ParentId for Write-Progress, if desired. Otherwise xProgress will
        # automatically set the ParentID to -1 (no parent) unless you are using the -xParent
        # parameter for xProgress managed ParentIDs.
        [int32]$ParentId
    )

    $ProgressGuid = $(New-Guid).guid

    $total = $ArrayToProcess.Count
    switch -Wildcard ($PSCmdlet.ParameterSetName)
    {
        'CI-*'
        {
            $Interval = Get-xProgressInterval -CalculatedProgressInterval $CalculatedProgressInterval -Total $total
        }
        'EI-*'
        {
            if ($ExplicitProgressInterval -gt $total)
            {
                $message = "ExplicitProgressInterval $ExplicitProgressInterval exceeds total count $total"
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.ArgumentException]::new($message),
                        'ExplicitProgressIntervalExceedsTotal',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $ExplicitProgressInterval
                    )
                )
            }
            else
            {
                $Interval = $ExplicitProgressInterval
            }
        }
        '*-MPC'
        {
            switch ($PSBoundParameters.ContainsKey('ParentID'))
            {
                $false
                {$ParentId = -1}
            }
        }
        '*-xPC'
        {
            $ParentID = $(Get-xProgress -Identity $xParentIdentity).ID
            $xPPID = $xParentIdentity.Guid
        }
    }

    $StatusType = switch ($PSBoundParameters.ContainsKey('Status'))
    {
        $true {'Specified'}
        $false {'Automatic'}
    }
    $CurrentOperationType = switch ($PSBoundParameters.ContainsKey('CurrentOperation'))
    {
        $true {'Specified'}
        $false {'Automatic'}
    }

    $xPi = [pscustomobject]@{
        PSTypeName           = 'xProgress.Instance'
        Identity             = $ProgressGUID
        Activity             = $Activity
        Status               = $Status
        CurrentOperation     = $CurrentOperation
        ProgressInterval     = $Interval
        Total                = $total
        Stopwatch            = [System.Diagnostics.Stopwatch]::New()
        Counter              = 0
        ParentID             = $ParentId
        xParentIdentity      = $xPPID
        ID                   = if ($PSBoundParameters.ContainsKey('Id'))
        {
            $Id
        }
        else
        {
            (++$script:WriteProgressID)
        }
        StatusType           = $StatusType
        CurrentOperationType = $CurrentOperationType
    }

    $script:ProgressTracker.$($ProgressGuid) = $xPi

    $xPi.Identity
}


Function Get-xProgress
{
    <#
    .SYNOPSIS
        Gets an xProgress instance based on the provided Identity or gets all current xProgress instances
    .DESCRIPTION
        Gets an xProgress configuration instance or all current xProgress configuration instances.
        Instances would have been created by a previous New-xProgress.
    .EXAMPLE
        Get-xProgress -Identity $xProgressID
        Returns the identified xProgress configuration instance if it exists
    #>
    [cmdletbinding()]
    [OutputType('xProgress.Instance')]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [guid[]]$Identity #GUID or GUID string provided from a previously run New-xProgress
    )
    begin
    {
        if (-not $MyInvocation.ExpectingInput -and $Identity.count -eq 0)
        {
            $script:ProgressTracker.Values
        }
    }
    process
    {
        foreach ($i in $Identity)
        {
            $script:ProgressTracker.$($i.Guid)
        }
    }
}


Function Get-xProgressTrackedInstance
{
    <#
    .SYNOPSIS
        Internal helper (not exported). Returns the tracked xProgress instance for a GUID, or $null
        with a warning if it isn't tracked.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory, HelpMessage = 'String form of the xProgress Identity GUID to look up')]
        [string]$ProgressGUID #string form of the xProgress Identity GUID to look up
    )
    if ($script:ProgressTracker.ContainsKey($ProgressGUID))
    {
        $script:ProgressTracker.$($ProgressGUID)
    }
    else
    {
        Write-Warning -Message "No xProgress Instance found for identity $ProgressGUID"
    }
}


Function Get-xProgressInterval
{
    <#
    .SYNOPSIS
        Internal helper (not exported). Resolves a CalculatedProgressInterval preset name and a
        total item count to a ProgressInterval integer.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory, HelpMessage = 'The named interval preset to resolve')]
        [ValidateSet('1Percent','10Percent','20Percent','25Percent','Each')]
        [string]$CalculatedProgressInterval #the named interval preset to resolve
        ,
        [parameter(Mandatory, HelpMessage = 'Total item count for the progress instance')]
        [int]$Total #total item count; used as the divisor for 'Each' and in the final Ceiling calculation
    )
    $divisor = switch ($CalculatedProgressInterval)
    {
        '1Percent'  {100}
        '10Percent' {10}
        '20Percent' {5}
        '25Percent' {4}
        'Each'      {$Total}
    }
    [math]::Ceiling($Total / $divisor)
}


Function Set-xProgress
{
    <#
    .SYNOPSIS
        Sets an xProgress instance based on the provided Identity(ies)
    .DESCRIPTION
        Sets an xProgress configuration instance or all specified xProgress instances. Instances
        would have been created by a previous New-xProgress.
    .EXAMPLE
        Set-xProgress -Identity $xProgressID -Status 'Final Phase'
        Sets the identified xProgress instance Status to the specified value 'Final Phase'
    .EXAMPLE
        Set-xProgress -Identity $xProgressID -AutomaticStatus
        Resets a previously specified Status back to automatic generation. Use after a
        stage-specific status is no longer relevant.
    .EXAMPLE
        Set-xProgress -Identity $xProgressID -CalculatedProgressInterval 10Percent
        Dynamically changes the progress update frequency to every 10% on an already-running
        instance. Useful when processing speed changes significantly mid-loop and you want to
        adjust update frequency without restarting.
    .EXAMPLE
        Set-xProgress -Identity $xProgressID -DecrementCounter
        Decrements the counter by one. Useful when an iteration is retried and the counter should
        not advance for that item.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,
            HelpMessage = 'GUID or GUID string of the xProgress instance to update')]
        [guid[]]$Identity #GUID or GUID string provided from a previously run New-xProgress
        ,
        [parameter()]
        # Displayed in the progress bar Activity field (passed through to Write-Progress
        # -Activity). This is the main title of the progress bar.
        [string]$Activity
        ,
        [parameter()]
        # Displayed in the progress bar Status field (passed through to Write-Progress -Status).
        # This is displayed below the Activity but above the progress bar. Overrides the
        # automatically generated xProgress status, which is NULL unless Parent/Child xProgress
        # instances are configured.
        [string]$Status
        ,
        [parameter()]
        # Displayed in the progress bar Status field (passed through to Write-Progress -Status).
        # This is displayed below the Activity but above the progress bar. Overrides the
        # automatically generated xProgress CurrentOperation.
        [string]$CurrentOperation
        ,
        [parameter()]
        [switch]$AutomaticStatus #Resets a previously specified Status back to automatic generation
        ,
        [parameter()]
        # Resets a previously specified CurrentOperation back to automatic generation
        [switch]$AutomaticCurrentOperation
        ,
        [parameter()]
        # Decrements the counter by one; use when a retried iteration should not advance the counter
        [switch]$DecrementCounter
        ,
        [parameter()]
        [alias('CalculatedInterval','CPI')]
        [ValidateSet('1Percent','10Percent','20Percent','25Percent','Each')]
        # Dynamically changes the progress update frequency on an already-running xProgress instance
        [string]$CalculatedProgressInterval
        ,
        [parameter()]
        [alias('ExplicitInterval','EPI')]
        # Dynamically changes the progress update frequency to a fixed item count on an
        # already-running xProgress instance
        [int32]$ExplicitProgressInterval
    )

    process
    {
        foreach ($i in $Identity)
        {
            $xPi = Get-xProgress -Identity $i
            switch ($PSBoundParameters.Keys)
            {
                'Activity'
                {
                    $xPi.Activity = $PSBoundParameters.Activity
                }
                'Status'
                {
                    $xPi.Status = $Status
                    $xPi.StatusType = 'Specified'
                }
                'CurrentOperation'
                {
                    $xPi.CurrentOperation = $CurrentOperation
                    $xPi.CurrentOperationType = 'Specified'
                }
                'AutomaticStatus'
                {
                    if ($true -eq $AutomaticStatus)
                    {
                        $xPi.StatusType = 'Automatic'
                    }
                }
                'AutomaticCurrentOperation'
                {
                    if ($true -eq $AutomaticCurrentOperation)
                    {
                        $xPi.CurrentOperationType = 'Automatic'
                    }
                }
                'DecrementCounter'
                {
                    if ($true -eq $DecrementCounter)
                    {
                        if ($xPi.Counter -gt 0)
                        {
                            $xPi.Counter--
                        }
                        else
                        {
                            $message = "Counter for $($xPi.Identity) already at $($xPi.Counter); decrement skipped"
                            Write-Warning -Message $message
                        }
                    }
                }
                'CalculatedProgressInterval'
                {
                    $intervalParams = @{
                        CalculatedProgressInterval = $CalculatedProgressInterval
                        Total                      = $xPi.Total
                    }
                    $xPi.ProgressInterval = Get-xProgressInterval @intervalParams
                }
                'ExplicitProgressInterval'
                {
                    if ($ExplicitProgressInterval -gt $xPi.Total)
                    {
                        $total = $xPi.Total
                        $message = "ExplicitProgressInterval $ExplicitProgressInterval exceeds total $total;" +
                            ' not changed'
                        Write-Warning -Message $message
                    }
                    else
                    {
                        $xPi.ProgressInterval = $ExplicitProgressInterval
                    }
                }
            }
        }
    }
}


Function Write-xProgress
{
    <#
    .SYNOPSIS
        Writes powershell progress output using Write-Progress based on an instance of xProgress
        created using New-xProgress
    .DESCRIPTION
        Writes powershell progress output using Write-Progress based on a previous New-xProgress
        identity. If the Progress instance timer is not started, this also starts the timer for
        the first item in the counter.
    .EXAMPLE
        Write-xProgress -Identity $xProgressID
        calls Write-Progress with previously defined activity and automatically generated
        counter, progress, and seconds remaining
    .EXAMPLE
        Write-xProgress -Identity $xProgressID
        Set-xProgress -Identity $xProgressID -CurrentOperation 'Cleanup'
        Write-xProgress -Identity $xProgressID -DoNotIncrement
        Updates the progress display mid-item (e.g. to show a phase change) without advancing the
        counter. The first Write-xProgress increments and shows initial progress; the second
        refreshes the display with the new CurrentOperation but does not count the item twice.
    .EXAMPLE
        Start-xProgress -Identity $xProgressID
        Write-xProgress -Identity $xProgressID -DoNotStartTimer
        Use -DoNotStartTimer when you have already started the stopwatch manually via
        Start-xProgress. Prevents Write-xProgress from attempting to start a timer that is
        already running.
    #>

    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,
            HelpMessage = 'GUID or GUID string of the xProgress instance to write progress for')]
        [guid[]]$Identity #GUID or GUID string provided from a previously run New-xProgress
        ,
        [parameter()]
        # Do not increment the progress counter - for situations where you call Write-xProgress
        # more than once during the processing of an item, for example, to update status or
        # activity, but do not want to increment the counter.
        [switch]$DoNotIncrement
        ,
        # Use in a case where you are writing progress but don't want to do the initial start of
        # the timer for the progress instance
        [parameter()]
        [switch]$DoNotStartTimer
    )

    process
    {
        foreach ($i in $Identity)
        {
            $ProgressGUID = $i.guid #set the ProgressGUID to the string represenation of the Identity GUID
            switch ($Script:ProgressTracker.containsKey($ProgressGUID))
            {
                $true
                {
                    $xPi = $script:ProgressTracker.$($ProgressGUID)
                }
                $false
                {
                    $message = "No xProgress Instance found for identity $ProgressGUID"
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::new(
                            [System.Management.Automation.ItemNotFoundException]::new($message),
                            'xProgressInstanceNotFound',
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $ProgressGUID
                        )
                    )
                }
            }
            switch ($DoNotIncrement)
            {
                $true
                {}
                $false
                {$xPi.Counter++} #advance the counter
            }
            $counter = $xPi.Counter #capture the current counter
            $progressInterval = $xPi.ProgressInterval #get the progressInterval for the modulus check
            #start the timer when the first item is processed
            if ($counter -eq 1 -and $false -eq $xPi.Stopwatch.IsRunning -and $true -ne $DoNotStartTimer)
            {
                $xPi.Stopwatch.Start()
            }

            if (($counter % $progressInterval -eq 0 -or $counter -eq 1) -and $counter -gt 0)
            {
                # modulus check passed so write-progress this time
                $elapsedSeconds = [math]::Ceiling($xPi.Stopwatch.elapsed.TotalSeconds)
                $secondsPerItem = [math]::Ceiling($elapsedSeconds / $counter)
                $secondsRemaining = $($xPi.total - $counter) * $secondsPerItem
                $progressItem = [Math]::Min($counter + $progressInterval - 1, $xPi.total)
                $CurrentOperation = switch ($xPi.CurrentOperationType)
                {
                    'Automatic' {"Processing $counter through $progressItem of $($xPi.total)"}
                    'Specified' {$xPi.CurrentOperation}
                }
                $wpParams = @{
                    Activity         = $xPi.Activity
                    CurrentOperation = $CurrentOperation
                    PercentComplete  =
                        switch ($counter / $xPi.total * 100)
                        {
                            {$_ -gt 100}
                            {
                                100
                                Write-Warning -Message 'PercentComplete value over 100 has been suppressed'
                            }
                            default
                            {$_}
                        }
                    SecondsRemaining = $secondsRemaining
                    ID               = $xPi.ID
                    ParentID         = $xPi.ParentID
                }
                switch ($xPi.StatusType)
                {
                    'Specified'
                    {
                        $wpParams.status = $xPi.Status
                    }
                    'Automatic'
                    {
                        # do something here with Parent/Child scenarios?
                    }
                }
                Write-Progress @wpParams
            }
        }
    }
}


Function Complete-xProgress
{
    <#
    .SYNOPSIS
        Completes xProgress for a specific xProgress identity created by New-xProgress
    .DESCRIPTION
        Completes xProgress for a specific xProgress identity created by New-xProgress.
        Removes the progress bar display in Powershell by calling Write-Progress with -Complete parameter.
        Removes the xProgress identity from xProgress module memory
    .EXAMPLE
        Complete-xProgress -Identity $xProgressId
        removes the progress bar from display and removes the xProgressId from xProgress module memory
    #>


    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,
            HelpMessage = 'GUID or GUID string of the xProgress instance to complete')]
        [guid[]]$Identity #the xProgress Identity to complete
    )

    process
    {
        foreach ($i in $Identity)
        {
            $ProgressGUID = $i.guid #set the ProgressGUID to the string represenation of the Identity GUID
            $xPi = Get-xProgressTrackedInstance -ProgressGUID $ProgressGUID
            if ($null -eq $xPi) { continue }
            $xPi.Stopwatch.Stop() #stop the stopwatch
            $elapsedSeconds = [math]::Ceiling($xPi.Stopwatch.elapsed.TotalSeconds)
            $wpParams = @{
                Activity         = $xPi.Activity
                PercentComplete  = 100
                SecondsRemaining = 0
                Id               = $xPi.Id
                ParentID         = $xPi.ParentId
            }
            #Remove progress bar
            Write-Progress @wpParams -Completed
            Write-Information -MessageData "Completing xProgress Instance: $ProgressGUID"
            $elapsedProperty = @{n = 'ElapsedSeconds'; e = {$elapsedSeconds}}
            Write-Information -MessageData $($xPi | Select-Object -Property *, $elapsedProperty)
            #Remove Progress Identity GUID
            $script:ProgressTracker.remove($ProgressGUID)
        }
    }
}


Function Start-xProgress
{
    <#
    .SYNOPSIS
        Starts the stopwatch for an xProgress instance
    .DESCRIPTION
        Starts the stopwatch for an xProgress instance. Use this to begin timing before
        the first Write-xProgress call, or after creating an instance for later use.
        When using Start-xProgress, pass -DoNotStartTimer to Write-xProgress to prevent
        it from attempting to auto-start a timer that is already running.
    .EXAMPLE
        Start-xProgress -Identity $xProgressID
        Starts the stopwatch for the identified xProgress instance
    .EXAMPLE
        $xParams = @{
            ArrayToProcess             = $MyListOfItems
            CalculatedProgressInterval = '1Percent'
            Activity                   = 'Process MyListOfItems'
        }
        $xProgressID = New-xProgress @xParams
        Start-xProgress -Identity $xProgressID
        foreach ($i in $MyListOfItems) { Write-xProgress -Identity $xProgressID -DoNotStartTimer }
        Complete-xProgress -Identity $xProgressID

        Starts the timer before the loop so that any pre-loop setup time is excluded from
        elapsed calculations. -DoNotStartTimer prevents Write-xProgress from re-starting the
        already-running stopwatch.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,
            HelpMessage = 'GUID or GUID string of the xProgress instance to start timing')]
        [guid[]]$Identity #GUID or GUID string provided from a previously run New-xProgress
    )

    process
    {
        foreach ($i in $Identity)
        {
            $ProgressGUID = $i.guid
            $xPi = Get-xProgressTrackedInstance -ProgressGUID $ProgressGUID
            if ($null -eq $xPi) { continue }
            if ($xPi.Stopwatch.IsRunning)
            {
                Write-Warning -Message "Stopwatch for xProgress Instance $ProgressGUID is already running"
            }
            else
            {
                $xPi.Stopwatch.Start()
            }
        }
    }
}


Function Suspend-xProgress
{
    <#
    .SYNOPSIS
        Suspends (pauses) the stopwatch for an xProgress instance
    .DESCRIPTION
        Pauses the stopwatch for an xProgress instance. Use Resume-xProgress to continue timing.
        Useful for excluding wait times, external operations, or human input from elapsed time
        and time-remaining calculations.
    .EXAMPLE
        Suspend-xProgress -Identity $xProgressID
        Pauses the stopwatch for the identified xProgress instance
    .EXAMPLE
        Suspend-xProgress -Identity $xProgressID
        Start-Sleep -Seconds 30
        Resume-xProgress -Identity $xProgressID
        Excludes a 30-second wait from elapsed time so it does not inflate the time-remaining estimate.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,
            HelpMessage = 'GUID or GUID string of the xProgress instance to suspend timing for')]
        [guid[]]$Identity #GUID or GUID string provided from a previously run New-xProgress
    )

    process
    {
        foreach ($i in $Identity)
        {
            $ProgressGUID = $i.guid
            $xPi = Get-xProgressTrackedInstance -ProgressGUID $ProgressGUID
            if ($null -eq $xPi) { continue }
            if ($xPi.Stopwatch.IsRunning)
            {
                $xPi.Stopwatch.Stop()
            }
            else
            {
                Write-Warning -Message "Stopwatch for xProgress Instance $ProgressGUID is not running"
            }
        }
    }
}


Function Resume-xProgress
{
    <#
    .SYNOPSIS
        Resumes a suspended stopwatch for an xProgress instance
    .DESCRIPTION
        Resumes a previously suspended stopwatch for an xProgress instance.
        Elapsed time continues accumulating from where it was paused; the wait period is excluded.
    .EXAMPLE
        Resume-xProgress -Identity $xProgressID
        Resumes the stopwatch for the identified xProgress instance
    .EXAMPLE
        Suspend-xProgress -Identity $xProgressID
        Invoke-SlowExternalOperation
        Resume-xProgress -Identity $xProgressID
        Write-xProgress -Identity $xProgressID -DoNotIncrement
        Resumes timing after an external operation and refreshes the progress display without
        advancing the counter.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,
            HelpMessage = 'GUID or GUID string of the xProgress instance to resume timing for')]
        [guid[]]$Identity #GUID or GUID string provided from a previously run New-xProgress
    )

    process
    {
        # Resuming is identical to starting - both start a stopped stopwatch and warn otherwise.
        Start-xProgress -Identity $Identity
    }
}

New-Alias -Name Initialize-xProgress -Value New-xProgress