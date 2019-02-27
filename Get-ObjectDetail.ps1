#by: tomasmu
#date: 2019-01-05

#some helper functions..
function Is {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory, Position = 0)]
        $InputObject,

        [Parameter(Mandatory, ParameterSetName = 'Enumerable')]
        [switch]$Enumerable,

        [Parameter(Mandatory, ParameterSetName = 'Dictionary')]
        [switch]$Dictionary,

        [Parameter(Mandatory, ParameterSetName = 'Indexable')]
        [switch]$Indexable,

        [Parameter(Mandatory, ParameterSetName = 'SimpleType')]
        [switch]$SimpleType,

        [Parameter(Mandatory, ParameterSetName = 'PSCustomObjectHashCode')]
        [switch]$PSCustomObjectHashCode

        #[Parameter(Mandatory, ParameterSetName = 'Todo?')]
        #[AllowEmptyCollection()]
        #[System.Collections.Generic.HashSet[int]]$HashCodes
    )

    if ($Enumerable) {
        #is enumerable and also not a "value type"
        #special case: [string] is excluded

        $InputObject -is [System.Collections.IEnumerable] -and
        -not (Is $InputObject -SimpleType)
    }
    elseif ($Dictionary) {
        $InputObject -is [System.Collections.IDictionary]
    }
    elseif ($Indexable) {
        #$x and $x[0] returns the same object if it's an unindexable datatype (e.g. KeyCollection)

        $null -ne $InputObject -and
        $null -ne $InputObject[0] -and
        $InputObject[0].GetHashCode() -ne $InputObject.GetHashCode()
    }
    elseif ($SimpleType) {
        #Is -SimpleType = should print value instead of (...), but when do we want to hide the ToString() representation?
        #move print logic or always print
        #e.g. $x.TimeOfDay (...) vs $x.TimeOfDay.ToString()
        #also: SimpleTypes never gets their GetHashCode() stored, create a StoreHash?
        $null -eq $InputObject -or
        $InputObject.GetType().IsPrimitive -or
        $InputObject -is [string] -or  #treat [string] as a value
        $InputObject -is [enum]        #and [enum]
        #$InputObject.GetType().IsValueType #i want to print+recurse valuetypes, e.g. enums has string+value
    }
    elseif ($PSCustomObjectHashCode) {
        $null -ne $InputObject -and
        $InputObject.GetHashCode() -eq ([PSCustomObject]@{}).GetHashCode()
    }
    elseif ($Unique) {
        #or function IsUnique?
        #unique = unique hashcode  || simple type where we don't save hashcodes || types with duplicate hashcodes
        #if hashcodes.ContainsKey -or (Is -SimpleType)                         -or (Is -PSCustomObjectHashCode)?
        #is this a ShouldPrint too? (Duplicate) or value, someone else's responsibility?
        #why a bool? GetValueOrDefault?
        #"todo: -Unique $InputObject"
    }
    else {
        $null
    }
}

<#
function IsSimple {
    #todo: should probably be renamed, and move hashcode handling here
    #its purpose is to determine if we want to print duplicate objects or not
    # if we encounter, say, the same dictionary a second time we don't want to print it again
    # however, occurrence of duplicate integers is of course ok
    # "complex" objects are thus printed and have their hashcodes saved, so we don't print them again
    # "simple" types are always written and their hashcodes aren't saved
    #some types give random hashcodes, e.g. (gci -File | select -First 1).Directory.GetHashCode()
    # this leads to infinite recursion of .Directory.Root.Root.Root...
    #other types give the same hashcode, e.g. $x=[pscustomobject]@{a=1};$y=[pscustomobject]@{b=1;c=2};$x.GetHashCode();$y.GetHashCode()
    #0-duplicates seems common, e.g. [timespan]0, all-zero guid, (Get-Date 0), perhaps always allow 0?
    # except (Get-Date 0).Date.Date... recurses forever until Depth, or perhaps PropertyCycle
}
#>

