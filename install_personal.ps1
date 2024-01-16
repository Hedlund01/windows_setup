
#Install boxstarter
. { Invoke-WebRequest -useb https://boxstarter.org/bootstrapper.ps1 } | Invoke-Expression; Get-Boxstarter -Force

Write-Output "Installing apps..."
.\scripts\personal.ps1