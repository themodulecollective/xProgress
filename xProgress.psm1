$script:ProgressTracker = @{}

Function Write-xProgress
{
    [cmdletbinding()]
    param(
        [guid]$Identity
    )

    $ProgressGUID = $Identity.guid #set the ProgressGUID to the string represenation of the Identity GUID
    $counter = $Script:ProgressTracker.$($ProgressGUID).Counter++ #advance the counter
    $progressInterval = $Script:ProgressTracker.$($ProgressGUID).ProgressInterval #get the progressInterval for the modulus check

    if ($counter % $progressInterval -eq 0)
    {
        #modulus check passed so w
        $activity = $Script:ProgressTracker.$($ProgressGUID).Activity
        $stopwatch = $script:ProgressTracker.$($ProgressGuid).Stopwatch
        $total = $script:ProgressTracker.$($ProgressGuid).total
        $elapsedSeconds = [math]::Ceiling($stopwatch.elapsed.TotalSeconds)
        $secondsPerItem = [math]::Ceiling($elapsedSeconds/$counter)
        $secondsRemaining = $($total - $counter) * $secondsPerItem
        $progressItem = $counter + $progressInterval
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
    [cmdletbinding(DefaultParameterSetName = 'CalculatedInterval')]
    param(
        [parameter(Mandatory)]
        [psobject[]]$ArrayToProcess
        ,
        [parameter(ParameterSetName = 'CalculatedInterval')]
        [alias('CalculatedInterval','CPI')]
        [ValidateSet('1Percent','10Percent','20Percent','25Percent','Each')]
        [string]$CalculatedProgressInterval = '1Percent'

        ,
        [parameter(ParameterSetName = 'ExplicitInterval')]
        [alias('ExplicitInterval','EPI')]
        [int32]$ExplicitProgressInterval
        ,
        [parameter(Mandatory)]
        [string]$Activity
        ,
        [parameter()]
        [int32]$Id
        ,
        [parameter()]
        [int32]$ParentId
    )

    $ProgressGuid = $(New-Guid).guid
    $total = $ArrayToProcess.Count
    switch ($PSCmdlet.ParameterSetName)
    {
        'CalculatedInterval'
        {
            $divisor = switch ($CalculatedInterval)
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
    [cmdletbinding()]
    param(
        [guid]$Identity
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