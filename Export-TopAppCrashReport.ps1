<#
.SYNOPSIS
    "Bonus" script for the AppHealthAPISeries: chains Posts 1-3 together.
    Pulls the top 20 crashiest apps, picks the worst version of each, and
    exports the crashing devices for every one of those app/version pairs.

.DESCRIPTION
    This is the three separate scripts from the series, run back-to-back
    automatically instead of by hand:
      1. Top 20 apps by 14-day crash count
         (userExperienceAnalyticsAppHealthApplicationPerformance)
      2. For each of those apps, the version with the most crashes
         (userExperienceAnalyticsAppHealthApplicationPerformanceByAppVersionDetails)
      3. For each app/version pair, every device that has crashed it
         (userExperienceAnalyticsAppHealthApplicationPerformanceByAppVersionDeviceID)

    Everything lands in one timestamped folder next to the script:
      - Top20Apps.csv        -> the 20 apps, sorted worst-first
      - ChosenVersions.csv   -> the worst version picked for each app
      - ExportSummary.csv    -> one row per app/version: how many devices were
                                 expected vs. actually exported, and status
      - 01_AppName_Version.csv ... 20_AppName_Version.csv
                              -> the actual crashing devices for each app/version

.NOTES
    Suggested file name: Export-TopAppCrashReport.ps1
    (Verb-Noun convention; "Export" because its end result is a folder of CSVs.)

    Requires: Microsoft.Graph.Authentication module and the
    "DeviceManagementManagedDevices.Read.All" Graph permission.

    Fixes applied to the pasted version (all three would have caused the
    script to error out or silently return wrong data):
      - "IsNull0rWhiteSpace" (zero instead of the letter O) -> IsNullOrWhiteSpace
      - "$escapeName" (undefined variable, so the filter's app-name clause was
        blank) -> $escapedName
      - "?&24filter=" (should URL-encode the "$" as %24, not "&24") -> "?%24filter="
#>

# Stop on any non-terminating error too, so a failed Graph call doesn't let
# the rest of the script run against incomplete data.
$ErrorActionPreference = 'Stop'

# --- Helper: page through any Graph collection endpoint and return every item ---
# Both the "top apps" call and the "versions" call return paged results, so
# this is shared instead of duplicating the do/while-nextLink loop twice.
function Get-GraphCollection {
    param ([Parameter(Mandatory)][string]$Uri)

    $items = [System.Collections.Generic.List[object]]::new()
    do {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop
        foreach ($item in $page.value) {
            $items.Add($item)
        }
        $Uri = $page.'@odata.nextLink'
    } while ($Uri)

    return $items.ToArray()
}

# --- Helper: turn an app name/version into a string that's safe to use in a file name ---
# Strips anything that isn't a letter, digit, dot, underscore or hyphen (so
# "/", ":", etc. in an app name can't break the file path), and truncates so
# long names don't hit filesystem path-length limits.
function Get-SafeFilePart {
    param([string]$Value, [int]$MaxLength = 80)

    $safe = ($Value -replace '[^A-Za-z0-9._-]','_').Trim('._')
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'Unknown' }
    if ($safe.Length -gt $MaxLength) { $safe = $safe.Substring(0, $MaxLength) }
    return $safe
}

# This script writes its exports next to itself, so it only works when run as
# a saved .ps1 file (not pasted directly into a console, where $PSScriptRoot
# is blank).
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    throw 'Save this code as a .ps1 file and run that file so exports can be saved beside it.'
}

# --- Step 1: Sign in and set up a fresh, timestamped export folder ---
Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$graphBase = 'https://graph.microsoft.com/v1.0/deviceManagement/'
$folderName = 'AppCrashExports_{0}' -f (Get-Date -Format 'yyyyMMdd_HHmmss')
$exportFolder = Join-Path -Path $PSScriptRoot -ChildPath $folderName
New-Item -ItemType Directory -Path $exportFolder -Force | Out-Null

