## How to Read CCMSETUP.log with last 50 lines
Invoke-Command -ComputerName DeviceName -Scriptblock {Get-Content -Path 'C:\Windows\CCMSetup\Logs\ccmsetup.log' -Tail 50}