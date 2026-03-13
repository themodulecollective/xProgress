# xProgress Powershell Module

xProgress makes the complexity of using progress bars (including some of the more advanced features like time remaining) in Powershell simple while minimizing the performance impact of Write-Progress for processing of large numbers of actions when iterating through an array.

Write-Progress is expensive to call on every iteration of a large loop and is complex to manage when fully using it's capabilities.
xProgress solves these problems.

Performance
    xProgress throttles Write-Progress calls to configurable intervals (e.g. every 1%, every 10 items) while still calculating accurate percentage complete and estimated time remaining for every item processed.

Complexity
    Managing progress bar calculations, parent/child relationships, and timer state is handled automatically by xProgress so you do not need to write custom tracking code for each scenario where progress output is needed.

```Powershell
New-xProgress
Get-xProgress
Write-xProgress
Set-xProgress
Complete-xProgress
Start-xProgress
Suspend-xProgress
Resume-xProgress
```

## Examples

### Basic Usage

```powershell
$xProgressID = New-xProgress `
-ArrayToProcess $MyListOfItems `
-CalculatedProgressInterval 1Percent `
-Activity "Process MyListOfItems"

# Sets up xProgress to display progress for a looped operation on $MyListOfItems.
# When Write-xProgress is called will update progress at each one percent increment of processing
# and will use -activity as the activity for Write-Progress.

foreach ($i in $MyListOfItems)
{
    Write-xProgress -Identity $xProgressID
    # Do some things
    Set-xProgress -Identity $xProgressID -Status 'Final Phase'
    Write-xProgress -Identity $xProgressID -DoNotIncrement
}

# determines if Write-Progress should be called for this iteration using the previously defined
# xProgress Identity and related Activity and automatically generated counter, progress, and seconds remaining

Complete-xProgress -Identity $xProgressId
# removes the progress bar from display
# (calls Write-Progress with -Complete parameter for the specified Identity)
# and removes the xProgressId from xProgress module memory

```

### Parent/Child Usage

```powershell

$PxPID = New-xProgress -ArrayToProcess @(1,2,3) -CalculatedProgressInterval Each -Activity "Multi-Stage Process" -Status 'Step 1 of 3: Get MyListofItems'
Write-xProgress -Identity $PxPID

#if appropriate a child xProgress could be created here
$MyListOfItems = @(

    #some code that retrieve my list of items
    #a child xProgress could be displayed here
)
# a child xProgress bar could be completed here

Set-xProgress -Identity $PxPID -Status 'Step 2 of 3: Process MyListOfItems'
Write-xProgress -Identity $PxPID
$CxPID = New-xProgress -ArrayToProcess $MyListOfItems -CalculatedProgressInterval 1Percent -Activity "Process MyListOfItems" -xParentIdentity $PxPID
foreach ($i in $MyListOfItems)
{
    Write-xProgress -Identity $CxPID
    # displays progress bar indented under parent progress bar
    Set-xProgress -Identity $CxPID -CurrentOperation 'cleaning up'
    Write-xProgress -Identity $CxPID -DoNotIncrement
    # displays progress bar again but without incrementing the counter
}
Complete-xProgress -Identity $CxPID
#completes the child progress bar

Set-xProgress -Identity $PxPID -Status 'Step 3 of 3: Export MyListOfItems'
Write-xProgress -Identity $PxPID

# Code that exports MyListOfItems
# if appropriate this could contain another child progress bar

Complete-xProgress -Identity $PxPID
#completes the parent progress bar
```

### Timer Management

#### Excluding wait time from elapsed calculations

When each iteration involves waiting on an external operation (an API call, a job, a sleep) or human input, or a branch to troubleshoot/resolve a problem encountered during normal processing, suspend the stopwatch during the wait so that elapsed time and time-remaining reflect only active processing time.

```powershell
$xProgressID = New-xProgress `
    -ArrayToProcess $MyListOfItems `
    -CalculatedProgressInterval 1Percent `
    -Activity "Process MyListOfItems"

foreach ($i in $MyListOfItems)
{
    Write-xProgress -Identity $xProgressID

    # Active processing
    $result = Process-Item $i

    # Exclude the wait from elapsed time
    Suspend-xProgress -Identity $xProgressID
    Start-Sleep -Seconds 5  # or any slow external call
    Resume-xProgress -Identity $xProgressID
}

Complete-xProgress -Identity $xProgressID
```

