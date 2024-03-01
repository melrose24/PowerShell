## Remove TS Execution for a package
Invoke-Command -ComputerName DeviceName.fqdn -ScriptBlock {Get-Childitem -NameSpace root\ccm\softmgmtagent -ClassName CCM_TSExecutionRequest | Where contentid -eq 'PKGID'} | Remove-WmiObject

##Recycle CCMExec Service 
Get-Service -ComputerName Devicename.fqdn -Name ccmexec | Restart-Service 

### Waiting 3 minutes to give ccmexec time to start up
Start-Sleep -s 90

##Request Machine Assignments
Invoke-Command -Computername DeviceName -ScriptBlock {Invoke-WmiMethod -NameSpace root\ccm -Class SMS_Client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}"}
## Evaluate Machine Policies
Invoke-Command -Computername DeviceName -ScriptBlock {Invoke-WmiMethod -NameSpace root\ccm -Class SMS_Client -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}"}

## Giving policy time to show up on the device
Start-Sleep -s 60

## Invoking the deploymenbt to rerun
Invoke-Command  -Computername DeviceName.fqdn -ScriptBlock {Invoke-WmiMethod -NameSpace root\ccm -class sms_client -name TriggerSchedule -ArgumentList "DeploymentID-PkgID-6F6BCC29"}
