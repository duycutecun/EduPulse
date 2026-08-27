Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path 'web/icons' | Out-Null

function Generate-Icon {
    param(
        [int]$Dimension,
        [string]$OutFile
    )

    $bmp = New-Object System.Drawing.Bitmap($Dimension, $Dimension)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    # Background gradient
    $rect = New-Object System.Drawing.Rectangle(0, 0, $Dimension, $Dimension)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(94, 92, 230),
        [System.Drawing.Color]::FromArgb(10, 132, 255),
        45.0
    )
    
    # Fill rounded background
    $radius = [int]($Dimension * 0.22)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $radius * 2, $radius * 2, 180, 90)
    $path.AddArc($Dimension - $radius * 2, 0, $radius * 2, $radius * 2, 270, 90)
    $path.AddArc($Dimension - $radius * 2, $Dimension - $radius * 2, $radius * 2, $radius * 2, 0, 90)
    $path.AddArc(0, $Dimension - $radius * 2, $radius * 2, $radius * 2, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)

    # Draw text EP
    $fontSize = [float]($Dimension * 0.38)
    $font = New-Object System.Drawing.Font('Arial', $fontSize, [System.Drawing.FontStyle]::Bold)
    $textBrush = [System.Drawing.Brushes]::White
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString('EP', $font, $textBrush, [System.Drawing.RectangleF]::new(0, 0, $Dimension, $Dimension), $sf)

    $bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

Generate-Icon -Dimension 64 -OutFile 'web/favicon.png'
Generate-Icon -Dimension 192 -OutFile 'web/icons/Icon-192.png'
Generate-Icon -Dimension 512 -OutFile 'web/icons/Icon-512.png'
Generate-Icon -Dimension 192 -OutFile 'web/icons/Icon-maskable-192.png'
Generate-Icon -Dimension 512 -OutFile 'web/icons/Icon-maskable-512.png'

Write-Host "Icons generated successfully!"