#helper helper function
function FilterPredicate {
    [CmdletBinding()]
    param(
        [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [AllowNull()]
        [Alias('Name')]
        [string]$InputObject,

        [parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()] #here or in calling function?
        [string[]]$Filter
    )

    begin {}
    process {
        if ($null -eq $Filter) {
            return $true
        }

        foreach ($filt in $Filter) {
            if ($InputObject -like $filt) {
                return $true
            }
        }

        return $false
    }
    end {}
}

function IncludeExcludePredicate {
    param(
        [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [AllowNull()]
        [Alias('FullName', 'Name')]
        [string]$InputObject,

        [string[]]$Include,
        
        [string[]]$Exclude
    )

    $isIncluded = ($InputObject | FilterPredicate -Filter $Include)
    $isExcluded = ($InputObject | FilterPredicate -Filter $Exclude)

    (($null -eq $Include) -or $isIncluded) -and
    (($null -eq $Exclude) -or -not $isExcluded)
}

function IsIgnoredType {
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [AllowNull()]
        $InputObject,

        [parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]]$IncludeType,
        
        [parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]]$ExcludeType
    )

    ($null -ne $InputObject) -and
    -not ($InputObject.GetType() | IncludeExcludePredicate -Include $IncludeType -Exclude $ExcludeType)
}

#determine if string ends with a property cycle repeated $Count times, to avoid infinitely recursive types
#e.g. $x.prop.prop.prop (3 repeats) or $x.a.b.c.a.b.c (2 repeats)
#i cannot always find duplicates with GetHashCode(), it returns random values on certain types
<#slightly bad workaround so it's not in use yet, there has to be a better way!
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
#>

