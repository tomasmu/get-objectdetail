#by: tomasmu
#date: 2019-01-05

#some helper functions..

#todo: suggestion, move the Is* functions into one
#then use like this: $obj | Test -IsEnumerable
<#
function TestObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject,

        [Parameter(ParameterSetName = 'IsEnumerable')]
        [switch]$IsEnumerable,

        [Parameter(ParameterSetName = 'IsDictionary')]
        [switch]$IsDictionary,

        [Parameter(ParameterSetName = 'IsIndexable')]
        [switch]$IsIndexable,

        [Parameter(ParameterSetName = 'ShouldPrint')]
        [switch]$ShouldPrint,
        [Parameter(ParameterSetName = 'ShouldPrint')]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[int]]$HashCodes
    )
}
#>

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
    # except (Get-Date 0).Date.Date... recurses forever until MaxDepth, or perhaps PropertyCycle
    
    [CmdletBinding()]
    param($InputObject)

    $null -eq $InputObject -or
    $InputObject.GetType().IsPrimitive -or
    $InputObject -is [string] -or  #treat [string] as a value
    $InputObject -is [enum]        #and [enum]
    #$InputObject.GetType().IsValueType #i want to print+recurse valuetypes, e.g. enums has string+value
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
    $null -ne $InputObject[0] -and
    $InputObject[0].GetHashCode() -ne $InputObject.GetHashCode()
}

function IsIgnored {
    [CmdletBinding()]
    param($InputObject)
    
    #reflection can really get out of hand
    $ignoreTypePattern = '^System\.Reflection|^System\.Runtime'

    $null -ne $InputObject -and
    $InputObject.GetType().FullName -match $ignoreTypePattern
}

#determine if string ends with a property cycle repeated $Count times, to avoid infinitely recursive types
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
        #$output | Add-Member @{ IsSimple = IsSimple -InputObject $InputObject }
        #$output | Add-Member @{ Hash = if ($null -ne $InputObject) { $InputObject.GetHashCode() } else { 'null' } }
    }

    $output
}

#the function that does it all
function ObjDetail {
    [CmdletBinding()]
    param(
        #[Parameter(ValueFromPipeline)]
        $InputObject,
        [string]$Name,
        [int]$Level,
        [int]$MaxDepth,
        [System.Collections.Generic.HashSet[int]]$HashCodes,
        [string[]]$ExcludeProperty
    )

    $obj = $InputObject

    $cmdName = $PSCmdlet.MyInvocation.MyCommand
    Write-Verbose "$cmdName, $($PSBoundParameters.GetEnumerator() | ? Key -ne 'HashCodes' | % { "$($_.Key)='$($_.Value)'" })"

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
        #todo: move this handling into a renamed IsSimple
        $hashCode = $obj.GetHashCode()
        $isUnique = $HashCodes.Add($hashCode)
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

    #ignore properties if $MaxDepth would be reached
    if ($Level -lt $MaxDepth) {
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
    else {
        Write-Verbose "$cmdName, MaxDepth reached for properties"
        if ($DebugPreference) {
            if ($obj.psobject.Properties.Name.Count -gt 0) {
                WriteObject -Name "$Name.[...]" -InputObject $obj -CustomValue '(MaxDepthProperty)'
            }
        }
    }
}

#will be the only exposed function when this is a module
function Get-ObjectDetail {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline)]$InputObject,
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
