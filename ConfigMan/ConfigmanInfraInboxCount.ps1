## Can Do an Invoke Command from another server or device that has access


## Just copy in one of inboxes 
Invoke-Command -ComputerName DeviceName.fqdn -ScriptBlock { }


(Get-ChildItem -Path F:\SCCM\inboxes\auth\dataldr.box\process -recurse).Count 
(Get-ChildItem -Path F:\SCCM\inboxes\auth\dataldr.box -recurse).Count 
(Get-ChildItem -Path F:\SCCM\inboxes\auth\statesys.box\process\ -recurse).Count 


(Get-ChildItem -Path F:\SCCM\inboxes\auth\statesys.box\incoming\ -recurse).Count 

(Get-ChildItem -Path F:\SCCM\inboxes\auth\statmsg.box -recurse).Count