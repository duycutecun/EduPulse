Add-Type -AssemblyName System.Drawing

$filePath = "assets/images/mascot.png"
$img = [System.Drawing.Image]::FromFile((Resolve-Path $filePath))
Write-Host "Original Dimensions: $($img.Width)x$($img.Height)"

$targetDim = 512
if ($img.Width -gt $targetDim -or $img.Height -gt $targetDim) {
    $bmp = New-Object System.Drawing.Bitmap($targetDim, $targetDim)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $targetDim, $targetDim)
    
    $img.Dispose()
    
    $tempPath = "assets/images/mascot_opt.png"
    $bmp.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    
    Move-Item -Path $tempPath -Destination $filePath -Force
    $newStat = Get-Item $filePath
    Write-Host "Optimized mascot.png saved! New size: $($newStat.Length) bytes"
} else {
    $img.Dispose()
    Write-Host "Image is already <= 512x512"
}
