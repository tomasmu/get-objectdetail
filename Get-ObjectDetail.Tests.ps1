#by: tomasmu
#date: 2019-01-05

. ($PSCommandPath -replace '\.Tests\.ps1', '.ps1')
#Remove-Module GetObjectDetail
#Import-Module GetObjectDetail

#helper function for output comparison and creating test arrays
#input: Get-ObjectDetail output
function ConvertToCsvString {
    param(
        [parameter(ValueFromPipeline)]$InputObject,
        [switch]$ArraySyntax,
        [char]$Delimiter = ','
    )

    process {
        ($InputObject |
            ForEach-Object {
                [PSCustomObject]@{
                    Name  = $_.Name
                    Value = ($_.Value | ForEach-Object { $_ }) -join ' '
                    Type  = $_.Type
                }
            } |
            ConvertTo-Csv -NoTypeInformation -Delimiter $Delimiter |
            ForEach-Object {
                if ($ArraySyntax) {
                    "'$($_ -replace "'", "''")'"
                }
                else {
                    $_
                }
            } |
            select -Skip 1) -join $Delimiter
    }
}

Describe 'Is -Enumerable' {
    #todo: split into separate tests
    Context 'Given an IEnumerable (array/hashtable/list)' {
        It 'Returns True' {
            Is @() -Enumerable | Should Be $true
            Is @{} -Enumerable | Should Be $true
            Is ([System.Collections.Generic.List[int]]::new()) -Enumerable | Should Be $true
            
            Is -Enumerable @() | Should Be $true
            Is -Enumerable @{} | Should Be $true
            Is -Enumerable ([System.Collections.Generic.List[int]]::new()) | Should Be $true
        }
    }

    Context 'Given an enumerable type (string) which we want to treat as a value' {
        It 'Returns False' {
            Is "special case" -Enumerable | Should Be $false
    
            Is -Enumerable "special case" | Should Be $false
        }
    }
    
    Context 'Given non-enumerable types (null/int/date)' {
        It 'Returns False' {
            Is $null -Enumerable | Should Be $false
            Is 42 -Enumerable | Should Be $false
            Is (Get-Date) -Enumerable | Should Be $false
    
            Is -Enumerable $null | Should Be $false
            Is -Enumerable 42 | Should Be $false
            Is -Enumerable (Get-Date) | Should Be $false
        }
    }
}

Describe 'Is -Dictionary' {
    Context 'Given a dictionary (hashtable)' {
        It 'Returns True' {
            Is @{ a = 42 } -Dictionary | Should Be $true

            Is -Dictionary @{ a = 42 } | Should Be $true
        }
    }

    Context 'Given a non-dictionary (hashset)' {
        It 'Returns False' {
            Is -Dictionary ([System.Collections.Generic.HashSet[string]]::new()) | Should Be $false

            Is ([System.Collections.Generic.HashSet[string]]::new()) -Dictionary | Should Be $false
        }
    }

    #todo: split into separate tests
    Context 'Given a non-dictionary (null/array/int/string)' {
        It 'Returns False' {
            Is -Dictionary $null | Should Be $false
            Is -Dictionary @('42') | Should Be $false
            Is -Dictionary 42 | Should Be $false
            Is -Dictionary "str" | Should Be $false

            Is $null -Dictionary | Should Be $false
            Is @('42') -Dictionary | Should Be $false
            Is 42 -Dictionary | Should Be $false
            Is "str" -Dictionary | Should Be $false
        }
    }
}

Describe 'Is -SimpleType' {
    #todo: split into separate tests
    Context "Given a 'simple/value/primitive' type (null/int/string)" {
        It "Returns True" {
            Is -SimpleType $null | Should Be $true
            Is -SimpleType 42 | Should Be $true
            Is -SimpleType "str" | Should Be $true

            Is $null -SimpleType | Should Be $true
            Is 42 -SimpleType | Should Be $true
            Is "str" -SimpleType | Should Be $true
        }
    }

    Context "Given enum" {
        It "some" {
            Is (Get-Date).DayOfWeek -SimpleType | Should Be $true
        }
    }

    Context 'Given complex type (array/hashtable/guid/intarray/timespan)' {
        It 'Returns False' {
            Is -SimpleType @('a', 1) | Should Be $false
            Is -SimpleType @{ 'a' = 1 } | Should Be $false
            Is -SimpleType (New-Guid) | Should Be $false
            Is -SimpleType ([int[]](12, 34)) | Should Be $false
            Is -SimpleType ([timespan]::new(1)) | Should Be $false

            Is @('a', 1) -SimpleType | Should Be $false
            Is @{ 'a' = 1 } -SimpleType | Should Be $false
            Is (New-Guid) -SimpleType | Should Be $false
            Is ([int[]](12, 34)) -SimpleType | Should Be $false
            Is ([timespan]::new(1)) -SimpleType | Should Be $false
        }
    }
}

