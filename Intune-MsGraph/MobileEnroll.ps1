# Requires -Version 5.1
<#
.SYNOPSIS
    Validates a list of device serial numbers against Microsoft Intune
    Apple Enrollment Program (ADE/DEP) using Connect-MgGraph + Invoke-MgGraphRequest.

.DESCRIPTION
    - Connects interactively via Connect-MgGraph (browser/MFA)
    - Discovers depOnboardingSettings (your ABM / carrier token connections)
    - Uses Invoke-MgGraphRequest against the beta endpoint, since importedAppleDeviceIdentities is nested under depOnboardingSettings and has no v1.0 / no standalone Get-Mg* cmdlet:
        GET /beta/deviceManagement/depOnboardingSettings/(1d}/importedAppleDeviceIdentities
    - Reads serial numbers from a CV or TXT file in ~/Downloads
    - Displays results in the terminal
    - Optionally exports results to a timestamped CSV in ~/Downloads

.REQUIREMENTS
Microsoft.Graph module 2x already installed (Microsoft.Graph.Authentication is enough).
Account running script needs: DeviceManagementServiceConfig.Read.All

.USAGE
# Macos
pwsh ./Validate-IntuneSerials.ps1

Input file options (place in ~/Downloads) :
serials.csv- column named SerialNumber
#>

# ---------------------------------------
# CONFIGURATION
# ---------------------------------------

# Change filename here if needed. Supports .csv or .txt. File must be in ~/Downloads or change that path
$InputFile = "$HOME/Downloads/serials.csv"

# ---------------------------------------
# FUNCTIONS
# ---------------------------------------
function Read-SerialNumbers {
    param([string]$Path)
if (-not (Test-Path $Path)) {
Write-Host ""
Write-Host "[ERROR] Input file not found: $Path" -ForegroundColor Red
Write-Host " Place your file in ~/Downloads and update `$InputFile if needed." -ForegroundColor Yellow
Write-Host " Supported formats:" -ForegroundColor Yellow
Write-Host "       serials.csv - column named 'SerialNumber'" -ForegroundColor Yellow
Write-Host "       serials.txt - one serial per line" -ForegroundColor Yellow
exit 1
}

$ext = [System.IO.Path]::GetExtension($Path).ToLower()

if ($ext -eq "-csv") {
    $data = Import-Csv -Path $Path

    if (-not $data -or $data.Count -eq 0) {
Write-Host ""
Write-Host "   [ERROR] CSV file is empty: $Path" -ForegroundColor Red
exit 1
    }

    $col = $data[0].PSObject.Properties.Name |
        Where-Object { $_ -match "^serial" } |
        Select-Object -First 1

if (-not $col) {
Write-Host ""
Write-Host "  [ERROR] CSV must have a column starting with 'Serial' (e.g. SerialNumber)." -ForegroundColor Red
Write-Host " Columns found: $($data[0].PSobject.Properties.Name -join ', ')" -ForegroundColor Yellow
exit 1
}

    return $data.$col |
    Where-Object { $_ -and $_.ToString().Trim() -ne "" } |
    ForEach-Object {$_.ToString().Trim().ToUpper() }
}

elseif ($ext -eq ".txt") {
    return Get-Content -Path $Path |
    Where-Object { $_-and $_.Trim().ToUpper() -ne "" } | 
    ForEach-Object {$_.Trim().ToUpper() }
}
else {
Write-Host ""
Write-Host "  [ERROR] Unsupported file type '$ext'. Use .csv or .txt." -ForegroundColor Red
exit 1
}
}

function Get-DepOnboardingSettings {
<#
.NOTES
    importedAppleDeviceIdentities is NOT a top-level collection.
    Per Microsoft Graph docs, it sits under depOnboardingSettings 
    (one per Apple Business Manager / carrier token connection):
    GET /deviceManagement/depOnboardingSettings{fid}/importedAppleDeviceIdentities
    So we first need the deponboardingSetting id(s).
#>

    $uri= "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSobject -ErrorAction Stop
        return @($response.value)
    }

    catch {
        Write-Host ""
        Write-Host " [ERROR] Failed to retrieve depOnboardingSettings (AB/carrier tokens)." -ForegroundColor Red
        Write-Host " $($_.Exception.Message)" -ForegroundColor Red 
        Write-Host " Ensure your account has DeviceManagementServiceConfig.Read.All and try again." -ForegroundColor Yellow
        exit 1
    }
}

