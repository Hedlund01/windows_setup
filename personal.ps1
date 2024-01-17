#Boxstarter file to install personal apps



Disable-UAC 
$ConfirmPreference = "None" #ensure installing powershell modules don't prompt on needed dependencies




#PowerShell Modules to install
$ModulesToBeInstalled = @(
    'PPoShTools' #is needed to install fonts
)

$ChocoInstalls = @(
    'firefox',
    'git',
    '7zip',
    'microsoft-windows-terminal',
    'oh-my-posh',
    'notepadplusplus',
    'openssh',
    'putty',
    'python',
    'terminal-icons.powershell',
    'vscode',
    'nodejs',
    'nvm',
    'yarn',
    'github-desktop',
    'wiztree',
    'mullvad-app',
    'spotify',
    'synologydrive',
    'zoom',
    'discord'

)


Write-Host "Checking if this is a desktop..."
#Install gaming apps if this is a desktop
if ((Get-Computerinfo).CsPCSystemType -eq "Desktop") {
    $ChocoInstalls += @(
        'steam',
        'epicgameslauncher',
        'origin',
        'gog-galaxy',
        'battle.net',
        'blizzard-battlenet'
    )
}


# Chocolatey places a bunch of crap on the desktop after installing or updating software. This flag allows
#  you to clean that up (Note: this will move *.lnk files from the Public user profile desktop and your own 
#  desktop to a new directory called 'shortcuts' on your desktop. This may or may not be what you want..) 
$ClearDesktopShortcuts = $false


# Should we create a powershell profile?
# Copy the powershell profile from the scripts/reusable folder to the user profile
$CreatePowershellProfile = $TRUE

$PowershellProfile = @'
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

oh-my-posh init pwsh --config $env:POSH_THEMES_PATH\catppuccin_mocha.omp.json | Invoke-Expression
Import-Module -Name Terminal-Icons
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
#Can be changed by pressing F2 in the terminal
Set-PSReadLineOption -PredictionViewStyle ListView #InlineView
Set-PSReadLineOption -EditMode Windows





#
# Ctrl+Shift+j then type a key to mark the current directory.
# Ctrj+j then the same key will change back to that directory without
# needing to type cd and won't change the command line.

#
$global:PSReadLineMarks = @{}

Set-PSReadLineKeyHandler -Key Ctrl+J `
    -BriefDescription MarkDirectory `
    -LongDescription "Mark the current directory" `
    -ScriptBlock {
    param($key, $arg)

    $key = [Console]::ReadKey($true)
    $global:PSReadLineMarks[$key.KeyChar] = $pwd
}

Set-PSReadLineKeyHandler -Key Ctrl+j `
    -BriefDescription JumpDirectory `
    -LongDescription "Goto the marked directory" `
    -ScriptBlock {
    param($key, $arg)

    $key = [Console]::ReadKey()
    $dir = $global:PSReadLineMarks[$key.KeyChar]
    if ($dir) {
        cd $dir
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
}

Set-PSReadLineKeyHandler -Key Alt+j `
    -BriefDescription ShowDirectoryMarks `
    -LongDescription "Show the currently marked directories" `
    -ScriptBlock {
    param($key, $arg)

    $global:PSReadLineMarks.GetEnumerator() | % {
        [PSCustomObject]@{Key = $_.Key; Dir = $_.Value } } |
    Format-Table -AutoSize | Out-Host

    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}



# This key handler shows the entire or filtered history using Out-GridView. The
# typed text is used as the substring pattern for filtering. A selected command
# is inserted to the command line without invoking. Multiple command selection
# is supported, e.g. selected by Ctrl + Click.
# As another example, the module 'F7History' does something similar but uses the
# console GUI instead of Out-GridView. Details about this module can be found at
# PowerShell Gallery: https://www.powershellgallery.com/packages/F7History.
Set-PSReadLineKeyHandler -Key F7 `
    -BriefDescription History `
    -LongDescription 'Show command history' `
    -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    if ($pattern) {
        $pattern = [regex]::Escape($pattern)
    }

    $history = [System.Collections.ArrayList]@(
        $last = ''
        $lines = ''
        foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath)) {
            if ($line.EndsWith('`')) {
                $line = $line.Substring(0, $line.Length - 1)
                $lines = if ($lines) {
                    "$lines`n$line"
                }
                else {
                    $line
                }
                continue
            }

            if ($lines) {
                $line = "$lines`n$line"
                $lines = ''
            }

            if (($line -cne $last) -and (!$pattern -or ($line -match $pattern))) {
                $last = $line
                $line
            }
        }
    )
    $history.Reverse()

    $command = $history | Out-GridView -Title History -PassThru
    if ($command) {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
    }
}

