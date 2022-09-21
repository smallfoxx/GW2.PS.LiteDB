Function New-GW2LiteDBSettings {

    @{
        "Path" = "$env:LOCALAPPDATA\GW2.PS\LiteDB"
        "DBName" = "GW2.PS"
        "MinTouch" = 1440
        "MaxAge" = 2628000
        "UseDB" = $true
    }

}

Function Set-GW2LiteDBPath {
    param([string]$Path="$env:LOCALAPPDATA\GW2.PS\LiteDB")

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

