Invoke-Command -ComputerName DeviceName.fqdn -ScriptBlock { 
    ## set up the different possible types of licenses in an array:  
    
    $licenseStatus=@{0="Unlicensed"; 1="Licensed"; 2="00BGrace"; 3="00TGrace";  
                                     4="NonGenuineGrace"; 5="Notification"; 6="ExtendedGrace"} 

  # Now get the license details and assign the object to $r 
  $r=Get-CimInstance -Class SoftwareLicensingProduct | Where-Object {$_.ApplicationID -eq "55c92734-d682-4d71-983e-d6ec3f16059f" -AND $_. PartialProductKey -ne $null} 
  
  # Now apply the value of $r. Licensestatus to the SlicenseStatus array 
  
  Write-Host $licenseStatus[[int]$r.LicenseStatus]

  # You could equally well reeturn this as a value from a function

}