#region Smart Insert/Delete

# The next four key handlers are designed to make entering matched quotes
# parens, and braces a nicer experience.  I'd like to include functions
# in the module that do this, but this implementation still isn't as smart
# as ReSharper, so I'm just providing it as a sample.

Set-PSReadLineKeyHandler -Key '"', "'" `
    -BriefDescription SmartInsertQuote `
    -LongDescription "Insert paired quotes if not already on a quote" `
    -ScriptBlock {
    param($key, $arg)

    $quote = $key.KeyChar

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # If text is selected, just quote it without any smarts
    if ($selectionStart -ne -1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }

    $ast = $null
    $tokens = $null
    $parseErrors = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)

    function FindToken {
        param($tokens, $cursor)

        foreach ($token in $tokens) {
            if ($cursor -lt $token.Extent.StartOffset) { continue }
            if ($cursor -lt $token.Extent.EndOffset) {
                $result = $token
                $token = $token -as [StringExpandableToken]
                if ($token) {
                    $nested = FindToken $token.NestedTokens $cursor
                    if ($nested) { $result = $nested }
                }

                return $result
            }
        }
        return $null
    }

    $token = FindToken $tokens $cursor

    # If we're on or inside a **quoted** string token (so not generic), we need to be smarter
    if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic) {
        # If we're at the start of the string, assume we're inserting a new string
        if ($token.Extent.StartOffset -eq $cursor) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            return
        }

        # If we're at the end of the string, move over the closing quote if present.
        if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote) {
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            return
        }
    }

    if ($null -eq $token -or
        $token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket) {
        if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1) {
            # Odd number of quotes before the cursor, insert a single quote
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
        }
        else {
            # Insert matching quotes, move cursor to be in between the quotes
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
        return
    }

    # If cursor is at the start of a token, enclose it in quotes.
    if ($token.Extent.StartOffset -eq $cursor) {
        if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or 
            $token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword)) {
            $end = $token.Extent.EndOffset
            $len = $end - $cursor
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
            return
        }
    }

    # We failed to be smart, so just insert a single quote
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
}

Set-PSReadLineKeyHandler -Key '(', '{', '[' `
    -BriefDescription InsertPairedBraces `
    -LongDescription "Insert matching braces" `
    -ScriptBlock {
    param($key, $arg)

    $closeChar = switch ($key.KeyChar) {
        <#case#> '(' { [char]')'; break }
        <#case#> '{' { [char]'}'; break }
        <#case#> '[' { [char]']'; break }
    }

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    
    if ($selectionStart -ne -1) {
        # Text is selected, wrap it in brackets
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    }
    else {
        # No text is selected, insert a pair
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
}

Set-PSReadLineKeyHandler -Key ')', ']', '}' `
    -BriefDescription SmartCloseBraces `
    -LongDescription "Insert closing brace or skip" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line[$cursor] -eq $key.KeyChar) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
    }
}

Set-PSReadLineKeyHandler -Key Backspace `
    -BriefDescription SmartBackspace `
    -LongDescription "Delete previous character or matching quotes/parens/braces" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -gt 0) {
        $toMatch = $null
        if ($cursor -lt $line.Length) {
            switch ($line[$cursor]) {
                <#case#> '"' { $toMatch = '"'; break }
                <#case#> "'" { $toMatch = "'"; break }
                <#case#> ')' { $toMatch = '('; break }
                <#case#> ']' { $toMatch = '['; break }
                <#case#> '}' { $toMatch = '{'; break }
            }
        }

        if ($toMatch -ne $null -and $line[$cursor - 1] -eq $toMatch) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
        }
    }
}

