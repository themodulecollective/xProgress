$script:ProgressTracker = @{}

Function Write-xProgress
{
    <#
    .SYNOPSIS
        Writes powershell progress output using Write-Progress based on a previous Initialize-xProgress identity
    .DESCRIPTION
        Writes powershell progress output using Write-Progress based on a previous Initialize-xProgress identity
    .EXAMPLE
        Write-xProgress -Identity $xProgressID
        calls Write-Progress with previously defined activity and automatically generated counter, progress, and seconds remaining
    #>


    [cmdletbinding()]
    param(
        [guid]$Identity #GUID or GUID string provided from a previously run Initialize-xProgress
    )

    $ProgressGUID = $Identity.guid #set the ProgressGUID to the string represenation of the Identity GUID
    if (-not $Script:ProgressTracker.containsKey($ProgressGUID))
    {
        throw("No xProgress Instance found for identity $ProgressGUID")
    }
    $Script:ProgressTracker.$($ProgressGUID).Counter++ #advance the counter
    $counter = $Script:ProgressTracker.$($ProgressGUID).Counter #capture the current counter
    $progressInterval = $Script:ProgressTracker.$($ProgressGUID).ProgressInterval #get the progressInterval for the modulus check

    if ($counter % $progressInterval -eq 0 -or $counter -eq 1)
    {
        #modulus check passed so w
        $activity = $Script:ProgressTracker.$($ProgressGUID).Activity
        $stopwatch = $script:ProgressTracker.$($ProgressGuid).Stopwatch
        $total = $script:ProgressTracker.$($ProgressGuid).total
        $elapsedSeconds = [math]::Ceiling($stopwatch.elapsed.TotalSeconds)
        $secondsPerItem = [math]::Ceiling($elapsedSeconds/$counter)
        $secondsRemaining = $($total - $counter) * $secondsPerItem
        $progressItem = $counter + $progressInterval - 1
        $wpParams = @{
            Activity         = $activity
            Status           = "Processing $counter through $progressItem of $total"
            PercentComplete  = $counter/$total * 100
            SecondsRemaining = $secondsRemaining
        }
        if ($Script:ProgressTracker.$($ProgressGUID).containsKey('Id'))
        {
            $wpParams.Id = $Script:ProgressTracker.$($ProgressGUID).Id
        }
        if ($Script:ProgressTracker.$($ProgressGUID).containsKey('ParentId'))
        {
            $wpParams.Id = $Script:ProgressTracker.$($ProgressGUID).ParentId
        }
        Write-Progress @wpParams
    }
}

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


    [cmdletbinding(DefaultParameterSetName = 'CalculatedInterval')]
    param(
        [parameter(Mandatory)]
        [psobject[]]$ArrayToProcess #The array of items to be processed
        ,
        [parameter(ParameterSetName = 'CalculatedInterval')]
        [alias('CalculatedInterval','CPI')]
        [ValidateSet('1Percent','10Percent','20Percent','25Percent','Each')]
        [string]$CalculatedProgressInterval = '1Percent' #Select a progress interval.  Default is 1 Percent (1Percent).

        ,
        [parameter(ParameterSetName = 'ExplicitInterval')]
        [alias('ExplicitInterval','EPI')]
        [int32]$ExplicitProgressInterval #specify an explicity item count at which to show progress.
        ,
        [parameter(Mandatory)]
        [string]$Activity #displayed in the progress bar Activity field (passed through to Write-Progress -Activity).
        ,
        [parameter()]
        [int32]$Id #set the Id for Write-Progress, if desired.
        ,
        [parameter()]
        [int32]$ParentId #set the ParentId for Write-Progress, if desired.
    )

    $ProgressGuid = $(New-Guid).guid
    $total = $ArrayToProcess.Count
    switch ($PSCmdlet.ParameterSetName)
    {
        'CalculatedInterval'
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
        'ExplicitInterval'
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
    }

    $script:ProgressTracker.$($ProgressGuid) = @{}
    $script:ProgressTracker.$($ProgressGuid).Activity = $Activity
    $script:ProgressTracker.$($ProgressGuid).ProgressInterval = $Interval
    $script:ProgressTracker.$($ProgressGuid).total = $total
    $script:ProgressTracker.$($ProgressGuid).Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $script:ProgressTracker.$($ProgressGuid).counter = 0
    if ($Id) {$script:ProgressTracker.$($ProgressGuid).Id = $Id}
    if ($ParentId) {$script:ProgressTracker.$($ProgressGuid).ParentId = $ParentId}

    $ProgressGuid
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
        [parameter(Mandatory)]
        [guid]$Identity #the xProgress Identity to complete
    )

    $ProgressGUID = $Identity.guid #set the ProgressGUID to the string represenation of the Identity GUID
    $script:ProgressTracker.$($ProgressGuid).Stopwatch.Stop() #stop the stopwatch
    $activity = $Script:ProgressTracker.$($ProgressGUID).Activity
    $stopwatch = $script:ProgressTracker.$($ProgressGuid).Stopwatch
    $elapsedSeconds = [math]::Ceiling($stopwatch.elapsed.TotalSeconds)
    $total = $script:ProgressTracker.$($ProgressGuid).total
    $wpParams = @{
        Activity         = $activity
        Status           = "Processed all $total iterations. Elapsed seconds: $elapsedSeconds"
        PercentComplete  = 100
        SecondsRemaining = 0
    }
    if ($Script:ProgressTracker.$($ProgressGUID).containsKey('Id'))
    {
        $wpParams.Id = $Script:ProgressTracker.$($ProgressGUID).Id
    }
    if ($Script:ProgressTracker.$($ProgressGUID).containsKey('ParentId'))
    {
        $wpParams.Id = $Script:ProgressTracker.$($ProgressGUID).ParentId
    }
    #Remove progress bar
    Write-Progress @wpParams -Completed
    #Remove Progress Identity GUID
    $script:ProgressTracker.remove($ProgressGUID)
}

Function Write-xJobProgress
{
        param(
        [System.Management.Automation.Job[]]$Job
    )
 
    process {
        foreach ($j in $Job)
        {
                #Extracts the latest progress of the job and writes the progress
                $jobProgressHistory = $j.ChildJobs[0].Progress
                $latestProgress = $jobProgressHistory[$jobProgressHistory.Count - 1]
                $latestPercentComplete = $latestProgress.PercentComplete
                $latestActivity = $latestProgress.Activity
                $latestStatus = $latestProgress.StatusDescription
            
                #When adding multiple progress bars, a unique ID must be provided. Here I am providing the JobID as this
                Write-Progress -Id $j.Id -Activity $latestActivity -Status $latestStatus -PercentComplete $latestPercentComplete;
        }
    }
}