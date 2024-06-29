<#
########################################################################################################################
Function that can be run to change the priorty of package if you wanted them all to be a certain priority. 

You will need to Run Function
Example of Command Line
Invoke-CMPackagePriority -Path 'C:\CMPKGPriority.txt'
Begin Function
########################################################################################################################
<#
.SYNOPSIS
This script does some really cool stuff.

.DESCRIPTION
This Function is to provide the ability to update priority to packages within Configuration Manager.  When you get a new DP, If you have High Prioirty set no all packages, they will all go at the same time and will not be able to set higher priority to possible ones you need to get out into environment sooner than later. 


.PARAMETER InputPath
Specifies Path of Conifugration Package IDs 

.EXAMPLE
Invoke-CMPackagePriority -Path 'C:\CMPKGPriority.txt'

.NOTES
Function that can be run to change the priorty of package if you wanted them all to be a certain priority. 
#>

Function Invoke-CMPackagePriority {

Param 
  (
  [Parameter(Mandatory=$true,Position=0)]
  $Path,
  [Parameter(Mandatory=$true,Position=1)]
  [ValidateSet('Low','Normal','High')]
  $Priority
  )

# Name is Drive and Locatin Configuratin Manager Site Server Installation Director for Console
Import-Module -Name F:\SCCM\AdminConsole\Bin\ConfigurationManager.psd1

Try {
    IF (Test-Path -Path 'SiteCode:\')
      {
      Set-Location -Path SiteCode:\'
      }
    Else 
      {
      Write-Output "SiteCode Drive does not exist"
      }

Catch
  {
  Write-Output "Unable to Set ConfgMgr Drive"
  }

# Setting Variable for package list of package that you want to chang priority
  $PackageList = Get-Content -Path $Path

  For-Each (item in $Packagelist)
    {
    Get-CMPackage -Id $Item | Set-CMPackage -Priority $Priority -ErrorAction Continue
    }
  } #End Function
  
