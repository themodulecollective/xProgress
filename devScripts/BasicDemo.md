# xProgress Demo

## Intro

- Mike Campbell - Senior Solutions Architect - M365/Azure AD Focus
- @thatexactmike
- exactmike on github

## Problem

1. I wanted to use Write-Progress more consistently in my modules and especially with long running functions and scripts.
2. I wanted to use "advanced" features of Write-Progress such as time remaining and parent/child progress.
3. I wanted to do 1 and 2 without re-writing the required logic

## Solution

[xProgress Module](https://github.com/themodulecollective/xProgress/)
https://github.com/themodulecollective/xProgress/

``` PowerShell

Install-Module xProgress -Scope AllUsers
$pictures = get-childitem $ByDatePicturesPath -Recurse
$Pictures.count
$PSStyle.Progress.View = 'Classic'
$xProgressID = New-xProgress `
-ArrayToProcess $pictures `
-ExplicitProgressInterval 1000 `
-Activity "Process Pictures" -status "First Stage"
foreach ($i in $pictures)
{
    Write-xProgress -Identity $xProgressID
    # Do some things
}
Complete-xProgress -Identity $xProgressID

```

## Features not demonstrated

- CalculatedProgressInterval parameteter (based on pre-defined percentages of progress by item count)
- Parent / Child xProgress bars
- Modification of Progress bar using Set-xProgress (useful for monitoring stages of operation)