# --- Step 2: Pull every app's crash totals and keep the worst 20 (Post 1) ---
Write-Host 'Retrieving application crash totals...'
$apps = @(Get-GraphCollection -Uri ($graphBase + 'userExperienceAnalyticsAppHealthApplicationPerformance'))
$topApps = @($apps |
    Sort-Object { [int64]$_.appCrashCount } -Descending |
    Select-Object -First 20)

if ($topApps.Count -eq 0) {
    throw 'Graph returned no application reliability records.'
}

# Save the Top 20 list on its own, independent of anything below.
$topApps |
    Select-Object `
        @{Name='AppName';Expression={$_.appName}},
        @{Name='Publisher';Expression={$_.appPublisher}},
        @{Name='TotalCrashes14Days';Expression={$_.appCrashCount}} |
    Export-Csv -Path (Join-Path $exportFolder 'Top20Apps.csv') -NoTypeInformation -Encoding UTF8

# --- Step 3: For each of those 20 apps, find its highest-crash version (Post 2) ---
Write-Host 'Retrieving app version crash totals...'
$allVersions = @(Get-GraphCollection -Uri ($graphBase + 'userExperienceAnalyticsAppHealthApplicationPerformanceByAppVersionDetails'))
$plans = [System.Collections.Generic.List[object]]::new()

foreach ($app in $topApps) {
    # Match on app name first...
    $sameName = @($allVersions | Where-Object { $_.appName -ieq $app.appName })
    # ...then narrow to the same publisher too, if the app has one. This
    # avoids mixing up two different apps that happen to share a name.
    $samePublisher = @($sameName | Where-Object { $_.appPublisher -ieq $app.appPublisher })
    $candidates = if ([string]::IsNullOrWhiteSpace($app.appPublisher)) {
        $sameName
    } else {
        $samePublisher
    }

    $bestVersion = $candidates |
        Sort-Object { [int64]$_.appCrashCount } -Descending |
        Select-Object -First 1

    # Record the plan for this app even if no version details were found
    # (Version ends up $null) - we still want it to show up in the summary
    # further down rather than silently disappearing.
    $plans.Add([pscustomobject]@{
        AppName             = $app.appName
        Publisher           = $app.appPublisher
        AppCrashes14Days    = [int64]$app.appCrashCount
        Version             = $bestVersion.appVersion
        VersionCrashes      = if ($bestVersion) { [int64]$bestVersion.appCrashCount } else { $null }
        ExpectedDeviceCount = if ($bestVersion) { [int64]$bestVersion.deviceCountWithCrashes } else { $null }
    })
}

# Save which version was picked for each app, for reference/auditing.
$plans.ToArray() |
    Export-Csv -Path (Join-Path $exportFolder 'ChosenVersions.csv') -NoTypeInformation -Encoding UTF8

# --- Step 4: For each app/version pair, export the crashing devices (Post 3) ---
$summaryPath = Join-Path $exportFolder 'ExportSummary.csv'
$deviceEndpoint = $graphBase + 'userExperienceAnalyticsAppHealthApplicationPerformanceByAppVersionDeviceID'

for ($i = 0; $i -lt $plans.Count; $i++) {
    $plan = $plans[$i]
    $rank = $i + 1
    # Prefix the file name with a 2-digit rank so the folder sorts in the
    # same worst-to-best order as Top20Apps.csv.
    $fileName = '{0:D2}_{1}_{2}.csv' -f $rank, (Get-SafeFilePart $plan.AppName), (Get-SafeFilePart $plan.Version 30)
    $filePath = Join-Path $exportFolder $fileName
    $exportedCount = 0
    $status = 'Completed'

    Write-Progress -Id 1 -Activity 'Exporting top app crash devices' `
        -Status "$rank of $($plans.Count): $($plan.AppName) $($plan.Version)" `
        -PercentComplete ([int](100 * ($rank - 1) / $plans.Count))

    if ([string]::IsNullOrWhiteSpace($plan.Version)) {
        # No version was found for this app in Step 3 - nothing to query, so
        # just note it in the summary and move on.
        $status = 'No version found'
        $fileName = ''
        Write-Warning "No version details found for $($plan.AppName)."
    } else {
        try {
            # Same escape-quotes-then-URL-encode approach as the standalone
            # Post 3 script, per app/version pair.
            $escapedName    = $plan.AppName.Replace("'", "''")
            $escapedVersion = $plan.Version.Replace("'", "''")
            $filter = "appName eq '$escapedName' and appVersion eq '$escapedVersion'"
            $uri = $deviceEndpoint + '?%24filter=' + [uri]::EscapeDataString($filter)
            $devices = [System.Collections.Generic.List[object]]::new()
            $pageNumber = 0

            do {
                $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
                $pageNumber++

                foreach ($item in $page.value) {
                    # Guard against Graph handing back something outside the
                    # requested app/version (the $filter is server-side, so
                    # this is a defensive check, not the primary filter).
                    if ($item.appName -ine $plan.AppName -or $item.appVersion -ne $plan.Version) {
                        throw 'Graph returned a device record outside the requested app and version'
                    }
                    # Extra safety: if the app has a publisher and this
                    # record's publisher doesn't match, skip it (handles the
                    # same-name-different-publisher case from Step 3).
                    if ($item.appPublisher -and $plan.Publisher -and
                        $item.appPublisher -ine $plan.Publisher) {
                        continue
                    }
                    if ([int64]$item.appCrashCount -gt 0) {
                        $devices.Add([pscustomobject]@{
                            DeviceName = $item.deviceDisplayName
                            Crashes    = [int64]$item.appCrashCount
                            DeviceId   = $item.deviceId
                        })
                    }
                }

                Write-Progress -Id 2 -ParentId 1 -Activity 'Retrieving devices' `
                    -Status "Page $pageNumber; $($devices.Count) devices"
                $uri = $page.'@odata.nextLink'
            } while ($uri)

            Write-Progress -Id 2 -ParentId 1 -Activity 'Retrieving devices' -Completed

            if ($devices.Count -gt 0) {
                $devices.ToArray() |
                    Sort-Object Crashes -Descending |
                    Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            } else {
                # Still write a (header-only) file so every ranked app/version
                # has a matching CSV, even if it turned out to have zero
                # crashing devices at export time.
                'DeviceName,Crashes,DeviceId' |
                    Set-Content -Path $filePath -Encoding UTF8
            }

            $exportedCount = $devices.Count
            # Post 2's version summary and this per-device export can drift
            # apart slightly if data changed between the two Graph calls -
            # flag it rather than hiding the discrepancy.
            if ($exportedCount -ne $plan.ExpectedDeviceCount) {
                $status = 'Completed; device count differs from version summary'
                Write-Warning "$($plan.AppName) $($plan.Version): expected $($plan.ExpectedDeviceCount) devices; exported $exportedCount."
            }
            Write-Host "[$rank/$($plans.Count)] $($plan.AppName) $($plan.Version): $exportedCount devices -> $fileName"
        } catch {
            Write-Progress -Id 2 -ParentId 1 -Activity 'Retrieving devices' -Completed
            $status = 'Failed'
            $fileName = ''
            Write-Warning "Export failed for $($plan.AppName) $($plan.Version): $($_.Exception.Message)"
        }
    }

    # Append one row per app/version to the running summary, so a failure
    # partway through still leaves a summary of everything completed so far.
    [pscustomobject]@{
        Rank                = $rank
        AppName             = $plan.AppName
        Publisher           = $plan.Publisher
        AppCrashes14Days    = $plan.AppCrashes14Days
        Version             = $plan.Version
        VersionCrashes      = $plan.VersionCrashes
        ExpectedDeviceCount = $plan.ExpectedDeviceCount
        ExportedDeviceCount = $exportedCount
        File                = $fileName
        Status              = $status
    } | Export-Csv -Path $summaryPath -NoTypeInformation -Encoding UTF8 -Append
}

Write-Progress -Id 1 -Activity 'Exporting top app crash devices' -Completed
Write-Host "Finished. Files are in: $exportFolder"
