<#
.SYNOPSIS
    Finds Intune-managed devices that have crashed a specific app version, and
    exports the list (sorted by crash count) to a CSV file.

.DESCRIPTION
    Prompts for an app name and version, then queries the Microsoft Graph
    "userExperienceAnalyticsAppHealthApplicationPerformanceByAppVersionDeviceId"
    report (Intune Endpoint Analytics) for that exact app/version combo.
    Any device with one or more recorded crashes for that app is written to a
    timestamped CSV in the script's own folder.

.NOTES
    Suggested file name: Get-DevicesWithAppCrashes.ps1
    (Verb-Noun PowerShell naming convention; "Get" because it retrieves/reports
    data and doesn't change anything in Intune.)

    Requires: Microsoft.Graph.Authentication module (for Connect-MgGraph /
    Invoke-MgGraphRequest) and the "DeviceManagementManagedDevices.Read.All"
    Graph permission (delegated or app, granted to whoever signs in).
#>

# --- Step 1: Get the app name/version to search for from the person running the script ---
$appName    = (Read-Host "Paste the app name").Trim()
$appVersion = (Read-Host "Paste the app version").Trim()

# Bail out early with a clear error if either input is blank.
if ([string]::IsNullOrWhiteSpace($appName) -or
    [string]::IsNullOrWhiteSpace($appVersion)) {
    throw "Both an app name and version are required."
}

# --- Step 2: Sign in to Graph with just enough permission to read device data ---
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"

# --- Step 3: Build a safe OData $filter for the Graph query ---
# Doubling any single quotes in the input prevents the value from breaking out
# of the OData string literal (basic injection protection for the $filter).
$escapedName    = $appName.Replace("'", "''")
$escapedVersion = $appVersion.Replace("'", "''")
$filter = "appName eq '$escapedName' and appVersion eq '$escapedVersion'"

# URL-encode the filter and attach it to the report endpoint.
# (Escaping "$filter" as "%24filter" avoids PowerShell trying to expand $filter
# as a variable inside the string.)
$baseURL = "https://graph.microsoft.com/v1.0/deviceManagement/userExperienceAnalyticsAppHealthApplicationPerformanceByAppVersionDeviceID"
$uri = $baseURL + '?%24filter=' + [uri]::EscapeDataString($filter)

# --- Step 4: Page through the Graph results, collecting devices with crashes ---
$devices = [System.Collections.Generic.List[object]]::new()
$pageNumber = 0

do {
    $page = Invoke-MgGraphRequest -Method Get -Uri $uri -ErrorAction Stop
    $pageNumber++

    foreach ($item in $page.value) {
        # Sanity check: Graph's $filter is server-side, so this just guards
        # against unexpected/partial matches slipping through.
        if ($item.appName -ine $appName -or $item.appVersion -ne $appVersion) {
            throw "Graph returned a record outside the requested app and version."
        }

        # Only keep devices that actually have at least one crash recorded.
        if ([int]$item.appCrashCount -gt 0) {
            $devices.Add([pscustomobject]@{
                DeviceName = $item.deviceDisplayName
                Crashes    = [int]$item.appCrashCount
                DeviceId   = $item.deviceId
            })
        }
    }

    # Show progress in the console while paging through results.
    Write-Progress -Activity "Retrieving devices" `
        -Status "Page $pageNumber; $($devices.Count) matching devices"

    # Graph returns an '@odata.nextLink' when there's another page; otherwise
    # this is $null and the loop ends.
    $uri = $page.'@odata.nextLink'
} while ($uri)

Write-Progress -Activity "Retrieving devices" -Completed

# --- Step 5: Report results / export to CSV ---
if ($devices.Count -eq 0) {
    Write-Warning "No devices with crashes found for $appName version $appVersion"
} else {
    # Timestamped filename so repeat runs don't overwrite each other.
    $fileName = "DevicesWithCrashes_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath $fileName

    $devices |
        Sort-Object Crashes -Descending |
        Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8

    Write-Host "Exported $($devices.Count) devices to $filePath"
}
