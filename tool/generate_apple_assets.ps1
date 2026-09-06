Add-Type -AssemblyName System.Drawing

$iosIconsDir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
$webIconsDir = "web/icons"
$splashDir = "web/icons/splash"

# Copy specific touch icon resolutions
Copy-Item "$iosIconsDir/Icon-App-60x60@3x.png" "$webIconsDir/apple-touch-icon-180x180.png" -Force
Copy-Item "$iosIconsDir/Icon-App-83.5x83.5@2x.png" "$webIconsDir/apple-touch-icon-167x167.png" -Force
Copy-Item "$iosIconsDir/Icon-App-76x76@2x.png" "$webIconsDir/apple-touch-icon-152x152.png" -Force
Copy-Item "$iosIconsDir/Icon-App-60x60@2x.png" "$webIconsDir/apple-touch-icon-120x120.png" -Force
Copy-Item "$iosIconsDir/Icon-App-60x60@3x.png" "$webIconsDir/apple-touch-icon.png" -Force

Write-Host "Apple touch icons copied successfully."

# Function to generate splash screen with centered icon and background #F7F7F7
$mascotPath = "assets/images/mascot.png"
if (-not (Test-Path $mascotPath)) {
    $mascotPath = "$iosIconsDir/Icon-App-1024x1024@1x.png"
}
$mascotImg = [System.Drawing.Image]::FromFile((Resolve-Path $mascotPath))

function Generate-Splash {
    param(
        [int]$Width,
        [int]$Height,
        [string]$Filename
    )
    
    $outPath = Join-Path $splashDir $Filename
    $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    
    # Background #F7F7F7
    $bgColor = [System.Drawing.Color]::FromArgb(247, 247, 247)
    $bgBrush = New-Object System.Drawing.SolidBrush($bgColor)
    $g.FillRectangle($bgBrush, 0, 0, $Width, $Height)
    
    # Icon size in center (approx 28% of min dimension or max 280px)
    $iconDim = [int]([Math]::Min($Width, $Height) * 0.28)
    if ($iconDim -gt 280) { $iconDim = 280 }
    if ($iconDim -lt 120) { $iconDim = 120 }
    
    $x = [int](($Width - $iconDim) / 2)
    $y = [int](($Height - $iconDim) / 2)
    
    $g.DrawImage($script:mascotImg, $x, $y, $iconDim, $iconDim)
    
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bgBrush.Dispose()
    $bmp.Dispose()
    
    Write-Host "Generated splash: $Filename ($($Width)x$($Height))"
}

# iPhone 16 Pro Max (1320 x 2868)
Generate-Splash -Width 1320 -Height 2868 -Filename "splash-1320x2868.png"

# iPad Pro 11" & iPad Air 10.9" (1668 x 2388)
Generate-Splash -Width 1668 -Height 2388 -Filename "splash-1668x2388.png"

# iPad Pro 12.9" & 13" (2048 x 2732)
Generate-Splash -Width 2048 -Height 2732 -Filename "splash-2048x2732.png"

# iPad 10.2" (1620 x 2160)
Generate-Splash -Width 1620 -Height 2160 -Filename "splash-1620x2160.png"

$mascotImg.Dispose()
Write-Host "All splash screens generated successfully!"
