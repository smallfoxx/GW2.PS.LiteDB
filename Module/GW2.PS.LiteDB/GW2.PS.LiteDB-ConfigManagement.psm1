Function Get-GW2LiteDBPath {
    If ($IsWindows) {
        "$env:LOCALAPPDATA\GW2.PS\LiteDB"
    } elseif ($IsMacOS) {
        "~/Library/Application Support/GW2.PS/LiteDB"
    } else {
        "$PSScriptRoot/Data/GW2.PS/LiteDB"
    }
}
Function New-GW2LiteDBSettings {

    @{
        "Path" = (Get-GW2LiteDBPath)
        "DBName" = "GW2.PS"
        "MinTouch" = 1440
        "MaxAge" = 2628000
        "UseDB" = $true
    }

}

Function Set-GW2LiteDBPath {
    param([string]$Path=(Get-GW2LiteDBPath))

    If (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        $Dir = New-Item -Path $Path -ItemType Directory -ErrorAction SilentlyContinue
    }
    $Dir = Get-Item -Path $Path -ErrorAction SilentlyContinue
    If ($Dir) {
        Set-GW2ConfigValue -Section LiteDB -Name 'Path' -Value $Dir.FullName
    }
}

Function Set-GW2UseDB {
    param([switch]$Disable)

    Set-GW2ConfigValue -Section LiteDB -Name 'UseDB' -Value (-not $Disable)
}

