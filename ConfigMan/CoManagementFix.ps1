
$Devices = Get-Content -Path "C:\path\to\your\device_list.txt"

foreach ($ComputerName in $Devices) 
{
Invoke-Command $ComputerName -ScriptBlock 
    {
    $Guid = Get-ChildItem HKLM:\Software\Microsoft\Enrollments |  ForEach-Object {Get-ItemProperty $_.pspath} |             Where-Object {$_.DiscoveryServiceFullURL} | Foreach-Object {$_.PSChildName}
    Write-Host $_.Name0 
    Write-Host $_.$Guid
        If ($Guid) 
        {
            Remove-Item -Path "HKLM:\Software\Microsoft\Enrollments\$guid" -Recurse
            Start-Sleep -Seconds 1
            Start-Process -FilePath 'c:\windows\CCMSETUP\ccmsetup.exe' -ArgumentList '/forceinstall cminstalldir=c:\windows\ccm ccmloglevel=0 cclogmaxsize=5242880 disablesiteopt=true DisableCache0pt=True smscachedir=c:\windows\ccmcache smscachesize=25 smscacheflags=PERCENTDISKSPACE SMSSITECODE=Auto' -Wait 
        }
    }
}
