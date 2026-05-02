<#
.SYNOPSIS
Gettings some computer information to gather last time system rebooted and OS Version

.DESCRIPTION
Gettings some computer information to gather last time system rebooted and OS Version

.NOTES
Get-ComputerInfo can be ran locally but Invoke-Command is required to run remotely and powershell must be opened with admin Creds. 
#>

Invoke-Command -ComputerName DeviceName.FQDN -Scriptblock {Get-ComputerInfo} | Select-Object 
CSModel,
CSName,
CSPowerstate,
CSSystemSKUNumber,
CSUserName,
OSVersion,
OSLastBootUpTime,
OSUptime,
OSFreeVirtualMemory,
OSIntallDate,
Timezone