#### Pre-starting the timer before the loop

Use `Start-xProgress` to begin timing before the first iteration — useful when setup work before the loop should be included in the elapsed time, or when you want to create all instances upfront and control exactly when each timer starts.

```powershell
$xProgressID = New-xProgress `
    -ArrayToProcess $MyListOfItems `
    -CalculatedProgressInterval 1Percent `
    -Activity "Process MyListOfItems"

Start-xProgress -Identity $xProgressID  # timer starts here, not on first Write-xProgress

foreach ($i in $MyListOfItems)
{
    Write-xProgress -Identity $xProgressID -DoNotStartTimer  # prevents auto-start since timer is already running
    # Do some things
}

Complete-xProgress -Identity $xProgressID
```

## Releases

0.1.0 New Functionality for managing complex timers when required by your scenario

- Set-xProgress interval adjustment: Added -CalculatedProgressInterval and -ExplicitProgressInterval parameters to dynamically change the progress update frequency on an existing xProgress instance
- Stopwatch lifecycle management - Three new functions for manual timer control and an adjustment to Write-xProgress to support.
  - Start-xProgress - Start the stopwatch before the first Write-xProgress call
  - Suspend-xProgress - Pause the stopwatch to exclude wait times from elapsed calculations
  - Resume-xProgress - Resume a paused stopwatch
  - Write-xProgress -DoNotStartTimer switch - Prevents auto-starting the timer on first write when using manual stopwatch control

0.0.12 Bug Fixes

- Write-xProgress: Fixed undefined variable - Corrected $xProgressInstance to $xPi when retrieving specified CurrentOperation, fixing null output in progress bar.
- Set-xProgress: Fixed StatusType not persisting - Corrected variable case inconsistency ($xPI → $xPi) so StatusType is properly updated when setting Status.
- Complete-xProgress: Added GUID validation - Function now validates that the provided Identity exists in the progress tracker before processing. Invalid GUIDs now produce a clear warning message instead of a  null reference error.
- Set-xProgress: DecrementCounter guard - The -DecrementCounter switch now validates that the counter is greater than zero before decrementing. If the counter is already at zero, a warning is issued and the
  decrement is skipped, preventing negative counter values.
0.0.11 fix for the fix
0.0.10 workaround/fix for situations where write-xprogress is being used more than once for an item in a processing loop.  The counter was incrementing with every call of write-xprogress which needs to be suppressed in this case.  the DoNotIncrement switch parameter was added. Also added a failsafe to write-xprogress in case of error with percent complete values greater than 100.  Write-xprogress will override values over 100 with 100 and throw a warning.
0.0.9 fix to start stopwatch at first call of write-xprogress for given xProgress instance.  Makes for more optimal time remaining calculation.
0.0.8 bug fix for progress status "item x of y of total z" where y was not getting a value
0.0.7 bug fix for Complete-xProgress preventing elapsed seconds from appearing in Write-Information output (when information stream is visible/consumed)
0.0.6 compatibility fix for Windows PowerShell 5.1 Write-Information (does not accept pipeline input)
0.0.5 renamed initialize-xProgress to New-xProgress.  Added alias Initialize-xProgress
0.0.4 add -decrementCounter to Set-xProgress
0.0.3 new functions: Get-xProgress, Set-xProgress.  New functionality: Parent/Child progress bars
0.0.2 bug fixes
0.0.1 initial release with New-xProgress, Write-xProgress, and Complete-xProgress

## Development Plans

- add/extend functions for Job Progress display
- possibly incorporate some gui progress bars like this: https://key2consulting.com/powershell-how-to-display-job-progress/ or https://github.com/Tiberriver256/PoshProgressBar