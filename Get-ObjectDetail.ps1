#by: tomasmu
#date: 2019-01-05

#some helper functions..
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

#the function that does it all
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
        #Write-Verbose "$cmdName, MaxDepth $MaxDepth exceeded: $Name"
        #WriteObject -Name $Name -InputObject $obj -CustomValue '(MaxDepth)'
        continue
    }

    $obj = $InputObject
    if ($null -eq $obj) {
        Write-Verbose "$cmdName, null: $Name"
        WriteObject -Name $Name -InputObject $obj
    }
    else {
        if (-not (IsSimple -InputObject $obj)) {
            $hashCode = $obj.GetHashCode()
            $isZeroHash = $hashCode -eq 0 #include anyway, probably an "error" (e.g. empty guid, [timespan]0, etc)
            #$isPSCustomObjectGetHashCodeBug = $obj -is [System.Management.Automation.PSCustomObject] #include anyway, because of duplicate hashcodes?
            $isUnique = $HashCodes.Add($hashCode) -or $isZeroHash #-or $isPSCustomObjectGetHashCodeBug
            if ($isUnique) {
                #print complex object without value, properties will be shown later
                WriteObject -Name $Name -InputObject $obj -CustomValue '(...)'
            }
            else {
                #Write-Verbose "Duplicate hashcode detected: $Name = $hashCode"
                WriteObject -Name $Name -InputObject $obj -CustomValue '(Duplicate)'
                continue
            }
        }
        else {
            WriteObject -Name $Name -InputObject $obj
        }

        $objDetailParam = @{
             Level           = $Level + 1
             MaxDepth        = $MaxDepth
             HashCodes       = $HashCodes
             ExcludeProperty = $ExcludeProperty
        }

        if (IsDictionary -InputObject $obj) {
            Write-Verbose "$cmdName, IsDictionary: $Name"
            foreach ($keyValue in $obj.GetEnumerator()) {
                $key = $keyValue.Key
                $value = $keyValue.Value
                ObjDetail -InputObject $value -Name "$Name['$key']" @objDetailParam
            }
        }
        elseif (IsEnumerable -InputObject $obj) {
            if (IsIndexable -InputObject $obj) {
                Write-Verbose "$cmdName, IsEnumerable IsIndexable: $Name"
                for ($index = 0; $index -lt $obj.Count; $index++) {
                    $value = $obj[$index]
                    ObjDetail -InputObject $value -Name "$Name[$index]" @objDetailParam
                }
            }
            else {
                #print non-indexable collection with pseudo-index: $obj (N)
                #$obj (N) can be retrieved with ($obj | select -Index N)
                Write-Verbose "$cmdName, IsEnumerable Not Indexable: $Name"
                $count = -1
                foreach ($value in $obj) {
                    $count++
                    ObjDetail -InputObject $value -Name "$Name ($count)" @objDetailParam
                }
            }
        }

        foreach ($prop in $obj.psobject.Properties) {
            $property = $prop.Name
            $value = $prop.Value
            if ($property -notin $ExcludeProperty) {
                ObjDetail -InputObject $value -Name "$Name.$property" @objDetailParam
            }
            #else {
            #    #Write-Verbose "$cmdName, ExcludedProperty: $Name"
            #    #WriteObject -Name "$Name.$property" -InputObject $value -CustomValue '(ExcludedProperty)'
            #}
        }
    }
}

#will be the only exposed function when this is a module
function Get-ObjectDetail {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline = $true)]$InputObject,
        [string]$Name = '$x',
        [int]$MaxDepth = 10,
        [string[]]$ExcludeProperty
    )

    begin {
        $objDetailParam = @{
            Name            = $Name
            Level           = 0
            MaxDepth        = $MaxDepth
            HashCodes       = [System.Collections.Generic.HashSet[int]]::new()
            ExcludeProperty = $ExcludeProperty
        }
    }
    process {
        ObjDetail -InputObject $InputObject @objDetailParam
    }
    end {}
}

New-Alias -Name god -Value Get-ObjectDetail -ErrorAction SilentlyContinue

#only export functions with dashes
#Export-ModuleMember '*-*'