Describe 'Is -Indexable' {
    #todo: split into separate tests
    Context 'Given a type which is indexable with integers (string/array/intArray)' {
        It 'Returns True' {
            Is -Indexable "str" | Should Be $true
            Is -Indexable @('a', 1) | Should Be $true
            Is -Indexable ([int[]](12, 34)) | Should Be $true

            Is "str" -Indexable | Should Be $true
            Is @('a', 1) -Indexable | Should Be $true
            Is ([int[]](12, 34)) -Indexable | Should Be $true
        }
    }

    Context 'Given a type that cannot be indexable with integers (null/dictionary/hashset/int)' {
        It 'Returns False' {
            Is -Indexable $null | Should Be $false
            Is -Indexable @{ 'a' = 1 } | Should Be $false
            Is -Indexable ([System.Collections.Generic.HashSet[string]]) | Should Be $false
            Is -Indexable 42 | Should Be $false

            Is $null -Indexable | Should Be $false
            Is @{ 'a' = 1 } -Indexable | Should Be $false
            Is ([System.Collections.Generic.HashSet[string]]) -Indexable | Should Be $false
            Is 42 -Indexable | Should Be $false
        }
    }
}

Describe 'Is -PSCustomObjectHashCode' {
    Context 'Given a PSCustomObject' {
        It 'Returns True if two different PSCustomObjects have the same GetHashCode() [unexpected but current behaviour 2019-01-10]' {
            Is ([PSCustomObject]@{ I = 'am'; a = 'PSCustomObject' }) -PSCustomObjectHashCode | Should Be $true
            Is ([PSCustomObject]@{ And = "I'm"; another = 'PSCustomObject!' }) -PSCustomObjectHashCode | Should Be $true
        }
    }

    Context 'Given other types (psobject, hashtable, string)' {
        It 'Returns False' {
            Is ([psobject]@{ ps = "object" }) -PSCustomObjectHashCode | Should Be $false
            Is (@{ horse = "table" }) -PSCustomObjectHashCode | Should Be $false
            Is "mary powershelley" -PSCustomObjectHashCode | Should Be $false
        }
    }
}

<#
Describe 'HasPropertyCycle' {
    #$x.prop.a.a.a.a     Count 4
    #$x.prop.a.b.a.b.a.b Count 3
    #$x.prop.a.b.a       Count 1 (uninteresting, repeated once in a row = a property exists)
    Context 'Given a property cycle of length 1, and -Count 2' {
        It 'Returns True if cycle occurs 2 times in the end' {
            $c1 = '.a'
            HasPropertyCycle -Count 2 -Text "`$x.prop$c1$c1"       | Should Be $true
            HasPropertyCycle -Count 2 -Text "`$x.prop$c1$c1$c1$c1" | Should Be $true

            HasPropertyCycle -Count 2 -Text "`$x.prop$c1"          | Should Be $false
        }
    }

    Context 'Given a property cycle of length 3, and -Count 4' {
        It 'Returns True if cycle occurs 4 times in the end' {
            $c3 = '.a.b.c'
            HasPropertyCycle -Count 4 -Text "`$x.prop$c3$c3$c3$c3"       | Should Be $true
            HasPropertyCycle -Count 4 -Text "`$x.prop$c3$c3$c3$c3$c3$c3" | Should Be $true

            HasPropertyCycle -Count 4 -Text "`$x.prop$c3$c3$c3"          | Should Be $false
        }
    }

    Context 'Given no ending property cycle' {
        It 'Returns False' {
            HasPropertyCycle -Count 2 -Text "`$x.prop.a.b.a" | Should Be $false
            HasPropertyCycle -Count 2 -Text "`$x.prop.a.a.b" | Should Be $false
            HasPropertyCycle -Count 2 -Text "`$x.prop.a.b.c" | Should Be $false
        }
    }
}
#>

