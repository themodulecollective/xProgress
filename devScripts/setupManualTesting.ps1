
Import-Module -Force $MyGitModules\xProgress\xProgress.psd1
$myDocs = Get-ChildItem -Recurse -File -Path $MyDocsPath
$xProgressID = New-xProgress -ArrayToProcess $mydocs -CalculatedInterval 1Percent -Activity 'Traverse MyDocs Files'
$xProgressID2 = New-xProgress -ArrayToProcess $mydocs -CalculatedInterval 1Percent -Activity 'Reverse MyDocs Files' -xParentIdentity $xProgressID