function Get-ADEDevice {
    param(
    [string] $SerialNumber,
    [string[]]$OnboardingSettingIds
    )

  $escapedSerial = $SerialNumber.Replace("'", "''")

  foreach ($settingId in $OnboardingSettingIds) {
    $uri="https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings/$settingId/importedAppleDeviceIdentities" +
        "?`$filter=contains (serialNumber, '$escapedSerial')"

        try {
            $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject -ErrorAction Stop

            if ($response.value -and $response.value.Count -gt 0) {
            # Exact-match locally so we only return the true serial
            $match = @($response.value | Where-Object {$_.serialNumber -eq $SerialNumber })

            if ($match. Count -gt 0) {
                return $match
            }
        }
    }
    catch {
            # Keep checking the remaining onboarding settings instead of stopping on first error
            return @{ _error_=$_.Exception.Message }
    }
}

# Checked all token connections, not found in any
return @()
}
# ---------------------------------------
# MAIN
#---------------------------------------
 Clear-Host
 Write-Host ""
 Write-Host " __________________________________" -ForegroundColor Cyan
 Write-Host "   Intune Enrollment Program - Serial Number Validator" -ForegroundColor Cyan 
 Write-Host "   Your Project" -ForegroundColor Cyan
 Write-Host " __________________________________" -ForegroundColor Cyan
 Write-Host ""

 # Step 1 - Check module
Write-Host " [1/5] Checking Microsoft.Graph.Authentication..." -ForegroundColor DarkCyan
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host ""
    Write-Host " [ERROR] Microsoft.Graph. Authentication module not found." -ForegroundColor Red 
    Write-Host " Install with: Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Yellow 
    exit 1
}

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Write-Host "           Module loaded." -ForegroundColor Green

# Step 2 - Authenticate
Write-Host ""
Write-Host " [2/5] Connecting to Microsoft Graph..." -ForegroundColor DarkCyan
Write-Host "           A browser window will open for sign-in / MFA." -ForegroundColor DarkGray
Write-Host ""
try {
    Connect-MgGraph -Scopes "DeviceManagementServiceConfig.Read.ALL" -Nowelcome -ErrorAction Stop
    $ctx = Get-MgContext
    Write-Host "         Signed in as : $($ctx.Account)" -ForegroundColor Green
    Write-Host "         Tenant ID     : $($ctx.Tenant.Id)" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host " [ERROR] Failed to connect to Microsoft Graph." -ForegroundColor Red
    Exit 1
}

# Step 3 - Load serials
Write-Host ""
Write-Host "    [3/51 Reading serial numbers from: $InputFile" -ForegroundColor DarkCyan
$serials = @(Read-Serialnumbers -Path $InputFile)
Write-Host "$($serials.Count) serial(s) loaded." -ForegroundColor Green

if (-not $serials -or $serials.Count -eq 0) {
Write-Host ""
Write-Host "   (ERROR] No serial numbers were found in the input file." -ForegroundColor Red
Exit 1
}

# Step 4 - Query Intune ADE
Write-Host ""
Write-Host "     [4/5] Discovering Apple Business Manager / carrier token connections..." -ForegroundColor DarkCyan
$onboardingSettings = @(Get-DepOnboardingSettings)

if (-not $onboardingSettings -or $onboardingSettings.Count -eq 0) {
Write-Host ""
Write-Host "    [ERROR] No depOnboardingSettings (ABM/carrier tokens) found in this tenant." -ForegroundColor Red
Write-Host " Nothing to validate against." -ForegroundColor Red 
exit 1
}

$onboardingIds = @($onboardingSettings| Select-Object -ExpandProperty id)

Write-Host "      Found $($onboardingSettings.Count) token connection(s):" -ForegroundColor Green
foreach ($s in $onboardingSettings) {
    Write-Host "      • $($s.tokenName) [id: $($s.id)]" -ForegroundColor DarkGreen
}

