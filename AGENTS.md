# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## What This Module Does

`xProgress` is a PowerShell module that wraps `Write-Progress` to solve two problems.

First, a performance problem: calling `Write-Progress` on every iteration of a large loop is expensive. xProgress throttles progress updates to configurable intervals while still calculating accurate percentage, elapsed time, and estimated time remaining.

Second, a complexity problem:  managing xProgress calculations and parent / child relationships is challenging to get right in complex PowerShell scripts and functions and xProgress handles these problems for the developer so that custom code does not have to be used for each scenario where progress output is a requirement.

## Code Conventions

We use the powershell-style-practice skill to guide all PowerShell code activities.

## Commands

### Linting (mirrors CI)

```powershell
Invoke-ScriptAnalyzer -Path *.psm1 -Recurse
```
The CI treats any **Error**-severity finding as a failure; warnings are logged but don't block. Run this before committing changes to `xProgress.psm1`.

### Automated Testing

- Framework: **Pester v5** (`#Requires -Modules @{ModuleName='Pester'; ModuleVersion='5.0.0'}` in every test file — a floor, not an exact pin)
- Test files: `Tests/*.Tests.ps1`, one per exported function plus 4 meta files (`Help.Tests.ps1`, `Module.Tests.ps1`, `Pester.Tests.ps1`, `ScriptAnalyzer.Tests.ps1`)
- Tags: `Build` (the 4 meta files), `UnitTests` (everything else — this module has no background jobs/network/filesystem I/O to integration-test)
- Run all: `Invoke-Pester -Path ./Tests -Output Detailed`
- Run one function's tests: `Invoke-Pester -Path ./Tests/New-xProgress.Tests.ps1 -Output Detailed`
- Each test file independently locates and imports the manifest (`Import-Module ...\xProgress.psd1 -Force`) in its own `BeforeAll`, so files can run standalone or in any order
- `Write-Progress`/`Write-Information` are mocked (`Mock -ModuleName xProgress Write-Progress { }`) where the test needs to assert *what* was passed to them (e.g. a non-null `-Id`); everywhere else tests assert on real return values/state
- Module-private/script-scoped state (`$script:ProgressTracker`, `$script:WriteProgressID`) can be inspected directly via `& (Get-Module xProgress) { $script:ProgressTracker }` if a future private helper needs it — not currently used since all functions are public and `Get-xProgress` already exposes instance state
- CI runs the suite on every push via the `test-with-pester` job in `.github/workflows/main.yml`

### Manual Testing

```powershell
# Load the dev setup helper (environment-specific paths inside)
. .\devScripts\setupManualTesting.ps1
```

### Publishing (CI-managed)

Publishing to the PowerShell Gallery is triggered automatically by a GitHub release or via `workflow_dispatch` on `.github/workflows/publish.yml`. It requires the `PSGallery_EMPK` repository secret.

## Architecture

### State management

All progress instances live in two module-scoped variables in `xProgress.psm1`:

- `$script:ProgressTracker` — hashtable keyed by GUID string; each value is a `PSCustomObject` representing one progress instance.
- `$script:WriteProgressID` — integer counter starting at 628, auto-incremented to assign unique `Write-Progress -Id` values.

### xProgress instance object shape

```
Identity              # GUID string (primary key)
Activity              # Write-Progress -Activity
Status                # $null = auto-generate; string = user-specified
CurrentOperation      # $null = auto-generate; string = user-specified
StatusType            # 'Automatic' | 'Specified'
CurrentOperationType  # 'Automatic' | 'Specified'
ProgressInterval      # Integer — only call Write-Progress every N items
Total                 # Total items in the array
Counter               # Items processed so far
Stopwatch             # System.Diagnostics.Stopwatch instance
ID                    # Write-Progress -Id
ParentID              # Write-Progress -ParentId (-1 = no parent)
xParentIdentity       # GUID of parent xProgress instance (if nested)
```

### Throttling logic

`Write-xProgress` only calls `Write-Progress` when `Counter % ProgressInterval -eq 0` OR `Counter -eq 1` (always show the first update). The interval is set at creation via `-CalculatedProgressInterval` (percentage-based enum: `1Percent`, `10Percent`, `20Percent`, `25Percent`, `Each`) or `-ExplicitProgressInterval` (fixed item count).

### Time estimation

- SecondsPerItem = `ElapsedSeconds / Counter`
- SecondsRemaining = `(Total - Counter) * SecondsPerItem`

### Function responsibilities

| Function | Purpose |
|---|---|
| `New-xProgress` | Creates instance, registers it in `$script:ProgressTracker`, returns GUID |
| `Write-xProgress` | Increments Counter, conditionally calls `Write-Progress`, auto-starts Stopwatch on first item |
| `Get-xProgress` | Retrieves one or all instances from `$script:ProgressTracker` |
| `Set-xProgress` | Mutates an existing instance (text, interval, counter decrement) |
| `Complete-xProgress` | Calls `Write-Progress -Completed`, stops Stopwatch, writes elapsed time via `Write-Information`, removes instance |
| `Start-xProgress` | Manually starts Stopwatch |
| `Suspend-xProgress` | Stops Stopwatch without resetting (to exclude wait time from elapsed) |
| `Resume-xProgress` | Restarts a suspended Stopwatch |

`Initialize-xProgress` is an alias for `New-xProgress`.

### Nesting

Parent/child `Write-Progress` nesting is supported two ways:

- **Manual:** Pass `-Id` / `-ParentId` integers directly.
- **xProgress-managed:** Pass `-xParentIdentity` (alias `xPPID`) with the parent's GUID; the module resolves the integer IDs automatically.

## CI/CD

- **On every push** → `.github/workflows/main.yml` runs PSScriptAnalyzer and the Pester test suite (two jobs) on ubuntu-latest.
- **On GitHub release or manual dispatch** → `.github/workflows/publish.yml` publishes to the PowerShell Gallery.

## Branch Conventions

- `main` — production / released code
- `Dev-0.1.0` — current development branch (active)

## WIP

`WIP/JobProgress.ps1` is a stub for a future feature: displaying progress from PowerShell background jobs. It is not exported or functional yet.
