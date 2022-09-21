Function Install-GW2LiteDB {
param([version]$MinimumVersion='5.0.12',
    [string]$Source='NuGet')

    $PackageName = 'LiteDB'
    If (-not (Get-Package -Name $PackageName)) {
        If (-Not (Get-PackageSource -ProviderName $Source)) {
            Write-Debug "Registering NuGet as package source"
            Register-PackageSource -Name NuGet -Location https://www.nuget.org/api/v2 -ProviderName NuGet
        }

        try {
            Write-Debug "Installing $PackageName"
            Install-Package -name $PackageName -MinimumVersion $MinimumVersion -Source 'NuGet' -Force -ErrorAction Stop
        } catch {
            Write-Warning "Installation FAILED!  Attempting to install 'LiteDB' in elevated admin mode."
            $PSExe = Get-ChildItem $PSHome\p*.exe | Select-Object -First 1 -ExpandProperty FullName
            Start-Process -Verb RunAs -FilePath $PSExe -ArgumentList @("-Command", 
                { Install-Package 'LiteDB' -SkipDependencies -MinimumVersion 5.0.12 -Source 'NuGet' -Force; pause }) -Wait 
            If (Get-Package $PackageName) { Write-Host "SUCCESS: $PackageName installed successful as admin" -ForegroundColor Green }
        }
    }

    Import-GW2LiteDBDriver
}

Function Import-GW2LiteDBDriver {
    param()

    # Test if we have already loaded the assembly by looking for the PSType of LiteDB.LiteDatabase
    If ( -Not ([System.Management.Automation.PSTypeName]'LiteDB.LiteDatabase').Type ) {
        $Package = Get-Package -Name $PackageName
        $PackageDllPaths = (Get-ChildItem -Filter '*.dll' -Recurse (Split-Path $Package.Source)).FullName
        $standardAssemblyFullPath = $PackageDllPaths | Where-Object {$_ -Like "*standard*"} | Select-Object -Last 1
    
        Add-Type -Path $standardAssemblyFullPath -ErrorAction 'SilentlyContinue'
    }

}

Function Connect-GW2LiteDB {
    param(
        [string]$DBName = (Get-GW2ConfigValue -Section 'LiteDB' -Name 'DBName'),
        [string]$DBPath = (Get-GW2ConfigValue -Section 'LiteDB' -Name 'Path')
    )

    If (-not (Get-Package 'LiteDB' -ErrorAction SilentlyContinue)) {
        Write-Warning "Database driver not installed! Call Install-GW2LiteDB before connecting to DB."
    } else {
        Import-GW2LiteDBDriver
        $script:GW2PSDatabase = [LiteDB.LiteDatabase]::New("$DBPath\$DBName.db")
    }

}

Function Disconnect-GW2LiteDB {
    param()

    $script:GW2PSDatabase.dispose()
}

Function Get-GW2LiteDB {
    param()

    Write-Output $script:GW2PSDatabase

}

Set-Alias -Name Install-GW2DB -Value Install-GW2LiteDB
