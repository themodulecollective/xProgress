# xProgress Powershell Module

The goal of xProgress is to make using progress bars in Powershell as simple as possible while minimizing the performance impact of Write-Progress for processing of large numbers of actions when iterating through an array.  

xProgress module provides the following functions to enable progress display in Powershell functions, modules, and scripts where progress intervals are used to write progress for intervals other than every record (for performance reasons as Write-Progress is expensive to performance) and to automatically provide counter and timer functionality for percentage complete and seconds remaining calculations.

```Powershell
Initialize-xProgress
Write-xProgress
Complete-xProgress
```

## Examples

```powershell

$xProgressID = Initialize-xProgress -ArrayToProcess $MyListOfItems -CalculatedProgressInterval 1Percent -Activity "Process MyListOfItems"
#Sets up xProgress to display progress for a looped operation on $MyListOfItems.  When Write-xProgress is called will update progress at each one percent increment of processing and will use -activity as the activity for Write-Progress.

foreach ($i in $MyListOfItems)
{
    Write-xProgress -Identity $xProgressID
}
#determines if Write-Progress should be called for this iteration using the previously defined xProgress Identity and related Activity and automatically generated counter, progress, and seconds remaining

Complete-xProgress -Identity $xProgressId
#removes the progress bar from display (calls Write-Progress with -Complete parameter for the specified Identity) and removes the xProgressId from xProgress module memory

```