Describe 'WriteObject' {
    #i should really write my own comparison and ditch ConvertToCsvString.. maybe?
    Context 'Given an object with value' {
        It 'Outputs the properties we want' {
            $object = @(12, 34)
            $expected = [PSCustomObject]@{
                Name  = "name"
                Value = "12 34"
                Type  = "System.Object[]"
            } | ConvertToCsvString
            
            $actual = WriteObject -Name "name" -InputObject $object
            
            ,$actual | ConvertToCsvString | Should Be $expected
        }
    }

    Context 'Given an object and custom value' {
        It 'Outputs the custom value' {
            $object = @(12, 34)
            $expected = [PSCustomObject]@{
                Name = "name"
                Value = "custom"
                Type = "System.Object[]"
            } | ConvertToCsvString
            
            $actual = WriteObject -Name "name" -InputObject $object -CustomValue "custom"
            
            ,$actual | ConvertToCsvString | Should Be $expected
        }
    }
}

Describe 'Get-ObjectDetail' {
    #todo: test columns separately with | select Col to make tests less brittle?
    Context 'Given int' {
        It 'Returns expected object' {
            $object = 42
            $expected = @(
                '"$_","42","System.Int32"'
            ) -join ','

            $actual = Get-ObjectDetail -InputObject $object
            
            ,$actual | ConvertToCsvString | Should Be $expected
        }
    }

    Context 'Given string' {
        It 'Returns expected object and properties' {
            $object = "this sentence has thirtynine characters"
            $expected = @(
                '"$_","this sentence has thirtynine characters","System.String"'
                '"$_.Length","39","System.Int32"'
            ) -join ','

            $actual = Get-ObjectDetail -InputObject $object
            
            ,$actual | ConvertToCsvString | Should Be $expected
        }
    }

    Context 'Given complex object (date)' {
        It 'Shows (...) as object value since its content will be expanded later' {
            $object = Get-Date
            $expected = @(
                '"$_","(...)","System.DateTime"'
            ) -join ','

            $actual = Get-ObjectDetail -InputObject $object -Depth 0
            
            ,$actual | ConvertToCsvString | Should Be $expected
        }
    }

    Context 'Given int array' {
        It 'Returns expected object' {
            $object = [int[]](12, 34, 56)
            $expected = @(
                '"$_","(...)","System.Int32[]"'
                '"$_[0]","12","System.Int32"'
                '"$_[1]","34","System.Int32"'
                '"$_[2]","56","System.Int32"'
                '"$_.Count","3","System.Int32"'
                '"$_.Length","3","System.Int32"'
                '"$_.LongLength","3","System.Int64"'
                '"$_.Rank","1","System.Int32"'
                '"$_.SyncRoot","(DuplicateHashCode)","System.Int32[]"'
                '"$_.IsReadOnly","False","System.Boolean"'
                '"$_.IsFixedSize","True","System.Boolean"'
                '"$_.IsSynchronized","False","System.Boolean"'
            ) -join ','

            $actual = Get-ObjectDetail -InputObject $object

            ,$actual | ConvertToCsvString | Should Be $expected
        }
    }

    Context 'Given object with duplicates' {
        It 'Marks duplicate complex types as (Duplicate), but not duplicate value types' {
            $duplicate = [PSObject]@{ Double = 6.283185 }
            $notDuplicate = 42
            $object = [PSCustomObject]@{
                Duplicate1 = $duplicate
                Duplicate2 = $duplicate
                NotDuplicate1 = $notDuplicate
                NotDuplicate2 = $notDuplicate
            }
            $expected = @(
                '"$_","(...)","System.Management.Automation.PSCustomObject"'
                '"$_.Duplicate1","(...)","System.Collections.Hashtable"'
                '"$_.Duplicate2","(DuplicateHashCode)","System.Collections.Hashtable"'
                '"$_.NotDuplicate1","42","System.Int32"'
                '"$_.NotDuplicate2","42","System.Int32"'
            ) -join ','

            $actual = Get-ObjectDetail -InputObject $object -Depth 1

            ,$actual | ConvertToCsvString | Should Be $expected
        }
    }

    Context 'Given dictionary with mixed content, both as parameter and piped' {
        It 'It Just Works' {
            $object = [ordered]@{
                hello = 13
                37 = "world!"
                yarr = @([char]'y', 'arr')
                someday = Get-Date 636823000000000000
                nil = $null
            }
            $expected = @(
                '"$_","(...)","System.Collections.Specialized.OrderedDictionary"'
                '"$_[''hello'']","13","System.Int32"'
                '"$_[''37'']","world!","System.String"'
                '"$_[''37''].Length","6","System.Int32"'
                '"$_[''yarr'']","(...)","System.Object[]"'
                '"$_[''yarr''][0]","y","System.Char"'
                '"$_[''yarr''][1]","arr","System.String"'
                '"$_[''yarr''][1].Length","3","System.Int32"'
                '"$_[''yarr''].Count","2","System.Int32"'
                '"$_[''yarr''].Length","2","System.Int32"'
                '"$_[''yarr''].LongLength","2","System.Int64"'
                '"$_[''yarr''].Rank","1","System.Int32"'
                '"$_[''yarr''].SyncRoot","(DuplicateHashCode)","System.Object[]"'
                '"$_[''yarr''].IsReadOnly","False","System.Boolean"'
                '"$_[''yarr''].IsFixedSize","True","System.Boolean"'
                '"$_[''yarr''].IsSynchronized","False","System.Boolean"'
                '"$_[''someday'']","(...)","System.DateTime"'
                '"$_[''someday''].DisplayHint","DateTime","Microsoft.PowerShell.Commands.DisplayHintType"'
                '"$_[''someday''].DisplayHint.value__","2","System.Int32"'
                '"$_[''someday''].DateTime","den 5 januari 2019 15:46:40","System.String"'
                '"$_[''someday''].DateTime.Length","27","System.Int32"'
                '"$_[''someday''].Date","(...)","System.DateTime"'
                '"$_[''someday''].Date.DateTime","den 5 januari 2019 00:00:00","System.String"'
                '"$_[''someday''].Date.DateTime.Length","27","System.Int32"'
                '"$_[''someday''].Date.Date","(DuplicateHashCode)","System.DateTime"'
                '"$_[''someday''].Date.Day","5","System.Int32"'
                '"$_[''someday''].Date.DayOfWeek","Saturday","System.DayOfWeek"'
                '"$_[''someday''].Date.DayOfWeek.value__","6","System.Int32"'
                '"$_[''someday''].Date.DayOfYear","5","System.Int32"'
                '"$_[''someday''].Date.Hour","0","System.Int32"'
                '"$_[''someday''].Date.Kind","Unspecified","System.DateTimeKind"'
                '"$_[''someday''].Date.Kind.value__","0","System.Int32"'
                '"$_[''someday''].Date.Millisecond","0","System.Int32"'
                '"$_[''someday''].Date.Minute","0","System.Int32"'
                '"$_[''someday''].Date.Month","1","System.Int32"'
                '"$_[''someday''].Date.Second","0","System.Int32"'
                '"$_[''someday''].Date.Ticks","636822432000000000","System.Int64"'
                '"$_[''someday''].Date.TimeOfDay","(...)","System.TimeSpan"'
                '"$_[''someday''].Date.TimeOfDay.Ticks","0","System.Int64"'
                '"$_[''someday''].Date.TimeOfDay.Days","0","System.Int32"'
                '"$_[''someday''].Date.TimeOfDay.Hours","0","System.Int32"'
                '"$_[''someday''].Date.TimeOfDay.Milliseconds","0","System.Int32"'
                '"$_[''someday''].Date.TimeOfDay.Minutes","0","System.Int32"'
                '"$_[''someday''].Date.TimeOfDay.Seconds","0","System.Int32"'
                '"$_[''someday''].Date.TimeOfDay.TotalDays","0","System.Double"'
                '"$_[''someday''].Date.TimeOfDay.TotalHours","0","System.Double"'
                '"$_[''someday''].Date.TimeOfDay.TotalMilliseconds","0","System.Double"'
                '"$_[''someday''].Date.TimeOfDay.TotalMinutes","0","System.Double"'
                '"$_[''someday''].Date.TimeOfDay.TotalSeconds","0","System.Double"'
                '"$_[''someday''].Date.Year","2019","System.Int32"'
                '"$_[''someday''].Day","5","System.Int32"'
                '"$_[''someday''].DayOfWeek","Saturday","System.DayOfWeek"'
                '"$_[''someday''].DayOfWeek.value__","6","System.Int32"'
                '"$_[''someday''].DayOfYear","5","System.Int32"'
                '"$_[''someday''].Hour","15","System.Int32"'
                '"$_[''someday''].Kind","Unspecified","System.DateTimeKind"'
                '"$_[''someday''].Kind.value__","0","System.Int32"'
                '"$_[''someday''].Millisecond","0","System.Int32"'
                '"$_[''someday''].Minute","46","System.Int32"'
                '"$_[''someday''].Month","1","System.Int32"'
                '"$_[''someday''].Second","40","System.Int32"'
                '"$_[''someday''].Ticks","636823000000000000","System.Int64"'
                '"$_[''someday''].TimeOfDay","(...)","System.TimeSpan"'
                '"$_[''someday''].TimeOfDay.Ticks","568000000000","System.Int64"'
                '"$_[''someday''].TimeOfDay.Days","0","System.Int32"'
                '"$_[''someday''].TimeOfDay.Hours","15","System.Int32"'
                '"$_[''someday''].TimeOfDay.Milliseconds","0","System.Int32"'
                '"$_[''someday''].TimeOfDay.Minutes","46","System.Int32"'
                '"$_[''someday''].TimeOfDay.Seconds","40","System.Int32"'
                '"$_[''someday''].TimeOfDay.TotalDays","0.657407407407407","System.Double"'
                '"$_[''someday''].TimeOfDay.TotalHours","15.7777777777778","System.Double"'
                '"$_[''someday''].TimeOfDay.TotalMilliseconds","56800000","System.Double"'
                '"$_[''someday''].TimeOfDay.TotalMinutes","946.666666666667","System.Double"'
                '"$_[''someday''].TimeOfDay.TotalSeconds","56800","System.Double"'
                '"$_[''someday''].Year","2019","System.Int32"'
                '"$_[''nil'']","",'
                '"$_.Count","5","System.Int32"'
                '"$_.IsReadOnly","False","System.Boolean"'
                '"$_.Keys","(...)","System.Collections.Specialized.OrderedDictionary+OrderedDictionaryKeyValueCollection"'
                '"$_.Keys (0)","hello","System.String"'
                '"$_.Keys (0).Length","5","System.Int32"'
                '"$_.Keys (1)","37","System.Int32"'
                '"$_.Keys (2)","yarr","System.String"'
                '"$_.Keys (2).Length","4","System.Int32"'
                '"$_.Keys (3)","someday","System.String"'
                '"$_.Keys (3).Length","7","System.Int32"'
                '"$_.Keys (4)","nil","System.String"'
                '"$_.Keys (4).Length","3","System.Int32"'
                '"$_.Keys.Count","5","System.Int32"'
                '"$_.Keys.SyncRoot","(...)","System.Object"'
                '"$_.Keys.IsSynchronized","False","System.Boolean"'
                '"$_.Values","(...)","System.Collections.Specialized.OrderedDictionary+OrderedDictionaryKeyValueCollection"'
                '"$_.Values (0)","13","System.Int32"'
                '"$_.Values (1)","world!","System.String"'
                '"$_.Values (1).Length","6","System.Int32"'
                '"$_.Values (2)","(DuplicateHashCode)","System.Object[]"'
                '"$_.Values (3)","(DuplicateHashCode)","System.DateTime"'
                '"$_.Values (4)","",'
                '"$_.Values.Count","5","System.Int32"'
                '"$_.Values.SyncRoot","(DuplicateHashCode)","System.Object"'
                '"$_.Values.IsSynchronized","False","System.Boolean"'
                '"$_.IsFixedSize","False","System.Boolean"'
                '"$_.SyncRoot","(...)","System.Object"'
                '"$_.IsSynchronized","False","System.Boolean"'
            ) -join ','

            $actualWithParameter = Get-ObjectDetail -InputObject $object
            $actualWithPipe = $object | Get-ObjectDetail

            ,$actualWithParameter | ConvertToCsvString | Should Be $expected
            ,$actualWithPipe | ConvertToCsvString | Should Be $expected
        }
    }
}
#>
