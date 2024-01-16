#Boxstarter file to install personal apps



Disable-UAC 
$ConfirmPreference = "None" #ensure installing powershell modules don't prompt on needed dependencies

<#
.SYNOPSIS
Retrieves a list of Chocolatey packages.

.DESCRIPTION
This function retrieves a list of Chocolatey packages installed on the system.

.PARAMETER None
This function does not accept any parameters.

.EXAMPLE
Get-ChocoPackages
# Retrieves a list of Chocolatey packages installed on the system.

#>


function Get-ChocoPackages {
    if (get-command clist -ErrorAction:SilentlyContinue) {
        clist -lo -r -all | ForEach-Object {
            $Name, $Version = $_ -split '\|'
            New-Object -TypeName psobject -Property @{
                'Name'    = $Name
                'Version' = $Version
            }
        }
    }
}

function Install-Reusable-Choco-Packages($scriptPath) {
    Write-Host -ForegroundColor:Blue "Executing $scriptPath"
    #Gets the $ChocoInstalls variable from the script in the scripts/reusable folder
    . ".\scripts\reusable\$scriptPath" 
    Write-Host -ForegroundColor:Blue "Installing $($ChocoInstalls.Count) packages from $scriptPath"
    Install-ChocoPackages($ChocoInstalls)
}



<#
.SYNOPSIS
Installs Chocolatey packages.

.DESCRIPTION
This function installs Chocolatey packages using the Chocolatey package manager.

.PARAMETER ChocoInstalls
List of names for Chocolatey packages to install.

.EXAMPLE
Install-ChocoPackages -PackageName "git", "7zip"

This example installs the "git" and "7zip" package using Chocolatey.

#>

function Install-ChocoPackages {
    param(
        [string[]]$ChocoInstalls
    )
    # Don't try to download and install a package if it shows already installed
    $InstalledChocoPackages = (Get-ChocoPackages).Name
    $ChocoInstalls = $ChocoInstalls | Where-Object { $InstalledChocoPackages -notcontains $_ }

    if ($ChocoInstalls.Count -gt 0) {
        # Install $ChocoInstalls packages with Chocolatey
        try {
            choco upgrade $ChocoInstalls -y --limitoutput
        }
        catch {
            Write-Warning "Unable to install software package with Chocolatey: $($_)"
        }
    }
    else {
        Write-Host -ForegroundColor:Green 'There were no packages to install!'
    }
}




Install-Reusable-Choco-Packages("browsers.ps1")
Install-Reusable-Choco-Packages("communication.ps1")
Install-Reusable-Choco-Packages("dev.ps1")

Write-Host -ForegroundColor:Blue "Checking if this is a desktop..."
#Install gaming apps if this is a desktop
if ((Get-Computerinfo).CsPCSystemType -eq "Desktop") {
    Write-Information "This is a desktop, installing gaming apps..."
    Install-Reusable-Choco-Packages("gaming.ps1")
}




# PowerShell Modules to install
# $ModulesToBeInstalled = @(
#     'OhMyPsh'
# )

# Chocolatey places a bunch of crap on the desktop after installing or updating software. This flag allows
#  you to clean that up (Note: this will move *.lnk files from the Public user profile desktop and your own 
#  desktop to a new directory called 'shortcuts' on your desktop. This may or may not be what you want..) 
$ClearDesktopShortcuts = $false


# Should we create a powershell profile?
# Copy the powershell profile from the scripts/reusable folder to the user profile
$CreatePowershellProfile = $TRUE

#Winconfig settings, see https://boxstarter.org/winconfig
try {
    Disable-GameBarTips
    Disable-BingSearch
}
catch {
    Write-Error "Unable to disable game bar tips or bing search: $($_)"
}



# Install/Update PowershellGet and PackageManager if needed
# try {
#     Import-Module PowerShellGet
# }
# catch {
#     throw 'Unable to load PowerShellGet!'
# }

# # Need to set Nuget as a provider before installing modules via PowerShellGet
# $null = Install-PackageProvider NuGet -Force

# # Store a few things for later use
# $SpecialPaths = Get-SpecialPaths
# $packages = Get-Package

# if (@($packages | Where-Object { $_.Name -eq 'PackageManagement' }).Count -eq 0) {
#     Write-Host -ForegroundColor cyan "PackageManager is installed but not being maintained via the PowerShell gallery (so it will never get updated). Forcing the install of this module through the gallery to rectify this now."
#     Install-Module PackageManagement -Force
#     Install-Module PowerShellGet -Force

#     Write-Host -ForegroundColor:Red "PowerShellGet and PackageManagement have been installed from the gallery. You need to close and rerun this script for them to work properly!"
    
#     Invoke-Reboot
# }
# else {
#     $InstalledModules = (Get-InstalledModule).name
#     $ModulesToBeInstalled = $ModulesToBeInstalled | Where-Object { $InstalledModules -notcontains $_ }
#     if ($ModulesToBeInstalled.Count -gt 0) {
#         Write-Host -ForegroundColor:cyan "Installing modules that are not already installed via powershellget. Modules to be installed = $($ModulesToBeInstalled.Count)"
#         Install-Module -Name $ModulesToBeInstalled -AllowClobber -AcceptLicense -ErrorAction:SilentlyContinue
#     }
#     else {
#         Write-Output "No modules were found that needed to be installed."
#     }
# }


# Clear the desktop of shortcuts, move them to a new folder on the desktop
if ($ClearDesktopShortcuts) {
    $Desktop = $SpecialPaths['DesktopDirectory']
    $DesktopShortcuts = Join-Path $Desktop 'Shortcuts'
    if (-not (Test-Path $DesktopShortcuts)) {
        Write-Host -ForegroundColor:Cyan "Creating a new shortcuts folder on your desktop and moving all .lnk files to it: $DesktopShortcuts"
        $null = mkdir $DesktopShortcuts
    }

    Write-Output "Moving .lnk files from $($SpecialPaths['CommonDesktopDirectory']) to the Shortcuts folder"
    Get-ChildItem -Path  $SpecialPaths['CommonDesktopDirectory'] -Filter '*.lnk' | Foreach {
        Move-Item -Path $_.FullName -Destination $DesktopShortcuts -ErrorAction:SilentlyContinue
    }

    Write-Output "Moving .lnk files from $Desktop to the Shortcuts folder"
    Get-ChildItem -Path $Desktop -Filter '*.lnk' | Foreach {
        Move-Item -Path $_.FullName -Destination $DesktopShortcuts -ErrorAction:SilentlyContinue
    }
}



# Copy over the powershell profile if it doesn't exist
if ($CreatePowershellProfile -and (-not (Test-Path $PROFILE))) {
    Write-Host -ForegroundColor:Green -Info 'Creating user powershell profile...'
    # Copy local profile to user profile
    Copy-Item -Path .\scripts\reusable\powershell_profile.ps1 -Destination $PROFILE -Force

    . $PROFILE # Reload the profile
}
else {
    Write-Host -ForegroundColor:Green "Powershell profile already exists, skipping..."
}




Enable-UAC
Enable-MicrosoftUpdate
Install-WindowsUpdate -Full -AcceptEula

if (Test-PendingReboot) {
    Invoke-Reboot
}

Write-Host -BackgroundColor:Red -ForegroundColor:White "Don't forget to configure Windows Terminal, it needs a nerd font to display icons!"

Write-Host -ForegroundColor:Green "Install and configuration complete!"