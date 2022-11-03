$script:ProgressTracker = @{}
$script:WriteProgressID = 628

Function Initialize-xProgress
{
    <#
    .SYNOPSIS
        Initializes an instance of xProgress for later display using Write-xProgess
    .DESCRIPTION
        Initializes an instance of xProgress for later display using Write-xProgess.
        Automatically sets up counters, timers, and incremental progress tracking.
        Can show progress only at a selected interval to improve performance (write-progress is expensive).
    .EXAMPLE
        $xProgressID = Initialize-xProgress -ArrayToProcess $MyListOfItems -CalculatedProgressInterval 1Percent -Activity "Process MyListOfItems"
        Sets up xProgress to display progress for a looped operation on $MyListOfItems.  When Write-xProgress is called will update progress at each one percent increment of processing and will use -activity as the activity for Write-Progress.
    .EXAMPLE
        $xProgressID = Initialize-xProgress -ArrayToProcess $MyListOfItems -ExplicitProgressInterval 5 -Activity "Process MyListOfItems"
        Sets up xProgress to display progress for a looped operation on $MyListOfItems.  When Write-xProgress is called will update progress once for each 5 items of processing and will use -activity as the activity for Write-Progress.
        Will throw an error if MyListOfItems is less than 5 items.
    #>


    [cmdletbinding(DefaultParameterSetName = 'CI-MPC')]
    param(
        [parameter(Mandatory)]
        [psobject[]]$ArrayToProcess #The array of items to be processed
        ,
        [parameter(ParameterSetName = 'CI-MPC')]
        [parameter(ParameterSetName = 'CI-xPC')]
        [alias('CalculatedInterval','CPI')]
        [ValidateSet('1Percent','10Percent','20Percent','25Percent','Each')]
        [string]$CalculatedProgressInterval = '1Percent' #Select a progress interval.  Default is 1 Percent (1Percent).
        ,
        [parameter(ParameterSetName = 'EI-MPC')]
        [parameter(ParameterSetName = 'EI-xPC')]
        [alias('ExplicitInterval','EPI')]
        [int32]$ExplicitProgressInterval #specify an explicity item count at which to show progress.
        ,
        [parameter(Mandatory)]
        [string]$Activity #Displayed in the progress bar Activity field (passed through to Write-Progress -Activity). This is the main title of the progress bar.
        ,
        [parameter()]
        [string]$Status #Displayed in the progress bar Status field (passed through to Write-Progress -Status). This is displayed below the Activity but above the progress bar. Overrides the automatically generated xProgress status which is NULL unless Parent/Child xProgress instances are configured.
        ,
        [parameter()]
        [string]$CurrentOperation #Displayed in the progress bar Status field (passed through to Write-Progress -Status). This is displayed below the Activity but above the progress bar. Overrides the automatically generated xProgress CurrentOperation.
        ,
        [parameter()]
        [int32]$Id #Manually set the Id for Write-Progress, if desired.  Otherwise xProgress will automatically set the ID to an incrementing value.
        ,
        [parameter(ParameterSetName = 'CI-MPC')]
        [parameter(ParameterSetName = 'EI-MPC')]
        [int32]$ParentId #Manually set the ParentId for Write-Progress, if desired. Otherwise xProgress will automatically set the ParentID to -1 (no parent) unless you are using the -xParent parameter for xProgress managed ParentIDs.
        ,
        [parameter(Mandatory,ParameterSetName = 'CI-xPC')]
        [parameter(Mandatory,ParameterSetName = 'EI-xPC')]
        [alias('xPPID')]
        [guid]$xParentIdentity #Set another xProgress Instance as the parent of this new xProgress instance for progress bar nesting
    )

    $ProgressGuid = $(New-Guid).guid

    $total = $ArrayToProcess.Count
    switch -Wildcard ($PSCmdlet.ParameterSetName)
    {
        'CI-*'
        {
            $divisor = switch ($CalculatedProgressInterval)
            {
                '1Percent'
                {100}
                '10Percent'
                {10}
                '20Percent'
                {5}
                '25Percent'
                {4}
                'Each'
                {$total}
            }
            $Interval = [math]::Ceiling($total / $divisor)
        }
        'EI-*'
        {
            if ($ExplicitProgressInterval -gt $total)
            {
                throw ("ExplicitProgressInterval $ExplicitProgressInterval is greater than the provided ArrayToProcess total count: $total")
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

    $StatusType = switch ($PSBoundParameters.ContainsKey('Status')) {$true {'Specified'} $false {'Automatic'}}
    $CurrentOperationType = switch ($PSBoundParameters.ContainsKey('CurrentOperation')) {$true {'Specified'} $false {'Automatic'}}

    $xPi = [pscustomobject]@{
        Identity             = $ProgressGUID
        Activity             = $Activity
        Status               = $Status
        CurrentOperation     = $CurrentOperation
        ProgressInterval     = $Interval
        Total                = $total
        Stopwatch            = [System.Diagnostics.Stopwatch]::StartNew()
        Counter              = 0
        ParentID             = $ParentId
        xParentIdentity      = $xPPID
        ID                   = ++$script:WriteProgressID
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
        Gets an xProgress configuration instance or all current xProgress configuration instances.  Instances would have been created by a previous Initialize-xProgress.
    .EXAMPLE
        Get-xProgress -Identity $xProgressID
        Returns the identified xProgress configuration instance if it exists
    #>
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [guid[]]$Identity #GUID or GUID string provided from a previously run Initialize-xProgress
    )
    begin
    {
        if (-not $MyInvocation.ExpectingInput -and $Identity.count -eq 0)
        {
            $script:ProgressTracker.keys.foreach({$script:ProgressTracker.$_})
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

Function Set-xProgress
{
    <#
    .SYNOPSIS
        Sets an xProgress instance based on the provided Identity(ies)
    .DESCRIPTION
        Sets an xProgress configuration instance or all specified xProgress instances.  Instances would have been created by a previous Initialize-xProgress.
    .EXAMPLE
        Set-xProgress -Identity $xProgressID -Status 'Final Phase'
        Sets the identified xProgress instance Status to the specified value 'Final Phase'
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [guid[]]$Identity #GUID or GUID string provided from a previously run Initialize-xProgress
        ,
        [parameter()]
        [string]$Activity #Displayed in the progress bar Activity field (passed through to Write-Progress -Activity). This is the main title of the progress bar.
        ,
        [parameter()]
        [string]$Status #Displayed in the progress bar Status field (passed through to Write-Progress -Status). This is displayed below the Activity but above the progress bar. Overrides the automatically generated xProgress status which is NULL unless Parent/Child xProgress instances are configured.
        ,
        [parameter()]
        [string]$CurrentOperation #Displayed in the progress bar Status field (passed through to Write-Progress -Status). This is displayed below the Activity but above the progress bar. Overrides the automatically generated xProgress CurrentOperation.
        ,
        [parameter()]
        [switch]$AutomaticStatus
        ,
        [parameter()]
        [switch]$AutomaticCurrentOperation
        ,
        [parameter()]
        [switch]$DecrementCounter
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
                    $xPI.StatusType = 'Specified'
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
                        $xPi.Counter--
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
        Writes powershell progress output using Write-Progress based on an instance of xProgress created using Initialize-xProgress
    .DESCRIPTION
        Writes powershell progress output using Write-Progress based on a previous Initialize-xProgress identity
    .EXAMPLE
        Write-xProgress -Identity $xProgressID
        calls Write-Progress with previously defined activity and automatically generated counter, progress, and seconds remaining
    #>

    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [guid[]]$Identity #GUID or GUID string provided from a previously run Initialize-xProgress
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
                    throw("No xProgress Instance found for identity $ProgressGUID")
                }
            }
            $xPi.Counter++ #advance the counter
            $counter = $xPi.Counter #capture the current counter
            $progressInterval = $xPi.ProgressInterval #get the progressInterval for the modulus check

            if ($counter % $progressInterval -eq 0 -or $counter -eq 1)
            {
                #modulus check passed so w
                $elapsedSeconds = [math]::Ceiling($xPi.Stopwatch.elapsed.TotalSeconds)
                $secondsPerItem = [math]::Ceiling($elapsedSeconds/$counter)
                $secondsRemaining = $($xPi.total - $counter) * $secondsPerItem
                $CurrentOperation = switch ($xPi.CurrentOperationType) {'Automatic' {"Processing $counter through $progressItem of $($xPi.total)"} 'Specified' {$xProgessInstance.CurrentOperation} }
                $progressItem = $counter + $progressInterval - 1
                $wpParams = @{
                    Activity         = $xPi.Activity
                    CurrentOperation = $CurrentOperation
                    PercentComplete  = $counter/$xPi.total * 100
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
        Completes xProgress for a specific xProgress identity created by Initialize-xProgress
    .DESCRIPTION
        Completes xProgress for a specific xProgress identity created by Initialize-xProgress.
        Removes the progress bar display in Powershell by calling Write-Progress with -Complete parameter.
        Removes the xProgress identity from xProgress module memory
    .EXAMPLE
        Complete-xProgress -Identity $xProgressId
        removes the progress bar from display and removes the xProgressId from xProgress module memory
    #>


    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [guid[]]$Identity #the xProgress Identity to complete
    )

    process
    {
        foreach ($i in $Identity)
        {
            $ProgressGUID = $i.guid #set the ProgressGUID to the string represenation of the Identity GUID
            $xPi = $script:ProgressTracker.$($ProgressGUID)
            $xPi.Stopwatch.Stop() #stop the stopwatch
            $elapsedSeconds = [math]::Ceiling($xProgessInstance.Stopwatch.elapsed.TotalSeconds)
            $wpParams = @{
                Activity         = $xPi.Activity
                PercentComplete  = 100
                SecondsRemaining = 0
                Id               = $Script:ProgressTracker.$($ProgressGUID).Id
                ParentID         = $Script:ProgressTracker.$($ProgressGUID).ParentId
            }
            #Remove progress bar
            Write-Progress @wpParams -Completed
            Write-Information -MessageData "Completing xProgress Instance: $ProgressGUID"
            $xPi | Select-Object -Property *,@{n = 'ElapsedSeconds'; e = {$elapsedSeconds} } | Write-Information
            #Remove Progress Identity GUID
            $script:ProgressTracker.remove($ProgressGUID)
        }
    }

}