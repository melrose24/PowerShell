<#
.SYNOPSIS
Intune Windows App Governance Report
Identifies imported apps by Notes, checks assignments and age,
and flags apps older than 60 days with no assignment for review.

.PARAMETER notesKeyword
The description value to search for (e.g. "AutoImport", "ZeroTouch")

.PARAMETER StaleDaysThreshold
Number of days since creation to consider an app stale. Default is 60.

.PARAMETER ExportCSV
Switch to automatically export results to CSV without prompting

.EXAMPLE
.\Audit-IntuneApps.ps1 -notesKeyword "ZeroTouch"
.\Audit-IntuneApps.ps1 -notesKeyword "AutoImport" -StaleDaysThreshold 30 -ExportCSV
#>

[CmdletBinding()]
param (
[Parameter(Mandatory)]
[string]$notesKeyword,

[int]$StaleDaysThreshold = 60,

[switch]$ExportCSV
)

#----------------------------------------------------------
# STEP 1 - Connect
#----------------------------------------------------------
Write-Host "`n[INFO] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "DeviceAppManagement.Read.All" -NoWelcome

$context = Get-MgContext
Write-Host "[INFO] Connected as: $($context.Account)" -ForegroundColor Cyan

#----------------------------------------------------------
# STEP 2 - Pull Windows Apps Only (Server-Side Filter)
#----------------------------------------------------------
Write-Host "`n[INFO] Retrieving Windows apps from Intune..." -ForegroundColor Cyan

$uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')"

$response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
$windowsApps = [System.Collections.Generic.List[object]]::new()
$windowsApps.AddRange($response.value)

# Handle pagination
while ($response.'@odata.nextLink') {
Start-Sleep -Milliseconds 200 # Gentle throttle buffer
$response = Invoke-MgGraphRequest -Method GET -Uri $response.'@odata.nextLink' -OutputType PSObject
$windowsApps.AddRange($response.value)
}

Write-Host "[INFO] Total Windows apps retrieved: $($windowsApps.Count)" -ForegroundColor Cyan

#----------------------------------------------------------
# STEP 3 - Filter by Notes Keyword
#----------------------------------------------------------
Write-Host "`n[INFO] Filtering by Notes containing '$notesKeyword'..." -ForegroundColor Cyan

$matchedApps = $windowsApps | Where-Object {
$_.notes -like "*$notesKeyword*"
}

if (-not $matchedApps -or $matchedApps.Count -eq 0) {
Write-Host "[WARNING] No apps found with description containing '$notesKeyword'. Exiting." -ForegroundColor Yellow
exit
}

Write-Host "[INFO] Matched apps: $($matchedApps.Count)" -ForegroundColor Green

#----------------------------------------------------------
# STEP 4 - Check Assignments and Creation Date for Each App
#----------------------------------------------------------
Write-Host "`n[INFO] Checking assignments and creation dates..." -ForegroundColor Cyan

$today = Get-Date
$results = [System.Collections.Generic.List[object]]::new()

foreach ($app in $matchedApps) {

# --- Creation Date ---
$createdDate = $null
$daysSinceCreation = $null
$ageStatus = "Unknown"

if ($app.createdDateTime) {
$createdDate = [datetime]$app.createdDateTime
$daysSinceCreation = ($today - $createdDate).Days
$ageStatus = if ($daysSinceCreation -ge $StaleDaysThreshold) { "STALE" } else { "Recent" }
}

# --- Assignments ---
try {
$assignments = Get-MgDeviceAppManagementMobileAppAssignment `
-MobileAppId $app.id `
-ErrorAction Stop

$assignmentCount = $assignments.Count
$assignmentStatus = if ($assignmentCount -gt 0) { "Assigned" } else { "No Assignment" }

# Pull group names if assigned
$assignedGroups = if ($assignmentCount -gt 0) {
($assignments | ForEach-Object { $_.Target.AdditionalProperties["groupId"] }) -join "; "
} else {
"None"
}

} catch {
$assignmentCount = 0
$assignmentStatus = "Error retrieving"
$assignedGroups = "Error"
}

# --- Risk Flag ---
# Flag if stale (60+ days) AND has no assignment
$riskFlag = if ($ageStatus -eq "STALE" -and $assignmentStatus -eq "No Assignment") {
"*** REVIEW FOR DELETION ***"
} elseif ($ageStatus -eq "STALE" -and $assignmentStatus -eq "Assigned") {
"Stale but Assigned"
} elseif ($ageStatus -eq "Recent" -and $assignmentStatus -eq "No Assignment") {
"New - No Assignment Yet"
} else {
"OK"
}

$results.Add([PSCustomObject]@{
AppName = $app.displayName
AppId = $app.id
Description = $app.description
Publisher = $app.publisher
CreatedDate = if ($createdDate) { $createdDate.ToString("yyyy-MM-dd") } else { "N/A" }
DaysSinceCreation = $daysSinceCreation
AgeStatus = $ageStatus
AssignmentStatus = $assignmentStatus
AssignmentCount = $assignmentCount
AssignedGroups = $assignedGroups
RiskFlag = $riskFlag
})

# Visual indicator per app
$color = switch ($riskFlag) {
"*** REVIEW FOR DELETION ***" { "Red" }
"Stale but Assigned" { "Yellow" }
"New - No Assignment Yet" { "Yellow" }
default { "Green" }
}
Write-Host " [$riskFlag] $($app.displayName) | Created: $($createdDate?.ToString('yyyy-MM-dd')) | Days: $daysSinceCreation | Assignments: $assignmentCount" -ForegroundColor $color
}

#----------------------------------------------------------
# STEP 5 - Summary Report to Console
#----------------------------------------------------------
$reviewCount = ($results | Where-Object { $_.RiskFlag -eq "*** REVIEW FOR DELETION ***" }).Count
$assignedCount = ($results | Where-Object { $_.AssignmentStatus -eq "Assigned" }).Count
$noAssignCount = ($results | Where-Object { $_.AssignmentStatus -eq "No Assignment" }).Count

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " AUDIT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Keyword Searched : $notesKeyword"
Write-Host " Stale Threshold : $StaleDaysThreshold days"
Write-Host " Total Matched : $($results.Count)"
Write-Host " Assigned : $assignedCount" -ForegroundColor Green
Write-Host " No Assignment : $noAssignCount" -ForegroundColor Yellow
Write-Host " Flagged for Review : $reviewCount" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Cyan

# Show flagged apps prominently
if ($reviewCount -gt 0) {
Write-Host "APPS FLAGGED FOR REVIEW:" -ForegroundColor Red
$results | Where-Object { $_.RiskFlag -eq "*** REVIEW FOR DELETION ***" } |
Format-Table AppName, CreatedDate, DaysSinceCreation, AssignmentStatus -AutoSize
}

#----------------------------------------------------------
# STEP 6 - Export to CSV
#----------------------------------------------------------
if ($ExportCSV) {
$path = ".\IntuneAppAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $path -NoTypeInformation
Write-Host "[INFO] Full report exported to: $path" -ForegroundColor Cyan
} else {
$export = Read-Host "Export full results to CSV? (Y/N)"
if ($export -eq "Y") {
$path = ".\IntuneAppAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $path -NoTypeInformation
Write-Host "[INFO] Full report exported to: $path" -ForegroundColor Cyan
}
}
