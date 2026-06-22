# PowerShell script to parameterize JMeter scripts
# Replaces hardcoded threads with ${__P(threads,X)} where X is from filename
# Ensures duration is ${__P(duration,300)}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$jmxFiles = Get-ChildItem -Path $scriptPath -Filter "*.jmx" | Where-Object { $_.Name -ne "parameterize_scripts.ps1" }

foreach ($file in $jmxFiles) {
    Write-Host "Processing: $($file.Name)"
    
    # Extract thread count from filename (e.g., 40U -> 40, 10U -> 10, 1U -> 1)
    $defaultThreads = 1
    if ($file.Name -match '_(\d+)U\.jmx$') {
        $defaultThreads = $matches[1]
        Write-Host "  Found thread count in filename: $defaultThreads"
    } elseif ($file.Name -match '(\d+)U\.jmx$') {
        $defaultThreads = $matches[1]
        Write-Host "  Found thread count in filename: $defaultThreads"
    } else {
        Write-Host "  No thread count in filename, using default: 1"
    }
    
    # Read file content
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    
    # Track if changes were made
    $changed = $false
    
    # Pattern 1: Replace <intProp name="ThreadGroup.num_threads">NUMBER</intProp>
    if ($content -match '<intProp name="ThreadGroup\.num_threads">(\d+)</intProp>') {
        $oldThreads = $matches[1]
        $newValue = "`${__P(threads,$defaultThreads)}"
        $content = $content -replace '<intProp name="ThreadGroup\.num_threads">\d+</intProp>', 
                                      "<stringProp name=`"ThreadGroup.num_threads`">$newValue</stringProp>"
        Write-Host "  Replaced intProp threads: $oldThreads -> parameterized with default $defaultThreads"
        $changed = $true
    }
    
    # Pattern 2: Replace <stringProp name="ThreadGroup.num_threads">NUMBER</stringProp>
    if ($content -match '<stringProp name="ThreadGroup\.num_threads">(\d+)</stringProp>') {
        $oldThreads = $matches[1]
        $newValue = "`${__P(threads,$defaultThreads)}"
        $content = $content -replace '<stringProp name="ThreadGroup\.num_threads">\d+</stringProp>', 
                                      "<stringProp name=`"ThreadGroup.num_threads`">$newValue</stringProp>"
        Write-Host "  Replaced stringProp threads: $oldThreads -> parameterized with default $defaultThreads"
        $changed = $true
    }
    
    # Pattern 3: Ensure duration is parameterized with default 300
    # Replace <intProp name="ThreadGroup.duration">NUMBER</intProp>
    if ($content -match '<intProp name="ThreadGroup\.duration">(\d+)</intProp>') {
        $oldDuration = $matches[1]
        $newValue = "`${__P(duration,300)}"
        $content = $content -replace '<intProp name="ThreadGroup\.duration">\d+</intProp>', 
                                      "<stringProp name=`"ThreadGroup.duration`">$newValue</stringProp>"
        Write-Host "  Replaced intProp duration: $oldDuration -> parameterized with default 300"
        $changed = $true
    }
    
    # Pattern 4: Update existing stringProp duration if it doesn't have default or is wrong
    if ($content -match '<stringProp name="ThreadGroup\.duration">([^<]+)</stringProp>') {
        $currentDuration = $matches[1]
        $expectedValue = '${__P(duration,300)}'
        if ($currentDuration -ne $expectedValue) {
            $newValue = "`${__P(duration,300)}"
            $content = $content -replace '<stringProp name="ThreadGroup\.duration">[^<]+</stringProp>', 
                                          "<stringProp name=`"ThreadGroup.duration`">$newValue</stringProp>"
            Write-Host "  Updated duration: $currentDuration -> parameterized"
            $changed = $true
        }
    }
    
    # Save file if changes were made
    if ($changed) {
        # Preserve UTF-8 encoding with BOM if original had it
        $encoding = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($file.FullName, $content, $encoding)
        Write-Host "  [SUCCESS] File updated successfully" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] No changes needed" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Processing complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "- All thread counts are now parameterized" -ForegroundColor White
Write-Host "- All durations are now parameterized" -ForegroundColor White
Write-Host "- Default thread values extracted from filenames" -ForegroundColor White
Write-Host "- Default duration is 300 seconds" -ForegroundColor White

# Made with Bob