Write-Host ""
Write-Host "     [5/5] Querying Intune Apple Enrollment Program (ADE/DEP)..." -ForegroundColor DarkCyan
Write-Host ""
Write-Host " __________________________________________________" -ForegroundColor DarkCyan

$results = [System.Collections.Generic.List [PSCustomObject]]:: new()
$found   = 0
$missing = 0
$errors  = 0
$total   = $serials.Count
$i       = 0

foreach ($serial in $serials) {
    $i++
    Write-Host -NoNewline " [$i/$total] $serial -> "

    $device = Get-ADEDevice -SerialNumber $serial -OnboardingSettingIds $onboardingIds

    # Error returned from function
    if ($device -is [hashtable] -and $device.Containskey('_error_')){
    Write-Host "ERROR" -ForegroundColor Red
    Write-Host "          $($device._error_)" -ForegroundColor DarkRed

    $results.Add([PSCustomObject]@{
        SerialNumber        = $serial
        Status              = "ERROR"
        Description         = ""
        Platform            = ""
        EnrollmentStatus    = ""
        CreatedDateTime     = ""
        LastModified        = ""
        Note                = $device._error_
    })
    $errors++
    }

# Found in ADE

elseif ($device -and $device.Count -gt 0) {
$d = $device[0]
Write-Host "FOUND" -ForegroundColor Green
Write-Host "        Description: $($d.description) | Platform: $($d.platform) | State: $($d.enrollmentState)" -ForegroundColor DarkGreen

$results.Add([PSCustomObject]@{
SerialNumber        = $serial
Status              = "Found"
Description         = $d.description
Platform            = $d.platform
EnrollmentState     = $d.enrollmentState
CreatedDateTime     = $d.createDateTime
LastModified        = $d.lastModifiedDateTime
Note                = ""
})
$found++
}

# Not in ADE
else {
    Write-Host "Not Found" -ForegroundColor Red
    Write-Host " Not in ADE/Enrollement program - will behave as a personal device!" -ForegroundColor Yellow

    $results.Add([PSCustomObject]@{
    SerialNumber        = $serial
    Status              = "Not Found"
    Description         = ""
    Platform            = ""
    EnrollmentState     = ""
    CreatedDateTime     = ""
    LastModified        = ""
    Note                = "Not in Apple Enrollment Program - contact carrier"
    })
    $missing++
}
}

# -----------------------
# Summary 
# -----------------------
Write-Host ""
Write-Host " ___________________________________" -ForegroundColor DarkGray
Write-Host ""
Write-Host "___________________________________" -ForegroundColor Cyan
Write-Host "     SUMMARY" -ForegroundColor Cyan
Write-Host "___________________________________" -ForegroundColor Cyan
Write-Host " Total checked  : $total"
Write-Host " Found : $found" -ForegroundColor Green
Write-Host " Not Found : $missing" -ForegroundColor Red

if ($errors -gt 0) {
    Write-Host " Errors       : $errors" -ForegroundColor Yellow
}

if ($missing -gt 0) {
    Write-Host ""
    Write-Host " ACTION REQUIRED - serial missing from Intune Enrollment Program" -ForegroundColor Yellow
    $results | 
    Where-Object { $_.Status -eq "Not Found" } |
    ForEach-Object {Write-Host "     • $($_.SerialNumber)" -ForegroundColor Red }
    Write-Host ""
    Write-Host "   Contact the carrier to add these to Apple business Manager / ADE." -ForegroundColor Yellow
}

# -----------------------
# OPTIONAL EXPORT 
# -----------------------

Write-Host ""
$export = Read-Host " Export results to CSV in Downloads? (Y/N)"

If ($export -match "^[Yy]") {
    $timestamp = Get-Date -Format"yyyyMMdd_HHmmss"
    $outputFile = "$HOME/Downloads/IntuneSerialValidation_$timestamp.csv"

    $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host " Exported - $outputFile" -ForegroundColor Green
}

#Disconnect cleanly
Write-Host ""
Disconnect-MgGraph | Out-Null
Write-Host " Session disconnected." -ForegroundColor DarkGray
Write-Host ""
Write-Most " Done." -ForegroundColor Cyan
Write-Host ""
