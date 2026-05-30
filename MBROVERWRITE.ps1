# ================================================
#  Wipe Disk!
# ================================================

function Get-PhysicalDrives {
    $drives = @()
    
    try {
        $physicalDisks = Get-PhysicalDisk
        
        foreach ($disk in $physicalDisks) {
            $drives += @{
                Number     = $disk.Number
                Name       = "PhysicalDrive$($disk.Number)"
                Model      = $disk.FriendlyName
                SizeGB     = [math]::Round($disk.Size / 1GB, 2)
                SizeBytes  = $disk.Size
                Status     = $disk.OperationalStatus
                MediaType  = $disk.MediaType
            }
        }
    }
    catch {
        Write-Host "Warning: Falling back to legacy detection" -ForegroundColor Yellow
        # Fallback (your original method)
        for ($i = 0; $i -lt 20; $i++) {
            try {
                $handle = [System.IO.File]::Open("\\.\PhysicalDrive$i", 'Open', 'Read')
                $handle.Close()
                $drives += @{
                    Number = $i
                    Name = "PhysicalDrive$i"
                    Model = "Unknown"
                    SizeGB = "Unknown"
                    SizeBytes = 0
                    Status = "Online"
                    MediaType = "Unknown"
                }
            } catch {}
        }
    }
    
    return $drives
}

function Show-DriveMenu {
    param([array]$Drives)
    
    $selectedIndex = 0
    
    while ($true) {
        Clear-Host
        Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                           Wipe the disk!                              ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host " ↑↓ Navigate | ENTER Select | ESC Cancel" -ForegroundColor Yellow
        Write-Host ""
        
        for ($i = 0; $i -lt $Drives.Count; $i++) {
            $d = $Drives[$i]
            
            if ($i -eq $selectedIndex) {
                Write-Host " ► $($d.Name)" -BackgroundColor Red -ForegroundColor White -NoNewline
                Write-Host " | $($d.Model) | $($d.SizeGB) GB | $($d.MediaType)" -ForegroundColor Red
            } else {
                Write-Host "   $($d.Name) | $($d.Model) | $($d.SizeGB) GB | $($d.MediaType)" -ForegroundColor Gray
            }
        }
        
        Write-Host "`n"
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { if ($selectedIndex -gt 0) { $selectedIndex-- } }           # Up
            40 { if ($selectedIndex -lt $Drives.Count-1) { $selectedIndex++ } } # Down
            13 { return $Drives[$selectedIndex] }                           # Enter
            27 { 
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                exit 
            }
        }
    }
}

function Confirm-DriveWipe {
    param([hashtable]$Drive)
    
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                           CRITICAL WARNING                            ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "You are about to permanently destroy ALL data on:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Drive : $($Drive.Name)" -ForegroundColor White
    Write-Host "    Model : $($Drive.Model)" -ForegroundColor White
    Write-Host "    Size  : $($Drive.SizeGB) GB" -ForegroundColor White
    Write-Host ""
    Write-Host "This action is IRREVERSIBLE and will make the drive completely blank." -ForegroundColor Red
    Write-Host ""
    
    $confirm = Read-Host "Type 'WIPE' in all caps to proceed"
    return $confirm -eq "WIPE"
}

function Wipe-FullDrive {
    param([hashtable]$Drive)
    
    $drivePath = "\\.\$($Drive.Name)"
    
    try {
        $handle = [System.IO.File]::Open($drivePath, 'Open', 'Write')
        
        $bufferSize = 4MB
        $zeroBuffer = New-Object byte[] $bufferSize
        $totalBytes = $Drive.SizeBytes
        $bytesWritten = 0
        
        Write-Host "`nStarting full wipe of $($Drive.Name) ($($Drive.SizeGB) GB)..." -ForegroundColor Cyan
        
        while ($bytesWritten -lt $totalBytes) {
            $remaining = $totalBytes - $bytesWritten
            $toWrite = [Math]::Min($bufferSize, $remaining)
            
            $handle.Write($zeroBuffer, 0, $toWrite)
            $bytesWritten += $toWrite
            
            $percent = [Math]::Round(($bytesWritten / $totalBytes) * 100, 2)
            Write-Progress -Activity "Wiping Drive" -Status "$percent% Complete" `
                          -PercentComplete $percent `
                          -CurrentOperation "$([Math]::Round($bytesWritten/1GB,2)) GB wiped"
        }
        
        $handle.Flush()
        Write-Progress -Activity "Wiping Drive" -Completed
        
        Write-Host "`n✓ Drive wipe completed successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        if ($handle) { 
            $handle.Close() 
            $handle.Dispose() 
        }
    }
}

# ====================== MAIN ======================
Clear-Host

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")) {
    Write-Host "This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

$drives = Get-PhysicalDrives

if ($drives.Count -eq 0) {
    Write-Host "No drives detected." -ForegroundColor Red
    exit 1
}

$selected = Show-DriveMenu -Drives $drives

if (-not (Confirm-DriveWipe -Drive $selected)) {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

Wipe-FullDrive -Drive $selected

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
