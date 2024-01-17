# function to install fonts
$fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
$downloadDirectory = "$env:TEMP\FiraCode"

# Create the destination directory if it doesn't exist
if (-not (Test-Path -Path $downloadDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $downloadDirectory | Out-Null
}

# Download the font zip file & extract the file
$fontZipPath = Join-Path -Path $downloadDirectory -ChildPath "FiraCode.zip"
Invoke-WebRequest -Uri $fontZipUrl -OutFile $fontZipPath
Write-Host "Extracting font files..."
Expand-Archive -Path $fontZipPath -DestinationPath $downloadDirectory -Force


Add-Font -Path $downloadDirectory

Write-Host "Font installation complete." -ForegroundColor Yellow


   
