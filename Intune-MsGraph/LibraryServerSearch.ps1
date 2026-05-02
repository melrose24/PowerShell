# Package Path Scanner
# Searches PowerShell scripts in package folders for specific paths

# Can change destination path
$destinationPath = "\\LibraryServer\Packages"
# Can add to search patterns to find specific paths.
$searchPatterns = @("c:\temp\", "c:\drv\")
# Can change output file location
$outputFile = "C:\temp\PackagesWithPaths.csv"

# Initialize CSV file with headers immediately
"PackageName,FoundPaths,ScriptCount" | Out-File -FilePath $outputFile -Encoding UTF8

# Validate destination path exists
if (-not (Test-Path $destinationPath)) {
    Write-Error "Destination path does not exist: $destinationPath"
    exit 1
}

Write-Host "Scanning packages in: $destinationPath" -ForegroundColor Cyan
Write-Host "Searching for patterns: $($searchPatterns -join ', ')" -ForegroundColor Cyan
Write-Host ""

# Get all top-level folders (packages)
$packages = Get-ChildItem -Path $destinationPath -Directory

$results = @()
$processedCount = 0
$totalPackages = $packages.Count

foreach ($package in $packages) {
    $processedCount++
    Write-Progress -Activity "Scanning Packages" -Status "Processing $($package.Name)" -PercentComplete (($processedCount / $totalPackages) * 100)
    
    # Get all PowerShell scripts in this package folder and subfolders
    $psScripts = Get-ChildItem -Path $package.FullName -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
    
    $foundPatterns = @()
    
    foreach ($script in $psScripts) {
        try {
            # Read script content
            $content = Get-Content -Path $script.FullName -Raw -ErrorAction SilentlyContinue
            
            # Check for each search pattern
            foreach ($pattern in $searchPatterns) {
                if ($content -match [regex]::Escape($pattern)) {
                    if ($foundPatterns -notcontains $pattern) {
                        $foundPatterns += $pattern
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not read file: $($script.FullName)"
        }
    }
    
    # If any patterns were found, add to results and export immediately
    if ($foundPatterns.Count -gt 0) {
        $result = [PSCustomObject]@{
            PackageName = $package.Name
            FoundPaths = ($foundPatterns -join "; ")
            ScriptCount = $psScripts.Count
        }
        
        $results += $result
        
        # Export this result immediately to CSV
        $result | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8 -Append
        
        Write-Host "Found in: $($package.Name) - Paths: $($foundPatterns -join ', ')" -ForegroundColor Green
    }
}

Write-Progress -Activity "Scanning Packages" -Completed

# Export results
if ($results.Count -gt 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "Scan Complete!" -ForegroundColor Green
    Write-Host "Total packages scanned: $totalPackages" -ForegroundColor Cyan
    Write-Host "Packages with matching paths: $($results.Count)" -ForegroundColor Cyan
    Write-Host "Results exported to: $outputFile" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    
    # Display summary
    Write-Host ""
    Write-Host "Package List:" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
}
else {
    Write-Host ""
    Write-Host "No packages found containing the specified paths." -ForegroundColor Yellow
}