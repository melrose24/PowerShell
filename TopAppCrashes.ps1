# Connect to Microsoft Graph with permission to read Intune-managed device data
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"

# Endpoint for Endpoint Analytics' "App Health" data — app performance/crash stats
# gathered from Intune-managed devices over the trailing 14-day window
$uri = "https://graph.microsoft.com/v1.0/deviceManagement/userExperienceAnalyticsAppHealthApplicationPerformance"

# Collect results here, since Graph paginates large result sets
$apps = @()

do {
    # Request the current page of results
    $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

    # Add this page's records to the running collection
    $apps += $page.value

    # Graph returns an '@odata.nextLink' when more pages remain;
    # this becomes $null once the last page has been retrieved, ending the loop
    $uri = $page.'@odata.nextLink'
} while ($uri)

# Sort all apps by crash count (descending) and take the worst 20 offenders,
# then relabel/select the fields into friendlier column names for reporting
$top20 = $apps |
    Sort-Object { [int64]$_.appCrashCount } -Descending |
    Select-Object -First 20 `
    @{Name="App name"; Expression={$_.appName}},
    @{Name="Publisher"; Expression={$_.appPublisher}},
    @{Name="Total crashes (14 days)"; Expression={$_.appCrashCount}}

# Print the top 20 crashiest apps as a formatted table
$top20 | Format-Table -Autosize