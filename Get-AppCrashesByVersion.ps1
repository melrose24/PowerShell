# Prompt the user for the application name to look up (e.g., "Outlook.exe")
# .Trim() removes any accidental leading/trailing whitespace from the input
$appName = (Read-Host "Paste the app name (for example, Outlook.exe)").Trim()

# Guard clause: stop execution if the user submitted an empty or whitespace-only value
if ([string]::IsNullOrWhiteSpace($appName)) {
    throw "An app name is required."
}

# Authenticate to Microsoft Graph with read-only access to Intune managed device data
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"

# Endpoint that returns Endpoint Analytics "App Health" performance data,
# broken down by app version
$uri = "https://graph.microsoft.com/v1.0/deviceManagement/userExperienceAnalyticsAppHealthApplicationPerformanceByAppVersionDetails"

# Accumulator array for all matching version records across all pages
$versions = @()

# Graph API results are paged; loop until there's no more @odata.nextLink
do {
    $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

    # Filter this page's results to only the app the user asked about
    # (-ieq = case-insensitive equality, since app names can vary in casing)
    $versions += @($page.value | Where-Object { $_.appName -ieq $appName })

    # Move to the next page, if one exists; otherwise this becomes $null and the loop exits
    $uri = $page.'@odata.nextLink'
 } while ($uri)

# If nothing matched the app name across all pages, let the user know and stop here
if ($versions.Count -eq 0) {
    Write-Warning "No version details found for $appName"
} else {
    # Otherwise, build a readable report:
    # - Sort versions by crash count, worst offenders first
    # - Rename raw API fields to friendly column headers
    # - Print as a formatted table
    $versions |
    Sort-Object {[int64]$_.appCrashCount } -Descending |
    Select-Object `
        @{Name="App version"; Expression={$_.appVersion}},
        @{Name="App Crashes (14 days)"; Expression={$_.appCrashCount}},
        @{Name="Devices with crashes"; Expression={$_.deviceCountWithCrashes}},
        @{Name="Latest"; Expression={$_.isLatestUsedVersion}},
        @{Name="Most used"; Expression={$_.isMostUsedVersion}} |
    Format-Table -AutoSize
}