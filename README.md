# xProgress Powershell Module

xProgress makes the complexity of using progress bars in Powershell simple: throttled updates, accurate time-remaining, nested parent/child bars, and, uniquely, progress reported from *inside a background job* — while minimizing the performance impact of calling Write-Progress on every iteration of a large loop.

Write-Progress is expensive to call on every iteration of a large loop, complex to manage when fully using its capabilities, and in the case of background jobs, invisible to the calling session.

xProgress solves all three problems.

## Performance

xProgress throttles Write-Progress calls to configurable intervals (e.g. every 1%, every 10 items) while still calculating accurate percentage complete and estimated time remaining for every item processed.

## Complexity

Managing progress bar calculations, parent/child relationships, and timer state is handled automatically by xProgress so you do not need to write custom tracking code for each scenario where progress output is desired.

A hand-rolled equivalent typically means: a counter and a modulus check to throttle calls, a stopwatch plus elapsed/remaining-time math, percent-complete capping so a rounding error never reports 101%, and — the moment a second progress bar nests under the first — a hand-maintained scheme for Id/ParentId bookkeeping. Roughly 40-80 lines of that plumbing per progress bar, copy-pasted and re-adapted at every callsite, versus one `New-xProgress` line plus a `Write-xProgress` call per iteration. It's also easy to get subtly wrong: a percent-complete that could exceed 100, a divide-by-zero on the first call, an auto-assigned Id that silently came out `$null`, an off-by-one in a batch-count message.  All bugs you no longer have to worry about.

## Background Jobs

Write-Progress calls inside a `Start-Job` scriptblock only reach that job's own Progress stream — they are invisible in the calling session without tooling like xProgress. As far as we're aware, no other PowerShell module does this for you. Getting it right by hand (tracking each activity separately instead of just the last message received, preserving parent/child nesting reported inside the job, avoiding Id collisions across concurrent jobs, cleaning up once a job finishes) easily runs past 100 lines. This why most scripts and modules either skip job progress entirely or settle for a naive "show whatever came in last" readout. `Write-xJobProgress` reduces all of that to one cmdlet call in your own polling loop.

```Powershell
New-xProgress
Get-xProgress
Write-xProgress
Set-xProgress
Complete-xProgress
Start-xProgress
Suspend-xProgress
Resume-xProgress
Write-xJobProgress
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

### Job Progress

`Write-xJobProgress` mirrors `Write-Progress` calls happening *inside* a background job's scriptblock into your own session. It's a lightweight, write-only passthrough — unlike the rest of xProgress, it does not register anything in xProgress's own tracker and has no throttling, Suspend/Resume, or timer semantics. Call it repeatedly from your own polling loop; it never blocks or polls on its own.

```powershell
$job = Start-Job -ScriptBlock {
    1..10 | ForEach-Object {
        Write-Progress -Activity 'Work' -PercentComplete ($_ * 10)
        Start-Sleep -Milliseconds 200
    }
}

while ($job.State -eq 'Running')
{
    Write-xJobProgress -Job $job
    Start-Sleep -Milliseconds 250
}
Write-xJobProgress -Job $job
# the final call shows the last update and completes/clears the progress bar

# Or, for every job in the session:
Get-Job | Write-xJobProgress
```

If the job's scriptblock reports more than one activity (including nested activities via `-ParentId`), `Write-xJobProgress` mirrors each one with a distinct, stable progress bar and preserves the parent/child nesting. Progress `-Id` values are drawn from the same pool xProgress itself uses, so mirrored job bars never collide with your own xProgress instances.

## Releases

1.1.0 New Functionality

- `Write-xJobProgress`: mirrors `Write-Progress` calls happening inside a
  background job's scriptblock into the caller's session, one bar per
  distinct activity, preserving parent/child nesting reported inside the
  job. Lightweight write-only passthrough - no throttling/timer/tracker
  integration (see the Job Progress section above).

1.0.1 Bug Fix

- `New-xProgress`: auto-assigned `-Id` (and any child's `ParentID` set via
  `-xParentIdentity`) could come out `$null`/`0` instead of an incrementing
  integer. The `else` branch of the ID assignment used a bare
  `++$script:WriteProgressID` as the last statement of an if/else
  value-capturing script block, and PowerShell's increment operator doesn't
  emit its result in that context. `Write-Progress` would then throw
  `Cannot validate argument on parameter 'Id'` the first time a script
  called `Write-xProgress`/`Complete-xProgress` on an auto-assigned
  instance. Fixed: wrapped the increment in parentheses so its value is
  returned.

1.0.0 New Functionality for managing complex timers when required by your scenario.  First major release completing the original vision for xProgress

- Set-xProgress interval adjustment: Added -CalculatedProgressInterval and -ExplicitProgressInterval parameters to dynamically change the progress update frequency on an existing xProgress instance
- Stopwatch lifecycle management - Three new functions for manual timer control and an adjustment to Write-xProgress to support.
  - Start-xProgress - Start the stopwatch before the first Write-xProgress call
  - Suspend-xProgress - Pause the stopwatch to exclude wait times from elapsed calculations
  - Resume-xProgress - Resume a paused stopwatch
  - Write-xProgress -DoNotStartTimer switch - Prevents auto-starting the timer on first write when using manual stopwatch control
- Bux fixes
  - `-Id` parameter in `New-xProgress` declared but never applied to the
  instance object. Fixed: now uses provided Id when present.
  - Division by zero in `Write-xProgress` when `-DoNotIncrement` is used
  as the first call (Counter=0). `0 % interval = 0` triggered the display
  block, then `elapsedSeconds / 0` threw. Fixed: added `$counter -gt 0`
  guard on the display block condition.
  - Auto-generated `CurrentOperation` text: `$progressItem` was not capped,
  so batch end count could exceed total (e.g. "101 through 110 of 105").
  Fixed: `[Math]::Min($counter + $progressInterval - 1, $xPi.total)`

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

- `Write-xJobProgress`: add an `-xParentIdentity` parameter to nest mirrored job progress bars under a caller's own xProgress instance
- possibly incorporate new progress bar ideas such as this: https://github.com/Tiberriver256/PoshProgressBar or https://github.com/rsalmei/alive-progress or https://github.com/tqdm/tqdm?tab=readme-ov-file