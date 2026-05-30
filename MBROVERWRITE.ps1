# Full Drive Wipe Tool with Interactive Drive Selection
# This script allows users to safely select a drive and wipe all sectors

function Get-PhysicalDrives {
    <#
    .SYNOPSIS
    Retrieves all available physical drives on the system
    #>
    $drives = @()
    $driveCount = 0
    
    # Try to get drives using WMI
    try {
        $wmiDrives = Get-WmiObject Win32_DiskDrive -ErrorAction SilentlyContinue
        if ($wmiDrives) {
            foreach ($drive in $wmiDrives) {
                $drives += @{
                    Number = $drive.Index
                    Name = "PhysicalDrive$($drive.Index)"
                    Model = $drive.Model
                    Size = [math]::Round($drive.Size / 1GB, 2)
                    SizeBytes = $drive.Size
                    Status = $drive.Status
                }
            }
        }
    } catch {
        Write-Host "Warning: Could not retrieve drive info via WMI" -ForegroundColor Yellow
    }
    
    # Fallback: enumerate available drives
    if ($drives.Count -eq 0) {
        for ($i = 0; $i -lt 10; $i++) {
            try {
                $handle = [System.IO.File]::Open("\\.\PhysicalDrive$i", 
                    [System.IO.FileMode]::Open, 
                    [System.IO.FileAccess]::Read)
                $handle.Close()
                $drives += @{
                    Number = $i
                    Name = "PhysicalDrive$i"
                    Model = "Unknown"
                    Size = "Unknown"
                    SizeBytes = 0
                    Status = "Online"
                }
            } catch {
                # Drive not accessible, continue
            }
        }
    }
    
    return $drives
}

function Show-DriveMenu {
    <#
    .SYNOPSIS
    Displays an interactive menu for drive selection using arrow keys
    #>
    param(
        [array]$Drives
    )
    
    $selectedIndex = 0
    $menuVisible = $true
    
    while ($menuVisible) {
        Clear-Host
        Write-Host "╔═══════════════════════════════════════════════════════════════════════╗"
        Write-Host "║          FULL DRIVE WIPE - SELECT TARGET DRIVE                        ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════════════════════╝"
        Write-Host ""
        Write-Host "Use ↑↓ Arrow Keys to navigate | Press ENTER to select | Press ESC to cancel" -ForegroundColor Yellow
        Write-Host ""
        
        for ($i = 0; $i -lt $Drives.Count; $i++) {
            $drive = $Drives[$i]
            
            if ($i -eq $selectedIndex) {
                Write-Host "► " -ForegroundColor Green -NoNewline
                Write-Host "$($drive.Name)" -BackgroundColor Green -ForegroundColor Black -NoNewline
                Write-Host " | Model: $($drive.Model) | Size: $($drive.Size)GB | Status: $($drive.Status)" -ForegroundColor Green
            } else {
                Write-Host "  $($drive.Name) | Model: $($drive.Model) | Size: $($drive.Size)GB | Status: $($drive.Status)" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        
        # Handle keyboard input
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                }
            }
            40 { # Down arrow
                if ($selectedIndex -lt $Drives.Count - 1) {
                    $selectedIndex++
                }
            }
            13 { # Enter
                return $Drives[$selectedIndex]
            }
            27 { # Escape
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit
            }
        }
    }
}

function Confirm-DriveWipe {
    <#
    .SYNOPSIS
    Displays a confirmation prompt before wiping the selected drive
    #>
    param(
        [hashtable]$Drive
    )
    
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════════════════════╗"
    Write-Host "║                      ⚠️  WARNING ⚠️                                    ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════════════╝"
    Write-Host ""
    Write-Host "You are about to COMPLETELY WIPE the entire drive:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Drive: $($Drive.Name)" -ForegroundColor Cyan
    Write-Host "  Model: $($Drive.Model)" -ForegroundColor Cyan
    Write-Host "  Size:  $($Drive.Size)GB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will overwrite ALL sectors with zeros, destroying all data!" -ForegroundColor Red
    Write-Host "This action CANNOT be undone!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Are you absolutely sure? Type 'yes, wipe everything' to confirm, or press any other key to cancel:" -ForegroundColor Yellow
    
    $confirmation = Read-Host
    
    if ($confirmation -eq "yes, wipe everything") {
        return $true
    } else {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return $false
    }
}

