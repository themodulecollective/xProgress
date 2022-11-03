# xProgress Powershell Module

The goal of xProgress is to make using progress bars in Powershell as simple as possible while minimizing the performance impact of Write-Progress for processing of large numbers of actions when iterating through an array.

The xProgress module provides the functions to enable progress display in Powershell functions, modules, and scripts where progress intervals are used to write progress for intervals including every item in an array, or for various percentages of the array, or for manually specified intervals (per number of items processed).

Script/Module authors may want to limit how often write-progress is called for performance reasons as each call to Write-Progress is actually very expensive to performance of long running operations which process many items.

Additionally, xProgress automatically provides counter and timer functionality for percentage complete and seconds remaining calculations, as well as automated management of ParentID for nested progress bars.

```Powershell
Initialize-xProgress
Get-xProgress
Write-xProgress
Set-xProgress
Complete-xProgress
```

## Examples

```powershell

$xProgressID = Initialize-xProgress -ArrayToProcess $MyListOfItems -CalculatedProgressInterval 1Percent -Activity "Process MyListOfItems"
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

## Releases

0.0.4 add -decrementCounter to Set-xProgress
0.0.3 new functions: Get-xProgress, Set-xProgress.  New functionality: Parent/Child progress bars
0.0.2 bug fixes
0.0.1 initial release with Initialize-xProgress, Write-xProgress, and Complete-xProgress

## Development Plans

- add/extend functions for Job Progress display
- extend Set-xProgress to include adjustment of progress interval using -CalculatedProgressInterval and/or -ExplicitProgressInterval