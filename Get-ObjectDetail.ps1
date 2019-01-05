#by: tomasmu
#date: 2019-01-05

function IsEnumerable {
    [CmdletBinding()]
    param($InputObject)

    $InputObject -is [System.Collections.IEnumerable] -and
    $InputObject -isnot [string]  #treat [string] as a value
}

function IsDictionary {
    [CmdletBinding()]
    param($InputObject)

    $InputObject -is [System.Collections.IDictionary]
}

function IsSimple {
    [CmdletBinding()]
    param($InputObject)

    $null -eq $InputObject -or
    $InputObject.GetType().IsPrimitive -or
    $InputObject -is [string] -or  #treat [string] as a value
    $InputObject -is [enum]        #treat [enum] as a value, like [int]
    
    #$InputObject.GetType().IsValueType #example: [date] is valuetype :(
}

function IsIndexable {
    [CmdletBinding()]
    param($InputObject)

    #$obj and $obj[0] are apparently equal in powershell if $obj is an unindexable datatype

    $null -ne $InputObject -and
    $null -ne $InputObject[0] -and  #breaks if array has $null element in [0] though :(
    $InputObject[0].GetHashCode() -ne $InputObject.GetHashCode()
}

function WriteObject {
    [CmdletBinding()]
    param(
        $InputObject,
        $Name,
        $CustomValue
    )

    $value = if ($null -eq $CustomValue) { $InputObject } else { $CustomValue }
    $type = if ($null -ne $InputObject) { $InputObject.GetType().Name } else { '$null' }

    $output = [PSCustomObject]@{
        Name  = $Name
        Value = $value
        Type  = $type
        #Level = $Level
    }

    $output
}

function ObjDetail {
    [CmdletBinding()]
    param(
        $InputObject,
        [string]$Name,
        [int]$Level,
        [int]$MaxDepth,
        [System.Collections.Generic.HashSet[int]]$HashCodes,
        [string[]]$ExcludeProperty
    )

    $cmdName = $PSCmdlet.MyInvocation.MyCommand
    Write-Verbose "$cmdName, $($PSBoundParameters.GetEnumerator() | % { "$($_.Key)='$($_.Value)'" })"

    if ($Level -gt $MaxDepth) {
        #Write-Error "MaxDepth exceeded: $Level"
        continue
    }

    $obj = $InputObject
    if ($null -eq $obj) {
        Write-Verbose "$cmdName, $Name is null"
        WriteObject -Name $Name -InputObject $obj
    }
    else {
        if (-not (IsSimple -InputObject $obj)) {
            $hashCode = $obj.GetHashCode()
            $isZeroHash = $hashCode -eq 0 #include anyway, maybe?
            #$isPSCustomObjectGetHashCodeBug = $obj -is [System.Management.Automation.PSCustomObject] #include anyway, because of duplicate hashcodes?
            $isUnique = $HashCodes.Add($hashCode) -or $isZeroHash #-or $isPSCustomObjectGetHashCodeBug

            if ($isUnique) {
                #print complex object without value, properties will be shown later (is this a good idea?)
                WriteObject -Name $Name -InputObject $obj -CustomValue "(...)"
            }
            else {
                #print object as duplicate:
                WriteObject -Name $Name -InputObject $obj -CustomValue "(Duplicate)"
                #Write-Error "Duplicate hashcode detected: $Name = $hashCode"
                continue
            }
        }
        else {
            WriteObject -Name $Name -InputObject $obj
        }

        $ObjDetailParam = @{
             Level           = $Level + 1
             MaxDepth        = $MaxDepth
             HashCodes       = $HashCodes
             ExcludeProperty = $ExcludeProperty
        }

        if (IsDictionary -InputObject $obj) {
            #print with key: $obj['key']
            Write-Verbose "$cmdName, IsDictionary"
            foreach ($keyValue in $obj.GetEnumerator()) {
                $key = $keyValue.Key
                $value = $keyValue.Value
                ObjDetail -InputObject $value -Name "$Name['$key']" @ObjDetailParam
            }
        }
        elseif (IsEnumerable -InputObject $obj) {
            if (IsIndexable -InputObject $obj) {
                #print with integer index: $obj[index]
                Write-Verbose "$cmdName, IsEnumerable IsIndexable"
                for ($index = 0; $index -lt $obj.Count; $index++) {
                    $value = $obj[$index]
                    ObjDetail -InputObject $value -Name "$Name[$index]" @ObjDetailParam
                }
            }
            else {
                #print non-indexable collection (numbered): $obj (#n)
                #$obj (#n) = ($obj | select -Index n)
                Write-Verbose "$cmdName, IsEnumerable Not Indexable"
                $count = -1
                foreach ($value in $obj) {
                    $count++
                    ObjDetail -InputObject $value -Name "$Name ($count)" @ObjDetailParam
                }
            }
        }

        #always print properties: $obj.prop
        foreach ($prop in $obj.psobject.Properties) {
            $property = $prop.Name
            $value = $prop.Value
            if ($property -notin $ExcludeProperty) {
                ObjDetail -InputObject $value -Name "$Name.$property" @ObjDetailParam
            }
            #else {
            #    #Write-Verbose "$cmdName, $Name is an ExcludedProperty"
            #    #WriteObject -Name "$Name.$property" -InputObject $value -CustomValue "(ExcludedProperty)"
            #}
        }
    }
}

function Get-ObjectDetail {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline = $true)]$InputObject,
        [string]$Name = '$x',
        [int]$MaxDepth = 10,
        [string[]]$ExcludeProperty
    )

    begin {
        $ObjDetailParam = @{
            Name            = $Name
            Level           = 0
            MaxDepth        = $MaxDepth
            HashCodes       = [System.Collections.Generic.HashSet[int]]::new()
            ExcludeProperty = $ExcludeProperty
        }
    }
    process {
        ObjDetail -InputObject $InputObject @ObjDetailParam
    }
    end {}
}

New-Alias -Name god -Value Get-ObjectDetail -ErrorAction SilentlyContinue

#only export functions with dashes
#Export-ModuleMember '*-*'
