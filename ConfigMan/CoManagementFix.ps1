
$devices = Get-Content -Path "C:\path\to\your\device_list.txt"

foreach ($ComputerName in $devices) 
{
Invoke-Command  $ComputerName  -ScriptBlock 
    {
    $guid = Get-ChildItem HKLM:\Software Microsoft\Enrollments |  ForEach-Object {Get-ItemProperty $_.pspath} | Where-Object {$_.DiscoveryServiceFullURL} | Foreach-Object {$_.PSChildName}
    write-host $_.name0 
    Write-Host $_.$guid
        If ($guid) 
        {
            Remove-Item -Path "HKLM:\Software\Microsoft\Enrollments\$guid" -Recurse
            Start-Sleep -Seconds 5
            Start-Process -FilePath 'c:\windows\CCMSETUP\ccmsetup.exe' -ArgumentList '/forceinstall cminstalldir=c:\windows\ccm ccmloglevel=0 cclogmaxsize=5242880 disablesiteopt=true DisableCache0pt=True smscachedir=c:\windows\ccmcache smscachesize=25 smscacheflags=PERCENTDISKSPACE SMSSITECODE=Auto' -Wait 
        }
    }
}
