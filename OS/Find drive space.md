## Find drive space
Invoke-Command -ComputerName DeviceName.fqdn -ScriptBlock {
    Get-WMIObject -Class win32_logicaldisk | Format-Table DeviceID, MediaType, @{n="size";e={[math]::Round($_.Size/1GB,2)}},@{n="FreeSpace"; e={[math]::Round($_.FreeSpace/1GB,2)}}
}
