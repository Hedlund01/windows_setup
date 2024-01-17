# Copy the json file to the Windows Terminal settings directory
$windowsTerminalSettingsDirectory = "$env:UserProfile\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$settingsJsonFileName = "settings.json"

Copy-Item -Path .\files\windows_terminal_settings.json -Destination $windowsTerminalSettingsDirectory\$settingsJsonFileName -Force
Write-Host "Windows Terminal settings JSON file replaced. Restart Windows Terminal to see the changes."-ForegroundColor Yellow