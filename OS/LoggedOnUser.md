#Results should give you a value if there is a user logged into the system. If it is blank that means there is no one logged in and you can remote into the system. 
Invoke-Command -ComputerName $DeviceName.FQDN -Scriptblock {Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object UserName}