function WriteObject {
    [CmdletBinding()]
    param(
        $InputObject,
        $Name,
        $CustomValue
    )

    $value = if ($null -eq $CustomValue) { $InputObject } else { $CustomValue }
    $type = if ($null -ne $InputObject) { $InputObject.GetType() } else { $null }
    
    $output = [PSCustomObject]@{
        Name  = $Name
        Value = $value
        Type  = $type
    }

    if ($DebugPreference) {
        #$output | Add-Member @{ Level = $Level } #$Level visible from outer function(!)
        #$output | Add-Member @{ IsSimple = Is $InputObject -SimpleType }
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
        [int]$Depth,
        [System.Collections.Generic.HashSet[int]]$HashCodes,
        [string[]]$IncludeProperty,
        [string[]]$ExcludeProperty,
        [string[]]$IncludeType,
        [string[]]$ExcludeType
    )

    $object = $InputObject

    $cmdName = $PSCmdlet.MyInvocation.MyCommand
    Write-Verbose "$cmdName, $($PSBoundParameters.GetEnumerator() | ? Key -ne 'HashCodes' | % { "$($_.Key)='$($_.Value)'" })"

    if ($Level -gt $Depth) {
        Write-Verbose "$cmdName, Depth $Depth exceeded: $Name"
        if ($DebugPreference) {
            WriteObject -Name $Name -InputObject $object -CustomValue '(Depth.Object)'
        }

        return
    }

    if (IsIgnoredType -InputObject $object -IncludeType $IncludeType -ExcludeType $ExcludeType) {
        Write-Verbose "$cmdName, ignored: $Name"
        if ($DebugPreference) {
            WriteObject -Name $Name -InputObject $object -CustomValue "(Ignored)"
        }

        return
    }
    #>

    <#configurable?
    $cycleCount = 2
    if (HasPropertyCycle -Text $Name -Count $cycleCount) {
        Write-Verbose "$cmdName, PropertyCycle exceeded: $cycleCount"
        if ($DebugPreference) {
            WriteObject -Name $Name -InputObject $object -CustomValue "(PropertyCycle)"
        }

        return
    }
    #>

    if (Is $object -SimpleType) {
        #print object and value
        WriteObject -Name $Name -InputObject $object
    }
    else {
        #todo: move this handling into Is -SimpleType, or one of the others
        $hashCode = $object.GetHashCode()
        $isUnique = $HashCodes.Add($hashCode) -or (Is $object -PSCustomObjectHashCode)
        if ($isUnique) {
            #print complex object without value, properties will be shown later
            WriteObject -Name $Name -InputObject $object -CustomValue '(...)'
        }
        else {
            #Write-Verbose "Duplicate hashcode detected: $Name = $hashCode"
            #output duplicates to not leave holes in arrays
            WriteObject -Name $Name -InputObject $object -CustomValue '(DuplicateHashCode)'

            return
        }
    }

    #ignore properties etc if $Depth would be reached
    if ($Level -ge $Depth) {
        Write-Verbose "$cmdName, Depth reached for properties"
        if ($DebugPreference) {
            $propCount = $object.psobject.Properties.Name.Count
            if ($propCount -gt 0) {
                WriteObject -Name "$Name.($propCount)" -InputObject $object -CustomValue '(Depth.Property)'
            }
        }

        return
    }

    $objDetailParam = @{
        Level           = $Level + 1
        Depth           = $Depth
        HashCodes       = $HashCodes
        IncludeProperty = $IncludeProperty
        ExcludeProperty = $ExcludeProperty
        ExcludeType     = $ExcludeType
    }

    #recursive stuff
    if (Is $object -Enumerable) {
        try {
            $enumerator = $object.GetEnumerator()
        }
        catch {
            #some enumerable types don't have .GetEnumerator()
            #e.g. (Get-ChildItem -File | select -first 1).PSDrive.Provider.ImplementingType.DeclaredNestedTypes
            if ($DebugPreference) {
                WriteObject -InputObject $object -Name $Name -CustomValue "(GetEnumerator)"
            }

            $enumerator = $object
        }
        
        $i = 0
        foreach ($item in $enumerator) {
            if (Is $object -Dictionary) {
                $index = $item.Key
                $value = $item.Value
                $newName = "$Name['$index']"
            }
            elseif (Is $object -Indexable) {
                $index = $i
                $value = $object[$index]
                $newName = "$Name[$index]"
            }
            else {
                #print non-indexable collection with pseudo-index: $object (N)
                $index = $i
                $value = $item
                $newName = "$Name ($index)"
            }

            ObjDetail -InputObject $value -Name $newName @objDetailParam
            $i++
        }
    }

    $properties = $object.psobject.Properties | Where-Object { $_ | IncludeExcludePredicate -Include $IncludeProperty -Exclude $ExcludeProperty }
    foreach ($prop in $properties) {
        $index = $prop.Name
        $value = $prop.Value
        $newName = "$Name.$index"

        ObjDetail -InputObject $value -Name $newName @objDetailParam
    }

    if ($DebugPreference) {
        #Write-Verbose "$cmdName, ExcludedProperty: $Name"
        $propertiesExcluded = $object.psobject.Properties | Where-Object { $_ | IncludeExcludePredicate -Include $IncludeProperty -Exclude $ExcludeProperty }
        foreach ($prop in $propertiesExcluded) {
            $index = $prop.Name
            $value = $prop.Value
            $newName = "$Name.$index"

            WriteObject -Name $newName -InputObject $value -CustomValue '(ExcludedProperty)'
        }
    }
}

#will be the only exposed function when this is a module
function Get-ObjectDetail {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline)]
        $InputObject,

        [string]$Name = '$_',

        [int]$Depth = 10,
        
        [string[]]$IncludeProperty,
        
        [string[]]$ExcludeProperty,

        [AllowEmptyString()]
        [string[]]$IncludeType,
        
        [AllowEmptyString()]
        [string[]]$ExcludeType = ('System.Reflection.*', 'System.RunTime*')
    )

    begin {
        $objDetailParam = @{
            Name            = $Name
            Level           = 0
            Depth           = $Depth
            HashCodes       = [System.Collections.Generic.HashSet[int]]::new()
            IncludeProperty = $IncludeProperty
            ExcludeProperty = $ExcludeProperty
            ExcludeType     = $ExcludeType
        }
    }
    process {
        ObjDetail -InputObject $InputObject @objDetailParam
    }
    end {}
}

New-Alias -Name god -Value Get-ObjectDetail -ErrorAction SilentlyContinue

#only export functions with dashes, the others are internal functions
#Export-ModuleMember '*-*'
