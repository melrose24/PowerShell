try {
    # Import WebAdministration module if needed
    # Import-Module WebAdministration -ErrorAction Stop
   
    # Check if Windows Authentication is enabled on Default Web Site
    $winAuthEnabled = Get-WebConfigurationProperty `
        -PSPath "IIS:\Sites\Default Web Site" `
        -Filter "system.webServer/security/authentication/windowsAuthentication" `
        -Name "enabled" -ErrorAction Stop
   
    # If Windows Authentication is not enabled, return Non-Compliant
    if ($winAuthEnabled.Value -ne $true) {
        Write-Output "Non-Compliant"
        exit
    }
   
    # Get the Windows Authentication providers for Default Web Site
    $providers = Get-WebConfigurationProperty `
        -PSPath "IIS:\Sites\Default Web Site" `
        -Filter "system.webServer/security/authentication/windowsAuthentication/providers" `
        -Name "." -ErrorAction Stop
   
    # Check if Negotiate provider exists in the enabled providers list
    $negotiateExists = $providers.Collection | Where-Object { $_.value -eq "Negotiate" }
   
    if ($negotiateExists) {
        # Compliant - Windows Auth enabled AND Negotiate provider found
        Write-Output "Compliant"
    } else {
        # Non-Compliant - Negotiate provider not found in enabled providers
        Write-Output "Non-Compliant"
    }
}
catch {
    # Non-Compliant - Error occurred (IIS not installed, site doesn't exist, etc.)
    Write-Output "Non-Compliant"
}
