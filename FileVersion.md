## MS EDGE
Invoke-Command -ComputerName DeviceName.fqdn -Scriptblock {(Get-Item -path 'c:\program files (x86)\Microsoft\Edge\Application\MSEdge.exe').Version}

