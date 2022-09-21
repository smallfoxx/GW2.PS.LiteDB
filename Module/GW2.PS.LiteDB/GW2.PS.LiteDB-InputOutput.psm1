Function New-GW2DBCollection {
    param(
        [parameter(Mandatory)]
        [string]$CollectionName,
        [string]$DefaultIndex = 'Id'
    )

    $Collection = Get-GW2DBCollection -CollectionName $CollectionName
    $Collection.EnsureIndex($DefaultIndex)
    Write-Output $Collection 
}

Function Get-GW2DBCollection {
    param(
        [parameter(Mandatory)]
        [string]$CollectionName
    )

    $DB = Get-GW2LiteDB
    $DB.GetCollection($CollectionName)

}

Function Test-GW2DBCollection {
    param(
        [parameter(Mandatory)]
        [string]$CollectionName
    )

    $DB = Get-GW2LiteDB
    Write-Output ([bool]($DB.CollectionExists($CollectionName)))

}

Function Get-GW2DBMapper {

    [LiteDB.BSONMapper]::New()

}

Function ConvertTo-GW2DBDocument {
    [OutputType('LiteDB.BsonDocument')]
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]
        $InputObject
    )

    Begin {
        $BSONMapper = [LiteDB.BSONMapper]::New()
    }
    Process {
        If ($InputObject) {
            [LiteDB.BsonDocument]$result = ($BSONMapper.ToDocument($InputObject))
            return $result
        }
    }
}

Function Add-GW2DBItem {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]
        [PSCustomObject]$InputObject,
        [parameter(Mandatory)]
        [string]$CollectionName,
        [int]$Count = 4
    )
    Begin {
        If (Test-GW2DBCollection -CollectionName $CollectionName) {
            $Collection = Get-GW2DBCollection -CollectionName $CollectionName
        }
        else {
            $Collection = New-GW2DBCollection -CollectionName $CollectionName
        }
        $BSONMapper = Get-GW2DBMapper
    }
    Process {
        #$doc = [LiteDB.BsonDocument]::New()
        $doc = $BSONMapper.ToDocument(@{'id' = $InputObject.Id })
        ForEach ($prop in ($InputObject | Get-Member -MemberType NoteProperty )) { #| select -first $count)) {
            If (-not ([string]::IsNullOrEmpty( $InputObject.($prop.Name)))) { #.length -gt 0) {
                Write-Debug "$($Collection.name): $($prop.name) => '$($InputObject.($prop.Name))' [$($InputObject.($prop.Name).length)]"
                $doc[$prop.name] = $InputObject.($prop.Name) | ConvertTo-Json -Depth 10
            }
        }
        Write-Debug "$($Collection.name): $($doc['id']) => $($doc['name'])"
        $null = $Collection.Insert($doc) #($BSONMapper.ToDocument($InputObject)))
    }
}

Function Get-GW2DBItem {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$Id,
        [parameter(Mandatory)]
        [string]$CollectionName

        ### TODO:  Need to deal with extra ear order on behalf
    )
    Begin {
        If (Test-GW2DBCollection -CollectionName $CollectionName) {
            $Collection = Get-GW2DBCollection -CollectionName $CollectionName
        }
        else {
            $Collection = New-GW2DBCollection -CollectionName $CollectionName
        }
    }
    Process {
        ForEach ($ItemId in ($Id -split ',')) {
            $result = @{}
            # While FindOne() will retrieve the first matching entry, the content are all esaped
            #  as JSoN formats.  Therefore, if the value starts with ", {, or [, it still needs to
            #  be converted from JSON
            ForEach ($prop in ($Collection.FindOne("`$.Id = '$ItemId'"))) {
                $value = $prop.Value
                While ($value -match "^(([""\{])|(\[[^&]))" ) {
                    $Value = $Value | ConvertFrom-Json
                }
                $result.($Prop.key) = $value
            }
            [PSCustomObject]$result
        }
    }
}

Function Get-GW2DBValue {
    [cmdletbinding()]
    param(
        [string]$APIValue,
        [securestring]$SecureAPIKey,
        [hashtable]$APIParams
    )

    Process {
        If ($APIParams.count -gt 0) {
            $CollectionName = $APIValue -replace "[\\/]","_"
            Get-GW2DBItem -CollectionName $CollectionName -APIParams $APIParams 
        } else {
            Get-GW2APIValue -APIValue $APIValue -SecureAPIKey $SecureAPIKey -APIParams $APIParams -UseCache:$false
        }
    }

}
