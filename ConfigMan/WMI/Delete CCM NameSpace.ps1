## Verify if CCM NameSpace exists
Get-Ciminstance -query "Select * from __NameSpace where Name = 'CCM'" -NameSpace Computername.Domain

## Removing CCM NameSpace
Get-Ciminstance -query "Select * from __NameSpace where Name = 'CCM'" -NameSpace Computername.Domain | Remove-WmiObject

