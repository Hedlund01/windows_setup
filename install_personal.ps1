
#Install boxstarter
. { Invoke-WebRequest -useb https://boxstarter.org/bootstrapper.ps1 } | Invoke-Expression; Get-Boxstarter -Force


Install-BoxstarterPackage -PackageName .\scripts\personal.ps1 -DisableReboots
# Install-BoxstarterPackage -PackageName .\scripts\install_font.ps1 -DisableReboots
Install-BoxstarterPackage -PackageName .\scripts\update_windows_terminal.ps1 -DisableReboots