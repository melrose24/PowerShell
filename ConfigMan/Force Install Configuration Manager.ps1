## Force Install Configuration Manager Remotely
Invoke-Command -ComputerName DeviceName.fqdn -Scriptblock {Start-Process -FilePath 'c:\windows\ccmsetup\ccmsetup.exe' -ArgumentList '/forceinstall ccminstalldir=c:\windows\ccm ccmloglevel=0 ccmlogmaxsize=5242880 disablesiteopr=True DisableCacheOpt=true smscachedir=c:\windows smscachesize=25 smscacheflags=PERCENTDISKSPACE SMSSITECODE=AUTO' -Wait}


## Force Install Local Machine
Start-Process -FilePath 'c:\windows\ccmsetup\ccmsetup.exe' -ArgumentList '/forceinstall ccminstalldir=c:\windows\ccm ccmloglevel=0 ccmlogmaxsize=5242880 disablesiteopr=True DisableCacheOpt=true smscachedir=c:\windows smscachesize=25 smscacheflags=PERCENTDISKSPACE SMSSITECODE=AUTO' -Wait

### CCMVersion Check
Invoke-Command -ComputerName DeviceName.fqdn -Scriptblock {(Get-ItemProperty -Path 'HKLM:\Software\Microsoft\SMS\Mobile Client').SMSClientVersion}
