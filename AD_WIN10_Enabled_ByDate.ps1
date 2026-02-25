# Requires the ActiveDirectory module (RSAT or AD DS role)
Import-Module ActiveDirectory

# Define the cutoff date
$CutoffDate = [DateTime]"2026-02-23"

# Query AD for disabled Windows computers with LastLogonDate >= cutoff
$EnabledDevices = Get-ADComputer -Filter {
    Enabled -eq $true -and
    OperatingSystem -like "*Windows 10*"
} -Properties Name, OperatingSystem, OperatingSystemVersion, LastLogonDate, DistinguishedName, Description |
Where-Object {
    $_.LastLogonDate -ne $null -and $_.LastLogonDate -ge $CutoffDate
} |
Select-Object Name,
              OperatingSystem,
              OperatingSystemVersion,
              LastLogonDate,
              DistinguishedName,
              Description |
Sort-Object LastLogonDate -Descending

# Output results to console
$EnabledDevices | Format-Table -AutoSize

# Summary count
Write-Host "Total devices found: $($EnabledDevices.Count)" -ForegroundColor Cyan

# Optional: Export to CSV
# $EnabledDevices | Export-Csv -Path ".\EnabledDevices.csv" -NoTypeInformation
# Write-Host "Results exported to EnabledDevices.csv" -ForegroundColor Green
