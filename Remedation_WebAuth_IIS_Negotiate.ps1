try {
    # Import WebAdministration module - IF you need to import remove the # on next line.
    # Import-Module WebAdministration -ErrorAction Stop
    
    # Check if Negotiate already exists to avoid duplicates
    $providers = Get-WebConfigurationProperty `
        -PSPath "IIS:\Sites\Default Web Site" `
        -Filter "system.webServer/security/authentication/windowsAuthentication/providers" `
        -Name "." -ErrorAction Stop
    
    $negotiateExists = $providers.Collection | Where-Object { $_.value -eq "Negotiate" }
    
    if (-not $negotiateExists) {
        # Add Negotiate to the providers list
        Add-WebConfigurationProperty `
            -PSPath "IIS:\Sites\Default Web Site" `
            -Filter "system.webServer/security/authentication/windowsAuthentication/providers" `
            -Name "." `
            -Value @{value="Negotiate"} `
            -ErrorAction Stop
        
        Write-Output "Negotiate provider added successfully"
        Exit 0
    } else {
        Write-Output "Negotiate provider already exists"
        Exit 0
    }
}
catch {
    Write-Output "Failed to add Negotiate provider: $($_.Exception.Message)"
    Exit 1
}