#endregion Smart Insert/Delete


# Each time you press Alt+', this key handler will change the token
# under or before the cursor.  It will cycle through single quotes, double quotes, or
# no quotes each time it is invoked.
Set-PSReadLineKeyHandler -Key "Alt+'" `
    -BriefDescription ToggleQuoteArgument `
    -LongDescription "Toggle quotes on the argument under the cursor" `
    -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $tokenToChange = $null
    foreach ($token in $tokens) {
        $extent = $token.Extent
        if ($extent.StartOffset -le $cursor -and $extent.EndOffset -ge $cursor) {
            $tokenToChange = $token

            # If the cursor is at the end (it's really 1 past the end) of the previous token,
            # we only want to change the previous token if there is no token under the cursor
            if ($extent.EndOffset -eq $cursor -and $foreach.MoveNext()) {
                $nextToken = $foreach.Current
                if ($nextToken.Extent.StartOffset -eq $cursor) {
                    $tokenToChange = $nextToken
                }
            }
            break
        }
    }

    if ($tokenToChange -ne $null) {
        $extent = $tokenToChange.Extent
        $tokenText = $extent.Text
        if ($tokenText[0] -eq '"' -and $tokenText[-1] -eq '"') {
            # Switch to no quotes
            $replacement = $tokenText.Substring(1, $tokenText.Length - 2)
        }
        elseif ($tokenText[0] -eq "'" -and $tokenText[-1] -eq "'") {
            # Switch to double quotes
            $replacement = '"' + $tokenText.Substring(1, $tokenText.Length - 2) + '"'
        }
        else {
            # Add single quotes
            $replacement = "'" + $tokenText + "'"
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
            $extent.StartOffset,
            $tokenText.Length,
            $replacement)
    }
}
'@

$TerminalProfile = @'
{
    "$help": "https://aka.ms/terminal-documentation",
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "actions": 
    [
        {
            "command": 
            {
                "action": "copy",
                "singleLine": false
            },
            "keys": "ctrl+c"
        },
        {
            "command": "paste",
            "keys": "ctrl+v"
        },
        {
            "command": "find",
            "keys": "ctrl+f"
        },
        {
            "command": 
            {
                "action": "splitPane",
                "split": "auto",
                "splitMode": "duplicate"
            },
            "keys": "alt+shift+d"
        }
    ],
    "copyFormatting": "none",
    "copyOnSelect": false,
    "defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
    "newTabMenu": 
    [
        {
            "type": "remainingProfiles"
        }
    ],
    "profiles": 
    {
        "defaults": 
        {
            "elevate": true,
            "font": 
            {
                "face": "FiraCode Nerd Font"
            },
            "useAtlasEngine": true
        },
        "list": 
        [
            {
                "elevate": true,
                "guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
                "hidden": false,
                "name": "PowerShell",
                "opacity": 60,
                "source": "Windows.Terminal.PowershellCore",
                "useAcrylic": true
            },
            {
                "adjustIndistinguishableColors": "always",
                "colorScheme": "Campbell",
                "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                "elevate": true,
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "hidden": true,
                "name": "Windows PowerShell",
                "opacity": 60,
                "useAcrylic": true
            },
            {
                "commandline": "%SystemRoot%\\System32\\cmd.exe",
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "hidden": false,
                "name": "Command Prompt"
            },
            {
                "guid": "{17bf3de4-5353-5709-bcf9-835bd952a95e}",
                "hidden": false,
                "name": "Ubuntu-22.04",
                "source": "Windows.Terminal.Wsl"
            }
        ]
    },
    "schemes": 
    [
        {
            "background": "#0C0C0C",
            "black": "#0C0C0C",
            "blue": "#0037DA",
            "brightBlack": "#767676",
            "brightBlue": "#3B78FF",
            "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C",
            "brightPurple": "#B4009E",
            "brightRed": "#E74856",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#F9F1A5",
            "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD",
            "foreground": "#CCCCCC",
            "green": "#13A10E",
            "name": "Campbell",
            "purple": "#881798",
            "red": "#C50F1F",
            "selectionBackground": "#FFFFFF",
            "white": "#CCCCCC",
            "yellow": "#C19C00"
        },
        {
            "background": "#012456",
            "black": "#0C0C0C",
            "blue": "#0037DA",
            "brightBlack": "#767676",
            "brightBlue": "#3B78FF",
            "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C",
            "brightPurple": "#B4009E",
            "brightRed": "#E74856",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#F9F1A5",
            "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD",
            "foreground": "#CCCCCC",
            "green": "#13A10E",
            "name": "Campbell Powershell",
            "purple": "#881798",
            "red": "#C50F1F",
            "selectionBackground": "#FFFFFF",
            "white": "#CCCCCC",
            "yellow": "#C19C00"
        },
        {
            "background": "#000000",
            "black": "#0C0C0C",
            "blue": "#0037DA",
            "brightBlack": "#767676",
            "brightBlue": "#3B78FF",
            "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C",
            "brightPurple": "#B4009E",
            "brightRed": "#E74856",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#F9F1A5",
            "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD",
            "foreground": "#FFFFFF",
            "green": "#13A10E",
            "name": "Color Scheme 11",
            "purple": "#881798",
            "red": "#C50F1F",
            "selectionBackground": "#FFFFFF",
            "white": "#CCCCCC",
            "yellow": "#C19C00"
        },
        {
            "background": "#282C34",
            "black": "#282C34",
            "blue": "#61AFEF",
            "brightBlack": "#5A6374",
            "brightBlue": "#61AFEF",
            "brightCyan": "#56B6C2",
            "brightGreen": "#98C379",
            "brightPurple": "#C678DD",
            "brightRed": "#E06C75",
            "brightWhite": "#DCDFE4",
            "brightYellow": "#E5C07B",
            "cursorColor": "#FFFFFF",
            "cyan": "#56B6C2",
            "foreground": "#DCDFE4",
            "green": "#98C379",
            "name": "One Half Dark",
            "purple": "#C678DD",
            "red": "#E06C75",
            "selectionBackground": "#FFFFFF",
            "white": "#DCDFE4",
            "yellow": "#E5C07B"
        },
        {
            "background": "#FAFAFA",
            "black": "#383A42",
            "blue": "#0184BC",
            "brightBlack": "#4F525D",
            "brightBlue": "#61AFEF",
            "brightCyan": "#56B5C1",
            "brightGreen": "#98C379",
            "brightPurple": "#C577DD",
            "brightRed": "#DF6C75",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#E4C07A",
            "cursorColor": "#4F525D",
            "cyan": "#0997B3",
            "foreground": "#383A42",
            "green": "#50A14F",
            "name": "One Half Light",
            "purple": "#A626A4",
            "red": "#E45649",
            "selectionBackground": "#4F525D",
            "white": "#FAFAFA",
            "yellow": "#C18301"
        },
        {
            "background": "#002B36",
            "black": "#002B36",
            "blue": "#268BD2",
            "brightBlack": "#073642",
            "brightBlue": "#839496",
            "brightCyan": "#93A1A1",
            "brightGreen": "#586E75",
            "brightPurple": "#6C71C4",
            "brightRed": "#CB4B16",
            "brightWhite": "#FDF6E3",
            "brightYellow": "#657B83",
            "cursorColor": "#FFFFFF",
            "cyan": "#2AA198",
            "foreground": "#839496",
            "green": "#859900",
            "name": "Solarized Dark",
            "purple": "#D33682",
            "red": "#DC322F",
            "selectionBackground": "#FFFFFF",
            "white": "#EEE8D5",
            "yellow": "#B58900"
        },
        {
            "background": "#FDF6E3",
            "black": "#002B36",
            "blue": "#268BD2",
            "brightBlack": "#073642",
            "brightBlue": "#839496",
            "brightCyan": "#93A1A1",
            "brightGreen": "#586E75",
            "brightPurple": "#6C71C4",
            "brightRed": "#CB4B16",
            "brightWhite": "#FDF6E3",
            "brightYellow": "#657B83",
            "cursorColor": "#002B36",
            "cyan": "#2AA198",
            "foreground": "#657B83",
            "green": "#859900",
            "name": "Solarized Light",
            "purple": "#D33682",
            "red": "#DC322F",
            "selectionBackground": "#073642",
            "white": "#EEE8D5",
            "yellow": "#B58900"
        },
        {
            "background": "#000000",
            "black": "#000000",
            "blue": "#3465A4",
            "brightBlack": "#555753",
            "brightBlue": "#729FCF",
            "brightCyan": "#34E2E2",
            "brightGreen": "#8AE234",
            "brightPurple": "#AD7FA8",
            "brightRed": "#EF2929",
            "brightWhite": "#EEEEEC",
            "brightYellow": "#FCE94F",
            "cursorColor": "#FFFFFF",
            "cyan": "#06989A",
            "foreground": "#D3D7CF",
            "green": "#4E9A06",
            "name": "Tango Dark",
            "purple": "#75507B",
            "red": "#CC0000",
            "selectionBackground": "#FFFFFF",
            "white": "#D3D7CF",
            "yellow": "#C4A000"
        },
        {
            "background": "#FFFFFF",
            "black": "#000000",
            "blue": "#3465A4",
            "brightBlack": "#555753",
            "brightBlue": "#729FCF",
            "brightCyan": "#34E2E2",
            "brightGreen": "#8AE234",
            "brightPurple": "#AD7FA8",
            "brightRed": "#EF2929",
            "brightWhite": "#EEEEEC",
            "brightYellow": "#FCE94F",
            "cursorColor": "#000000",
            "cyan": "#06989A",
            "foreground": "#555753",
            "green": "#4E9A06",
            "name": "Tango Light",
            "purple": "#75507B",
            "red": "#CC0000",
            "selectionBackground": "#555753",
            "white": "#D3D7CF",
            "yellow": "#C4A000"
        },
        {
            "background": "#300A24",
            "black": "#171421",
            "blue": "#0037DA",
            "brightBlack": "#767676",
            "brightBlue": "#08458F",
            "brightCyan": "#2C9FB3",
            "brightGreen": "#26A269",
            "brightPurple": "#A347BA",
            "brightRed": "#C01C28",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#A2734C",
            "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD",
            "foreground": "#FFFFFF",
            "green": "#26A269",
            "name": "Ubuntu-22.04-ColorScheme",
            "purple": "#881798",
            "red": "#C21A23",
            "selectionBackground": "#FFFFFF",
            "white": "#CCCCCC",
            "yellow": "#A2734C"
        },
        {
            "background": "#000000",
            "black": "#000000",
            "blue": "#000080",
            "brightBlack": "#808080",
            "brightBlue": "#0000FF",
            "brightCyan": "#00FFFF",
            "brightGreen": "#00FF00",
            "brightPurple": "#FF00FF",
            "brightRed": "#FF0000",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#FFFF00",
            "cursorColor": "#FFFFFF",
            "cyan": "#008080",
            "foreground": "#C0C0C0",
            "green": "#008000",
            "name": "Vintage",
            "purple": "#800080",
            "red": "#800000",
            "selectionBackground": "#FFFFFF",
            "white": "#C0C0C0",
            "yellow": "#808000"
        }
    ],
    "theme": "system",
    "themes": [],
    "useAcrylicInTabRow": true
}
'@

#Don't change, is to ensure that the fonts can be installed, they are dependant on one module.
$ModulesInstalled = $false


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
        [string[]]$Packages
    )
    # Don't try to download and install a package if it shows already installed
    $InstalledChocoPackages = (Get-ChocoPackages).Name
    $Packages = $Packages | Where-Object { $InstalledChocoPackages -notcontains $_ }

    if ($ChocoInstalls.Count -gt 0) {
        # Install $ChocoInstalls packages with Chocolatey
        try {
            choco upgrade $Packages -y
        }
        catch {
            Write-Warning "Unable to install software package with Chocolatey: $($_)"
        }
    }
    else {
        Write-Host -ForegroundColor:Green 'There were no packages to install!'
    }
}

# function to install fonts
function Install-Fonts {
    if($ModulesInstalled -eq $false) {
        Install-PowerShellModules
        $ModulesInstalled = $true
    }
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

    $installedFonts = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts').PsObject.Properties.Value

    # Install all TTF files
    $ttfFiles = Get-ChildItem -Path $downloadDirectory -Filter "*.ttf"
    foreach ($ttfFile in $ttfFiles) {
        if($installedFonts -contains $ttfFile.Name) {
            Write-Host "Skipping $($ttfFile.Name) because it is already installed." -ForegroundColor Yellow
            continue
        }
        Write-Host "Installing $($ttfFile.Name)..."
        Add-Font -Path $ttfFile.FullName | Out-Null
    }



    Write-Host "Font installation complete." -ForegroundColor Yellow
}

function Update-Terminal {
    if ($TerminalProfile) {
        $TerminalProfile | Out-File -FilePath $env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json -Force
        Write-Host "Windows Terminal settings JSON file replaced. Restart Windows Terminal to see the changes."-ForegroundColor Yellow

    }
}

function Install-PowerShellModules {
    if($ModulesInstalled -eq $true) {
        return
    }
    #Setup Powershell Gallery as a trusted source
    #Trust the psgallery for installs
    Write-Host -ForegroundColor 'Yellow' 'Setting PSGallery as a trusted installation source...'
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted


    # Install/Update PowershellGet and PackageManager if needed
    try {
        Import-Module PowerShellGet
    }
    catch {
        throw 'Unable to load PowerShellGet!'
    }

    # Need to set Nuget as a provider before installing modules via PowerShellGet
    $null = Install-PackageProvider NuGet -Force

    # Store a few things for later use
    # $SpecialPaths = Get-SpecialPaths
    $packages = Get-Package

    if (@($packages | Where-Object { $_.Name -eq 'PackageManagement' }).Count -eq 0) {
        Write-Host -ForegroundColor cyan "PackageManager is installed but not being maintained via the PowerShell gallery (so it will never get updated). Forcing the install of this module through the gallery to rectify this now."
        Install-Module PackageManagement -Force
        Install-Module PowerShellGet -Force

        Write-Host -ForegroundColor:Red "PowerShellGet and PackageManagement have been installed from the gallery. You need to close and rerun this script for them to work properly!"
    
        Invoke-Reboot
    }
    else {
        $InstalledModules = (Get-InstalledModule).name
        $ModulesToBeInstalled = $ModulesToBeInstalled | Where-Object { $InstalledModules -notcontains $_ }
        if ($ModulesToBeInstalled.Count -gt 0) {
            Write-Host -ForegroundColor:cyan "Installing modules that are not already installed via powershellget. Modules to be installed = $($ModulesToBeInstalled.Count)"
            Install-Module -Name $ModulesToBeInstalled -AllowClobber -AcceptLicense -ErrorAction:SilentlyContinue
        }
        else {
            Write-Output "No modules were found that needed to be installed."
        }
        $ModulesInstalled = $true

    }
}

function Clear-DesktopShortcuts{
    # Clear the desktop of shortcuts, move them to a new folder on the desktop
    if ($ClearDesktopShortcuts) {
        $Desktop = $SpecialPaths['DesktopDirectory']
        $DesktopShortcuts = Join-Path $Desktop 'Shortcuts'
        if (-not (Test-Path $DesktopShortcuts)) {
            Write-Host -ForegroundColor:Cyan "Creating a new shortcuts folder on your desktop and moving all .lnk files to it: $DesktopShortcuts"
            $null = mkdir $DesktopShortcuts
        }

        Write-Output "Moving .lnk files from $($SpecialPaths['CommonDesktopDirectory']) to the Shortcuts folder"
        Get-ChildItem -Path  $SpecialPaths['CommonDesktopDirectory'] -Filter '*.lnk' | ForEach-Object {
            Move-Item -Path $_.FullName -Destination $DesktopShortcuts -ErrorAction:SilentlyContinue
        }

        Write-Output "Moving .lnk files from $Desktop to the Shortcuts folder"
        Get-ChildItem -Path $Desktop -Filter '*.lnk' | ForEach-Object {
            Move-Item -Path $_.FullName -Destination $DesktopShortcuts -ErrorAction:SilentlyContinue
        }
    }
}

function Update-PowershellProfile{
    Write-Host "Updating Powershell Profile..."
    # Copy over the powershell profile if it doesn't exist
    if ($CreatePowershellProfile -and (-not (Test-Path $PROFILE))) {
        Write-Host -ForegroundColor:Green -Info 'Creating user powershell profile...'
        # Copy local profile to user profile
        Copy-Item -Path .\files\powershell_profile.ps1 -Destination $PROFILE -Force

        . $PROFILE # Reload the profile
    }
    else {
        Write-Host -ForegroundColor:Green "Powershell profile already exists, skipping..."
    }

}

$Bloatware = @(
    #Microsoft
    'Clipchamp.Clipchamp',
    'Microsoft.BingFinance',
    'Microsoft.BingFoodAndDrink ',
    'Microsoft.BingHealthAndFitness',
    'Microsoft.BingNews',
    'Microsoft.BingSports',
    'Microsoft.BingTranslator',
    'Microsoft.BingTravel',
    'Microsoft.BingWeather',
    'Microsoft.Messaging',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftPowerBIForWindows',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MixedReality.Portal',
    'Microsoft.NetworkSpeedTest',
    'Microsoft.News',
    'Microsoft.Office.OneNote',
    'Microsoft.Office.Sway',
    'Microsoft.OneConnect',
    'Microsoft.SkypeApp',
    'Microsoft.Todos',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps',
    'Microsoft.WindowsSoundRecorder',
    'Microsoft.ZuneVideo',
    'MicrosoftCorporationII.MicrosoftFamily ',
    'MicrosoftTeams',
    #3rd Party
    'ACGMediaPlayer',
    'ActiproSoftwareLLC',
    'AdobeSystemsIncorporated.AdobePhotoshopExpress',
    'Amazon.com.Amazon',
    'AmazonVideo.PrimeVideo',
    'Asphalt8Airborne',
    'AutodeskSketchBook',
    'CaesarsSlotsFreeCasino',
    'COOKINGFEVER',
    'CyberLinkMediaSuiteEssentials',
    'DisneyMagicKingdoms',
    'Disney',
    'Dolby',
    'DrawboardPDF',
    'Duolingo-LearnLanguagesforFree',
    'EclipseManager',
    'Facebook',
    'FarmVille2CountryEscape',
    'fitbit',
    'Flipboard',
    'HiddenCity',
    'HULULLC.HULUPLUS',
    'iHeartRadio',
    'Instagram',
    'king.com.BubbleWitch3Saga',
    'king.com.CandyCrushSaga',
    'king.com.CandyCrushSodaSaga',
    'LinkedInforWindows',
    'MarchofEmpires',
    'Netflix',
    'NYTCrossword',
    'OneCalendar',
    'PandoraMediaInc',
    'PhototasticCollage',
    'PicsArt-PhotoStudio',
    'Plex',
    'PolarrPhotoEditorAcademicEdition',
    'Royal Revolt',
    'Shazam',
    'Sidia.LiveWallpaper',
    'SlingTV',
    'Speed Test',
    'Spotify',
    'TikTok',
    'TuneInRadio',
    'Twitter',
    'Viber',
    'WinZipUniversal',
    'Wunderlist',
    'XING'

)

function Remove-Bloatware{
    Write-Host "Removing Bloatware..."
    foreach ($app in $Bloatware) {
       Write-Host "attempting to remove $app"
       Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers
    }
}

Install-ChocoPackages -Packages $ChocoInstalls

Install-PowerShellModules

Install-Fonts

Update-Terminal

Clear-DesktopShortcuts

Update-PowershellProfile

Remove-Bloatware

#Winconfig settings, see https://boxstarter.org/winconfig
try {
    Disable-GameBarTips
    Disable-BingSearch
}
catch {
    Write-Error "Unable to disable game bar tips or bing search: $($_)"
}


# Windows config settings
Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowProtectedOSFiles -EnableShowFileExtensions -EnableShowFullPathInTitleBar


Enable-UAC
if (Test-PendingReboot) {
    Invoke-Reboot
}


Write-Host -ForegroundColor:Green "Install and configuration complete!"