function Wipe-FullDrive {
    <#
    .SYNOPSIS
    Wipes all sectors of the selected drive
    #>
    param(
        [hashtable]$Drive
    )
    
    try {
        Write-Host ""
        Write-Host "Beginning full drive wipe of $($Drive.Name)..." -ForegroundColor Cyan
        Write-Host ""
        
        # Open the physical drive
        $drivePath = "\\.\$($Drive.Name)"
        $driveHandle = [System.IO.File]::Open($drivePath, 
            [System.IO.FileMode]::Open, 
            [System.IO.FileAccess]::Write)
        
        try {
            # Create a 1MB buffer of zeros (faster than writing byte by byte)
            $bufferSize = 1MB
            $zeroBuffer = [byte[]]@(0) * $bufferSize
            
            # Get drive size
            $driveSize = $driveHandle.Length
            $bytesWritten = 0
            
            Write-Host "Total drive size: $([math]::Round($driveSize / 1GB, 2))GB"
            Write-Host ""
            
            # Write zeros to entire drive
            while ($bytesWritten -lt $driveSize) {
                $remaining = $driveSize - $bytesWritten
                $toWrite = if ($remaining -lt $bufferSize) { $remaining } else { $bufferSize }
                
                $driveHandle.Write($zeroBuffer, 0, $toWrite)
                $bytesWritten += $toWrite
                
                # Show progress
                $percentComplete = [math]::Round(($bytesWritten / $driveSize) * 100, 2)
                Write-Host -NoNewline "`rProgress: $percentComplete% ($([math]::Round($bytesWritten / 1GB, 2))GB / $([math]::Round($driveSize / 1GB, 2))GB)"
            }
            
            $driveHandle.Flush()
            Write-Host ""
            Write-Host ""
            Write-Host "✓ Full drive wipe completed successfully!" -ForegroundColor Green
            Write-Host "  All sectors on $($Drive.Name) have been overwritten with zeros" -ForegroundColor Green
            return $true
        } finally {
            $driveHandle.Close()
            $driveHandle.Dispose()
        }
    } catch [UnauthorizedAccessException] {
        Write-Host "✗ ERROR: Access Denied" -ForegroundColor Red
        Write-Host "  Please run this script as Administrator" -ForegroundColor Red
        return $false
    } catch [System.IO.FileNotFoundException] {
        Write-Host "✗ ERROR: Drive not found" -ForegroundColor Red
        Write-Host "  The selected drive is not accessible" -ForegroundColor Red
        return $false
    } catch {
        Write-Host "✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Main {
    <#
    .SYNOPSIS
    Main execution function
    #>
    
    # Check if running as Administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        exit
    }
    
    # Get available drives
    Write-Host "Scanning for available drives..." -ForegroundColor Cyan
    $drives = Get-PhysicalDrives
    
    if ($drives.Count -eq 0) {
        Write-Host "ERROR: No physical drives found" -ForegroundColor Red
        exit
    }
    
    # Show interactive menu
    $selectedDrive = Show-DriveMenu -Drives $drives
    
    if (-not $selectedDrive) {
        Write-Host "No drive selected. Exiting." -ForegroundColor Yellow
        exit
    }
    
    # Confirm before wiping
    $confirmWipe = Confirm-DriveWipe -Drive $selectedDrive
    
    if (-not $confirmWipe) {
        exit
    }
    
    # Wipe the entire drive
    $result = Wipe-FullDrive -Drive $selectedDrive
    
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}

# Run main function
Main
