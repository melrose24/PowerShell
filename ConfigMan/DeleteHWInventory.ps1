$DeviceName = Device.FQDN
Get-Ciminstance -ComputerName $DeviceName  -NameSpace root\ccm\invagt -Class inventoryactionstatus | 
Where-object {$_.inventoryactionid -eq "{00000000-0000-0000-0000-000000000001}"
#Sleep to ensure it gives it time to delete everything before we request a new one. This will send a new FULL inventory
Start-Sleep -Seconds 5
Invoke-Command -ComputerName $DeviceName -Scriptblock {Invoke-WMIMethod -NameSpace  root\ccm -Class SMS_Client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}"}
