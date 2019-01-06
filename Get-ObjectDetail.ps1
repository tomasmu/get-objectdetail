#by: tomasmu
#date: 2019-01-05

#some helper functions..
function IsSimple {
    #similar to "is value type"
    [CmdletBinding()]
    param($InputObject)

    $null -eq $InputObject -or
    $InputObject.GetType().IsPrimitive -or
    $InputObject -is [string] -or  #treat [string] as a value
    $InputObject -is [enum]        #and [enum]
}

function IsEnumerable {
    #is enumerable unless it's a "value type" like [string]
    [CmdletBinding()]
    param($InputObject)

    $InputObject -is [System.Collections.IEnumerable] -and
    -not (IsSimple -InputObject $InputObject)
}

function IsDictionary {
    [CmdletBinding()]
    param($InputObject)

    $InputObject -is [System.Collections.IDictionary]
}

function IsIndexable {
    [CmdletBinding()]
    param($InputObject)

    #$x and $x[0] returns the same object if it's an unindexable datatype (e.g. KeyCollection)

    $null -ne $InputObject -and
    $null -ne $InputObject[0] -and  #breaks if array has $null element in [0] though :(
    $InputObject[0].GetHashCode() -ne $InputObject.GetHashCode()
}

function IsIgnored {
    [CmdletBinding()]
    param($InputObject)
    
    $null -ne $InputObject -and
    $InputObject.GetType().Name -match '^Runtime' #reflection can really get out of hand
}

#determine if string ends with a property cycle repeated $Count times, to avoid infinitely recursive types
#i cannot always find duplicates with GetHashCode(), it returns random values on certain types
#slightly bad workaround so it's not in use yet, there has to be a better way!
function HasPropertyCycle {
    [CmdletBinding()]
    param(
        [string]$Text,
        [ValidateRange(2, [int]::MaxValue)]
        [int]$Count = 2
    )

    $cyclePattern = "((\.[^.]+)+)\1{$($Count - 1)}$"

    ([regex]$cyclePattern).Match($Text).Success
}

function WriteObject {
    [CmdletBinding()]
    param(
        $InputObject,
        $Name,
        $CustomValue
    )

    $value = if ($null -eq $CustomValue) { $InputObject } else { $CustomValue }
    $type = if ($null -ne $InputObject) { $InputObject.GetType().Name } else { 'null' }

    $output = [PSCustomObject]@{
        Name  = $Name
        Value = $value
        Type  = $type
    }

    if ($DebugPreference) {
        #$output | Add-Member @{ Level = $Level } #$Level visible from outer function(!)
        $output | Add-Member @{ Hash = if ($null -ne $InputObject) { $InputObject.GetHashCode() } else { 'null' } }
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
        Write-Verbose "$cmdName, MaxDepth $MaxDepth exceeded: $Name"
        if ($DebugPreference) {
            WriteObject -Name $Name -InputObject $obj -CustomValue '(MaxDepth)'
        }

        return
    }

    <#configurable?
    $cycleCount = 2
    if (HasPropertyCycle -Text $Name -Count $cycleCount) {
        Write-Verbose "$cmdName, PropertyCycle exceeded: $cycleCount"
        if ($DebugPreference) {
            WriteObject -Name $Name -InputObject $obj -CustomValue "(PropertyCycle)"
        }

        return
    }
    #>

    $obj = $InputObject
    <#not needed anymore, null is treated as a value anyway
    if ($null -eq $obj) {
        WriteObject -Name $Name -InputObject $obj

        return
    }
    #>

    #configurable?
    if (IsIgnored -InputObject $obj) {
        Write-Verbose "$cmdName, ignored: $Name"
        if ($DebugPreference) {
            WriteObject -Name $Name -InputObject $obj -CustomValue "(Ignored)"
        }

        return
    }
    #>
    
    if (IsSimple -InputObject $obj) {
        #print object and value
        WriteObject -Name $Name -InputObject $obj
    }
    else {
        $hashCode = $obj.GetHashCode()
        #random thoughts:
        #$isZeroHash = $hashCode -eq 0 #include anyway, could be empty guid, [timespan]0, etc
        #(Get-Date 0) can be a problem because of infinite .Date.Date.Date... which $MaxDepth has to handle
        #todo: is there a better way than GetHashCode() to find duplicates?
        #$isPSCustomObjectGetHashCodeBug = $obj -is [System.Management.Automation.PSCustomObject] #include anyway, because of duplicate hashcode bug?
        $isUnique = $HashCodes.Add($hashCode) #-or $isZeroHash #-or $isPSCustomObjectGetHashCodeBug
        if ($isUnique) {
            #print complex object without value, properties will be shown later
            WriteObject -Name $Name -InputObject $obj -CustomValue '(...)'
        }
        else {
            #Write-Verbose "Duplicate hashcode detected: $Name = $hashCode"
            #output duplicates to not leave holes in arrays
            WriteObject -Name $Name -InputObject $obj -CustomValue '(Duplicate)'

            return
        }
    }

    $objDetailParam = @{
        Level           = $Level + 1
        MaxDepth        = $MaxDepth
        HashCodes       = $HashCodes
        ExcludeProperty = $ExcludeProperty
    }

    #recursive stuff
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
            $count = 0
            foreach ($value in $obj) {
                ObjDetail -InputObject $value -Name "$Name ($count)" @objDetailParam
                $count++
            }
        }
    }

    #print properties
    foreach ($prop in $obj.psobject.Properties) {
        $property = $prop.Name
        $value = $prop.Value
        if ($property -notin $ExcludeProperty) {
            ObjDetail -InputObject $value -Name "$Name.$property" @objDetailParam
        }
        else {
            #Write-Verbose "$cmdName, ExcludedProperty: $Name"
            if ($DebugPreference) {
                WriteObject -Name "$Name.$property" -InputObject $value -CustomValue '(ExcludedProperty)'
            }
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
