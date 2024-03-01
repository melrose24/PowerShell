## Deleting HW Instsance
Invoke-Command -ComputerName DeviceName.FQDN -ScriptBlock {Get-Ciminstance  -Namespace root\ccm\invagt -Class inventoryactionstatus | Where-Object {$_.inventoryactionid -eq "{00000000-0000-0000--0000-000000000001"} | Remove-Ciminstance}

Start-Sleep -Seconds 3 

#Software Inventory Cycle 
Invoke-Command -Computername DeviceName.FQDN -ScriptBlock {Invoke-WmiMethod -NameSpace root\ccm -Class SMS_Client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}" }

