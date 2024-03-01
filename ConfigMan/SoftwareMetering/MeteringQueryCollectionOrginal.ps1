
################################################
function Random-StartTime
{
	[string]$RandomHour = (Get-Random -Maximum 23) 
	[string]$RandomMinute = (Get-Random -Maximum 59)
	[string]$RandomStartTime = $RandomHour + ":" + $RandomMinute
	return $RandomStartTime
}
#Get the sitecode
Get-WMIObject -Namespace "root\SMS" -Class "SMS_ProviderLocation" | foreach-object{if ($_.ProviderForLocalSite -eq $true){$SiteCode=$_.SiteCode}} 

#Import module
Import-Module(Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)

#Variables
$DeviceLimitingCollection = "All Systems"
$CollectionDevFolderName = "Query Rules\Software\Software Meetering"
$CollectionDevFolderPath = $SiteCode + ":" + "\DeviceCollection\$CollectionDevFolderName"
$SoftwareMeteringCommentTrigger = "CMTrace"
$NumberOfDaysSinceUse = 120

#Set location
Set-Location($SiteCode + ":") -ErrorAction Stop

Write-Host "***********************************************START SCRIPT***********************************************"
Write-Host "Running in the context of '$($env:USERNAME)'"

#Check if the collection folder exist
if (!(Test-Path $CollectionDevFolderPath))
{
    #Variables
    $Folders = $CollectionDevFolderPath.Split("\")
    $FolderPath = $null

    #Check each folder for existence
    Foreach($Folder in $Folders){

        #Define this folder path
        $FolderPath += ( $Folder + "\")
        
        #If not there, create it
        if(!(Test-Path $FolderPath.TrimEnd("\"))){
            Write-Host  ("Device collection folder `"$FolderPath`" not existing, creating it..")
            New-Item $FolderPath
        }
    }

}

#All metering rules Get-CMSoftwareInventory
$ManagedMeteringRules = Get-CMSoftwareMeteringRule | Where-Object {$_.Comment -eq $SoftwareMeteringCommentTrigger}

Foreach($Rule in $ManagedMeteringRules){

    #Variables
    $Schedule = New-CMSchedule -Start (Random-StartTime) -RecurInterval Days -RecurCount 1
    $FileName = ($Rule.FileName)
    $ProductName = ($Rule.ProductName)
    $InstalledCollName = ("$ProductName | Installed")
    $LastUseLastXDaysCollName = ("$ProductName | Used in the last $NumberOfDaysSinceUse days")
    $WarningZoneCollName = ("$ProductName | Not used in the last $NumberOfDaysSinceUse days")
    $InstalledQuery = "SELECT SMS_R_SYSTEM.ResourceID, SMS_R_SYSTEM.ResourceType, SMS_R_SYSTEM.Name, SMS_R_SYSTEM.SMSUniqueIdentifier, SMS_R_SYSTEM.ResourceDomainORWorkgroup, SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_INSTALLED_SOFTWARE on SMS_G_System_INSTALLED_SOFTWARE.ResourceId = SMS_R_System.ResourceId where SMS_G_System_INSTALLED_SOFTWARE.ProductName like `"$ProductName`""
    $LastUsageInLastXDaysQuery = "SELECT SMS_R_SYSTEM.ResourceID, SMS_R_SYSTEM.ResourceType, SMS_R_SYSTEM.Name, SMS_R_SYSTEM.SMSUniqueIdentifier, SMS_R_SYSTEM.ResourceDomainORWorkgroup,  SMS_R_SYSTEM.Client from SMS_R_SYSTEM  inner join SMS_MonthlyUsageSummary on SMS_R_SYSTEM.ResourceID = SMS_MonthlyUsageSummary.ResourceID    INNER JOIN SMS_MeteredFiles ON SMS_MonthlyUsageSummary.FileID = SMS_MeteredFile.MeteredFileID WHERE SMS_MeteredFiles.FileName = `"$FileName`"  AND DateDiff(day, SMS_MonthlyUsageSummary.LastUsage, GetDate()) < $NumberOfDaysSinceUse"
    $CollectionDescription = "Auto created"

    #Create the colleciton containing the devices having the softwre installed
    if($Collection = Get-CMDeviceCollection -Name $InstalledCollName){
        
        #The collection already exist
        Write-Host "Device collection '$InstalledCollName', already exist"
    }else{

        #Create the collection
        try {
            Write-Host "Creating device collection '$InstalledCollName' and query"
            $InstallCollection = New-CMDeviceCollection -Name $InstalledCollName -LimitingCollectionName $DeviceLimitingCollection -RefreshType Periodic -RefreshSchedule $Schedule -Comment $CollectionDescription
            Add-CMDeviceCollectionQueryMembershipRule -Collection $InstallCollection -QueryExpression $InstalledQuery -RuleName "Using '$ProductName' productname"
            Move-CMObject -FolderPath $CollectionDevFolderPath -InputObject $InstallCollection
        }
        catch {
            Write-Host ("$_")
        }
    }

    #Create the collection containing users of the software within the last X days
    if($Collection = Get-CMDeviceCollection -Name $LastUseLastXDaysCollName){
    
        #The collection already exist
        Write-Host "Device collection '$LastUseLastXDaysCollName', already exist"
    }else{

        #Create the collection
        try {
            Write-Host "Creating device collection '$LastUseLastXDaysCollName' and query"
            $LastUseXCollection = New-CMDeviceCollection -Name $LastUseLastXDaysCollName -LimitingCollectionName $InstalledCollName -RefreshType Periodic -RefreshSchedule $Schedule -Comment $CollectionDescription
            Add-CMDeviceCollectionQueryMembershipRule -Collection $LastUseXCollection -QueryExpression $LastUsageInLastXDaysQuery -RuleName "Using $FileName"
            Move-CMObject -FolderPath $CollectionDevFolderPath -InputObject $LastUseXCollection
        }
        catch {
            Write-Host ("$_")
        }
    }

    #Create the collection containing users who have not used it in the last X days
    if($Collection = Get-CMDeviceCollection -Name $WarningZoneCollName){
    
        #The collection already exist
        Write-Host "Device collection '$WarningZoneCollName', already exist"
    }else{

        #Create the collection
        try {
            Write-Host "Creating device collection '$WarningZoneCollName' including colls"
            $Collection = New-CMDeviceCollection -Name $WarningZoneCollName -LimitingCollectionName $InstalledCollName -RefreshType Periodic -RefreshSchedule $Schedule -Comment $CollectionDescription
            Add-CMDeviceCollectionIncludeMembershipRule -Collection $Collection -IncludeCollectionName $InstalledCollName
            Add-CMDeviceCollectionExcludeMembershipRule -Collection $Collection -ExcludeCollectionName $LastUseLastXDaysCollName
            Move-CMObject -FolderPath $CollectionDevFolderPath -InputObject $Collection
        }
        catch {
            Write-Host ("$_")
        }
    }
}