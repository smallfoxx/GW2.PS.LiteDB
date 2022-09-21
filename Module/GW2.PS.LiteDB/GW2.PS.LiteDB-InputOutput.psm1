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

Function ConvertFrom-GW2DBDocument {
<#
.SYNOPSIS
Removes JSON obfuscation of BSON Document properties and builds array into standard PSCustomObject
#>
    param($Document)

    $result = @{}
    ForEach ($Property in $Document) {
        $value = $Property.Value
        $ConversionAttempts = 0
        While (($value -match "^(([""\{])|(\[[^&]))") -and ($ConversionAttempts -lt 5) ) {
            try {
                $ConversionAttempts++
                Write-Debug "attempting [$ConversionAttempts] to convert [ $value ]"
                $Value = $Value | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Write-Debug "Failed to convert [ $value ] after [ $ConversionAttempts ] attempts"
                $ConversionAttempts++
            }
        }
        $result.($Property.key) = $value
    }
    [PSCustomObject]$result

}

Function Add-GW2DBEntry {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]
        [PSCustomObject]$InputObject,
        [parameter(Mandatory)]
        [string]$CollectionName,
        [switch]$PassThru
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
        If ($PassThru) { ConvertFrom-GW2DBDocument -Document $doc }
    }
}

Function Get-GW2DBItemByQuery {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$QueryString,
        [parameter(Mandatory)]
        [string]$CollectionName,
        [switch]$SingleResult
    )

    Begin {
        #Ensure that if they past an endpoint name, we ensure its a proper collection name before we get the collection
        $CollectionName = Get-GW2DBCollectionName -EndPointName $CollectionName
        If (Test-GW2DBCollection -CollectionName $CollectionName) {
            $Collection = Get-GW2DBCollection -CollectionName $CollectionName
        }
        else {
            $Collection = New-GW2DBCollection -CollectionName $CollectionName
        }
    }

    Process {
        If ($SingleResult) {
            $Collection.FindOne($QueryString)
        } else {
            $Collection.Find($QueryString)
        }
    }
}

Function Get-GW2DBEntry {
    [cmdletbinding(DefaultParameterSetName="OnlyID")]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName="OnlyID")]
        [string[]]$Id,
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName="PropertyHashTable",Mandatory)]
        [hashtable]$PropertyValues,
        [parameter(Mandatory)]
        [string]$CollectionName,
        [switch]$SkipOnlineLookup

        ### TODO:  Need to deal with extra ear order on behalf
    )
    Begin {
        If (Test-GW2DBCollection -CollectionName $CollectionName) {
            $Collection = Get-GW2DBCollection -CollectionName $CollectionName
        }
        else {
            $Collection = New-GW2DBCollection -CollectionName $CollectionName
        }
        $MissingIds=@()
    }
    Process {
        switch ($PSCmdlet.ParameterSetName) {
            "OnlyID" {
                Write-Debug "Database query of $CollectionName for IDs = $ID"
                If ($ID -match ","){
                    $Entries = ($id -split ',')
                    $FormatEntries = $Entries | %{ If ($_ -match "^'[^']*'$") { $_ } else { "'$_'" } }
                    $QueryArray = "[ {0} ]" -f ($FormatEntries -join ',')
                    Write-Information "Querying $COllectionName for an array $QueryArray"
                    $Documents = $Collection.Find("`$.Id in $QueryArray")
                    # TODO: Something in here is causing a result of "True" which is getting sent to API as an unknown ID which obviously fails
                    $Results = $Documents | ForEach-Object { ConvertFrom-GW2DBDocument -Document $_ }
                    $MissingIds += $FormatEntries -notin ($Results.Id | ForEach-Object { "'$_'" } )
                    $Results
                } else {
                    $Document = $Collection.FindOne("`$.Id = '$Id'")
                    If ($Document) {
                        ConvertFrom-GW2DBDocument -Document $Document
                    } else {
                        $MissingIds += $Id
                    }
                }
                <#
                ForEach ($EntryId in ($Id -split ',')) {
                    # While FindOne() will retrieve the first matching entry, the content are all esaped
                    #  as JSoN formats.  Therefore, if the value starts with ", {, or [, it still needs to
                    #  be converted from JSON
                }
                #>
            }
            default {
                $QueryElements=[System.Collections.ArrayList]@()
                ForEach ($Property in $PropertyValues.Keys) {
                    $QueryElements.Add(("`$.{0} = '{1}'" -f $Property,$PropertyValues.$Property))
                }
                $FullQuery = $QueryElements -join " and "
                Write-Debug "Attempting to query $CollectionName for $FullQuery"
                $Document = $Collection.FindOne($FullQuery)
                ConvertFrom-GW2DBDocument -Document $Document
            }
        }
    }
    End {
        If ($MissingIds -and (-not $SkipOnlineLookup)) {
            Write-Debug "Couldn't find $($MissingIds.count) IDs in Database; looking up online"
            $APIValue = Get-GW2DBAPIValue -CollectionName $CollectionName
            $MissingEntries = Get-GW2APIValue -APIValue $APIValue -APIParams @{ 'ids' = ($MissingIds -join ',') } -UseCache:$false -UseDB:$false
            $MissingEntries | Add-GW2DBEntry -CollectionName $CollectionName -PassThru
        }
    }
}

Function Get-GW2DBCollectionName {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$EndPointName)

    Process {
        $EndpointName -replace "[\\/]","_"
    }
}

Function Get-GW2DBAPIValue {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$CollectionName)

    Process {
        $CollectionName -replace "_","/"
    }
}

Function Get-GW2DBValue {
    [cmdletbinding()]
    param(
        [string]$APIValue,
        [securestring]$SecureAPIKey,
        [hashtable]$APIParams
    )

    Begin {
        $CollectionName = $APIValue | Get-GW2DBCollectionName
        Connect-GW2LiteDB
    }

    Process {
        If ($APIParams.Ids) {
            Get-GW2DBEntry -CollectionName $CollectionName -Id $APIParams.Ids 
        } elseIf ($APIParams.count -gt 0) {
            Get-GW2DBEntry -CollectionName $CollectionName -PropertyValues $APIParams 
        } else {
            $WebResults = Get-GW2APIValue -APIValue $APIValue -SecureAPIKey $SecureAPIKey -APIParams $APIParams -UseCache:$false -UseDB:$false
            $WebResults
        }
    }

    ENd {
        Disconnect-GW2LiteDB
    }

}
