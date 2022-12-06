# xProgress Powershell Module

The goal of xProgress is to make using progress bars in Powershell as simple as possible while minimizing the performance impact of Write-Progress for processing of large numbers of actions when iterating through an array.

The xProgress module provides the functions to enable progress display in Powershell functions, modules, and scripts where progress intervals are used to write progress for intervals including every item in an array, or for various percentages of the array, or for manually specified intervals (per number of items processed).

Script/Module authors may want to limit how often write-progress is called for performance reasons as each call to Write-Progress is actually very expensive to performance of long running operations which process many items.

Additionally, xProgress automatically provides counter and timer functionality for percentage complete and seconds remaining calculations, as well as automated management of ParentID for nested progress bars.

```Powershell
New-xProgress
Get-xProgress
Write-xProgress
Set-xProgress
Complete-xProgress
```

## Examples

### Basic Usage
```powershell
$xProgressID = New-xProgress -ArrayToProcess $MyListOfItems -CalculatedProgressInterval 1Percent -Activity "Process MyListOfItems"
#Sets up xProgress to display progress for a looped operation on $MyListOfItems.  When Write-xProgress is called will update progress at each one percent increment of processing and will use -activity as the activity for Write-Progress.

foreach ($i in $MyListOfItems)
{
    Write-xProgress -Identity $xProgressID
    # Do some things
    Set-xProgress -Status 'Final Phase'
    Write-xProgress -Identity $xProgressID
}
#determines if Write-Progress should be called for this iteration using the previously defined xProgress Identity and related Activity and automatically generated counter, progress, and seconds remaining

Complete-xProgress -Identity $xProgressId
#removes the progress bar from display (calls Write-Progress with -Complete parameter for the specified Identity) and removes the xProgressId from xProgress module memory

```

### Parent/Child Usage

```powershell

$PxPID = New-xProgress -ArrayToProcess @(1,2,3) -CalculatedProgressInterval Each -Status 'Step 1 of 3: Get MyListofItems'
Write-xProgress -Identity $PxPID

#if appropriate a child xProgress could be created here
$MyListOfItems = @(

    #some code that retrieve my list of items
    #a child xProgress could be displayed here
)
# a child xProgress bar could be completed here

Set-xProgress -Identity $PxPID -Status 'Step 2 of 3: Process MyListOfItems'
Write-xProgress -Identity $PxPID
$CxPID = New-xProgress -ArrayToProcess $MyListOfItems -CalculatedProgressInterval 1Percent -Activity "Process MyListOfItems" -xParentID $PxPID
foreach ($i in $MyListOfItems)
{
    Write-xProgress -Identity $CxPID
    # displays progress bar indented under parent progress bar
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

## Releases
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
- extend Set-xProgress to include adjustment of progress interval using -CalculatedProgressInterval and/or -ExplicitProgressInterval
- Add a switch to New-xProgress to support creating the instance but not yet starting the stopwatch.  Add Start-xProgress and Stop-xProgress to support starting and stopping the stopwatch.  This would allow creation of a hierarchy of xProgress instances in one place in a function or script to be activated as needed. This also enables some advanced functionality with Parent/Child scenarios for automation of stages/steps.
- possibly incorporate some gui progress bars like this: https://key2consulting.com/powershell-how-to-display-job-progress/ or https://github.com/Tiberriver256/PoshProgressBar