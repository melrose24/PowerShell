$DeviceName = DeviceName.FQDN
Invoke-Command -ComputerName $DeviceName -Scriptblock {
(Get-ChildItem -Path C:\FolderLocation\Cache -Recurse | Remove-Item -Force -Recurse -Confirm:$False)
}
#Recycling NomadService is required after you remove content from Nomad Cache location.  Nomad will update the registry key entries so other computers will not try Peer to Peer against that deleted content
Get-Service -Computname $DeviceName -Name NomadBranch | Restart-Service
